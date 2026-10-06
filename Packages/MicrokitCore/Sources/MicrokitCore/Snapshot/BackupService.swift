/// Reads a full `KeyboardBackup` from a keyboard and writes one back.
public struct BackupService: Sendable {
    public let client: VIAClient

    public init(client: VIAClient) {
        self.client = client
    }

    public func read(definition: KeyboardDefinition, protocolVersion: UInt16) async throws -> KeyboardBackup {
        let layers = try await client.layerCount()
        let keymap = try await client.readKeymap(layers: layers, rows: definition.matrix.rows, cols: definition.matrix.cols)
        let encoderCount = definition.encoderCount
        let encoders = encoderCount > 0 ? try await client.readEncoders(layers: layers, encoders: encoderCount) : nil
        var macroBuffer: [UInt8]?
        if try await client.macroCount() > 0 {
            macroBuffer = try await client.readMacroBuffer(size: try await client.macroBufferSize())
        }
        let layoutOptions = definition.layouts.labels?.isEmpty == false ? try await client.layoutOptions() : nil
        var customValues: [CustomValueRecord] = []
        for control in definition.lightingPages.flatMap({ $0.sections.flatMap(\.controls) }) {
            if case .unsupported = control.kind { continue }
            if let bytes = try? await client.customValue(path: control.path, count: control.byteCount) {
                customValues.append(CustomValueRecord(path: control.path, bytes: bytes))
            }
        }
        return KeyboardBackup(name: definition.name, vendorProductId: definition.vendorProductId, protocolVersion: protocolVersion,
                              keymap: keymap, encoders: encoders, macroBuffer: macroBuffer, layoutOptions: layoutOptions,
                              customValues: customValues)
    }

    /// Writes every part of the backup. The keymap must match the keyboard's size.
    public func restore(_ backup: KeyboardBackup) async throws {
        let layers = try await client.layerCount()
        guard layers == backup.keymap.layers else {
            throw VIAError.invalidArgument("The backup has \(backup.keymap.layers) layers, the keyboard has \(layers).")
        }
        try await client.writeKeymap(backup.keymap)
        if let encoders = backup.encoders {
            for layer in 0..<encoders.layers {
                for encoder in 0..<encoders.encoders {
                    for clockwise in [false, true] {
                        try await client.setEncoderKeycode(encoders[layer, encoder, clockwise], layer: layer, encoder: encoder, clockwise: clockwise)
                    }
                }
            }
        }
        if let macroBuffer = backup.macroBuffer {
            let size = try await client.macroBufferSize()
            try await client.writeMacroBuffer(Array(macroBuffer.prefix(size)))
        }
        if let layoutOptions = backup.layoutOptions {
            try await client.setLayoutOptions(layoutOptions)
        }
        for record in backup.customValues {
            try await client.setCustomValue(path: record.path, record.bytes)
        }
        for channel in Set(backup.customValues.compactMap(\.path.first)).sorted() {
            try? await client.saveCustomValues(channel: channel)
        }
    }
}
