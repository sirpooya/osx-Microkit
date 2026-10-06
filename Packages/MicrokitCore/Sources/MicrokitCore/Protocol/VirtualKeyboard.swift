/// An in-memory VIA keyboard that answers like qmk_firmware `quantum/via.c`.
/// Used by the tests and by the app's demo keyboard. Writes change only this memory.
public actor VirtualKeyboard: ReportTransport {
    public var protocolVersion: UInt16 = 0x000C
    public var keycodesVersion: UInt32?
    public var rows: Int
    public var cols: Int
    public var keymap: Keymap
    public var encoders: EncoderMap
    public var macroCount: Int
    public var macroBuffer: [UInt8]
    public var layoutOptions: UInt32 = 0
    public var customValues: [[UInt8]: [UInt8]] = [:]
    public var pressed: Set<[Int]> = []
    /// Requests seen, in order.
    public private(set) var log: [[UInt8]] = []
    /// A report delivered before the next real reply, to test reply matching.
    public var strayReport: [UInt8]?

    public init(layers: Int = 4, rows: Int = 4, cols: Int = 4, encoders: Int = 2, macroCount: Int = 16, macroBufferSize: Int = 823) {
        self.rows = rows
        self.cols = cols
        keymap = Keymap(layers: layers, rows: rows, cols: cols)
        self.encoders = EncoderMap(layers: layers, encoders: encoders)
        self.macroCount = macroCount
        macroBuffer = Array(repeating: 0, count: macroBufferSize)
    }

    public func setKeymap(_ keymap: Keymap) { self.keymap = keymap }
    public func setEncoders(_ encoders: EncoderMap) { self.encoders = encoders }
    public func setStrayReport(_ report: [UInt8]?) { strayReport = report }
    public func setCustomValue(_ path: [UInt8], _ bytes: [UInt8]) { customValues[path] = bytes }
    public func setKeycodesVersion(_ version: UInt32?, protocolVersion: UInt16) {
        keycodesVersion = version
        self.protocolVersion = protocolVersion
    }
    public func press(row: Int, col: Int) { pressed.insert([row, col]) }
    public func release(row: Int, col: Int) { pressed.remove([row, col]) }
    public func setMacroBuffer(_ bytes: [UInt8]) {
        for (i, byte) in bytes.enumerated() where i < macroBuffer.count { macroBuffer[i] = byte }
    }

    public func exchange(_ request: [UInt8], timeout: Duration, matches: @escaping @Sendable ([UInt8]) -> Bool) async throws -> [UInt8] {
        log.append(request)
        var data = request + Array(repeating: 0, count: max(0, VIAClient.reportSize - request.count))
        handle(&data)
        var candidates: [[UInt8]] = []
        if let strayReport {
            candidates.append(strayReport)
            self.strayReport = nil
        }
        candidates.append(data)
        guard let reply = candidates.first(where: matches) else { throw VIAError.timeout(command: request[0]) }
        return reply
    }

    private func handle(_ d: inout [UInt8]) {
        func u16(_ i: Int) -> Int { Int(d[i]) << 8 | Int(d[i + 1]) }
        switch VIACommand(rawValue: d[0]) {
        case .getProtocolVersion:
            d[1] = UInt8(protocolVersion >> 8)
            d[2] = UInt8(protocolVersion & 0xFF)
        case .getKeyboardValue:
            switch VIAKeyboardValue(rawValue: d[1]) {
            case .layoutOptions:
                d.replaceSubrange(2..<6, with: layoutOptions.bigEndianBytes)
            case .keycodesVersion:
                if let keycodesVersion { d.replaceSubrange(2..<6, with: keycodesVersion.bigEndianBytes) } else { d[0] = 0xFF }
            case .firmwareVersion, .uptime:
                d.replaceSubrange(2..<6, with: [0, 0, 0, 0])
            case .switchMatrixState:
                let offset = protocolVersion >= 12 ? Int(d[2]) : 0
                var i = protocolVersion >= 12 ? 3 : 2
                let bytesPerRow = (cols + 7) / 8
                var row = offset
                while row < rows, i + bytesPerRow <= d.count {
                    var value: UInt32 = 0
                    for col in 0..<cols where pressed.contains([row, col]) { value |= 1 << col }
                    for b in (0..<bytesPerRow).reversed() {
                        d[i] = UInt8((value >> (8 * b)) & 0xFF)
                        i += 1
                    }
                    row += 1
                }
            default:
                d[0] = 0xFF
            }
        case .setKeyboardValue:
            if d[1] == VIAKeyboardValue.layoutOptions.rawValue {
                layoutOptions = UInt32(bigEndianBytes: Array(d[2..<6]))
            }
        case .getKeycode:
            let code = keymap[Int(d[1]), Int(d[2]), Int(d[3])]
            d[4] = UInt8(code >> 8)
            d[5] = UInt8(code & 0xFF)
        case .setKeycode:
            keymap[Int(d[1]), Int(d[2]), Int(d[3])] = UInt16(u16(4))
        case .getKeymapBuffer, .setKeymapBuffer:
            let offset = u16(1), size = Int(d[3])
            var bytes = keymap.codes.flatMap(\.bigEndianBytes)
            if d[0] == VIACommand.getKeymapBuffer.rawValue {
                for i in 0..<size where offset + i < bytes.count { d[4 + i] = bytes[offset + i] }
            } else {
                for i in 0..<size where offset + i < bytes.count { bytes[offset + i] = d[4 + i] }
                let codes = stride(from: 0, to: bytes.count, by: 2).map { UInt16(bytes[$0]) << 8 | UInt16(bytes[$0 + 1]) }
                keymap = Keymap(layers: keymap.layers, rows: rows, cols: cols, codes: codes)
            }
        case .getEncoder:
            let code = encoders[Int(d[1]), Int(d[2]), d[3] != 0]
            d[4] = UInt8(code >> 8)
            d[5] = UInt8(code & 0xFF)
        case .setEncoder:
            encoders[Int(d[1]), Int(d[2]), d[3] != 0] = UInt16(u16(4))
        case .customGetValue:
            if let bytes = customValues[[d[1], d[2]]] {
                for (i, b) in bytes.enumerated() { d[3 + i] = b }
            } else {
                d[0] = 0xFF
            }
        case .customSetValue:
            let path = [d[1], d[2]]
            let count = customValues[path]?.count ?? 1
            customValues[path] = Array(d[3..<3 + count])
        case .customSave:
            break
        case .macroGetCount:
            d[1] = UInt8(macroCount)
        case .macroGetBufferSize:
            d[1] = UInt8(macroBuffer.count >> 8)
            d[2] = UInt8(macroBuffer.count & 0xFF)
        case .macroGetBuffer:
            let offset = u16(1), size = Int(d[3])
            for i in 0..<size where offset + i < macroBuffer.count { d[4 + i] = macroBuffer[offset + i] }
        case .macroSetBuffer:
            let offset = u16(1), size = Int(d[3])
            for i in 0..<size where offset + i < macroBuffer.count { macroBuffer[offset + i] = d[4 + i] }
        case .getLayerCount:
            d[1] = UInt8(keymap.layers)
        default:
            d[0] = 0xFF
        }
    }
}
