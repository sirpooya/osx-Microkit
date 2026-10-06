/// Typed VIA commands over a `ReportTransport`.
///
/// Wire format (qmk_firmware `quantum/via.c`): one 32-byte report out, one 32-byte report
/// back that echoes the request header. Multi-byte values are big-endian. Chunked buffer
/// commands carry at most `maxChunk` data bytes.
public struct VIAClient: Sendable {
    public static let reportSize = 32
    public static let maxChunk = 28

    public let transport: any ReportTransport
    public let timeout: Duration

    public init(transport: any ReportTransport, timeout: Duration = .milliseconds(800)) {
        self.transport = transport
        self.timeout = timeout
    }

    // MARK: Raw

    /// Sends one command and returns the full reply. Throws `VIAError.unhandled` on 0xFF.
    @discardableResult
    public func send(_ command: VIACommand, _ arguments: [UInt8] = []) async throws -> [UInt8] {
        let request = [command.rawValue] + arguments
        guard request.count <= Self.reportSize else {
            throw VIAError.invalidArgument("Request for command \(command) is \(request.count) bytes, the limit is \(Self.reportSize).")
        }
        let id = command.rawValue
        let echo = Array(arguments.prefix(command.echoLength))
        let reply = try await transport.exchange(request, timeout: timeout) { reply in
            guard reply.count > echo.count, reply[0] == id || reply[0] == VIACommand.unhandled else { return false }
            return reply.dropFirst().prefix(echo.count).elementsEqual(echo)
        }
        if reply[0] == VIACommand.unhandled {
            throw VIAError.unhandled(command: id)
        }
        return reply
    }

    // MARK: Device

    public func protocolVersion() async throws -> UInt16 {
        let reply = try await send(.getProtocolVersion)
        return try reply.bigEndianUInt16(at: 1, command: .getProtocolVersion)
    }

    public func layerCount() async throws -> Int {
        let reply = try await send(.getLayerCount)
        return Int(try reply.byte(at: 1, command: .getLayerCount))
    }

    /// Reads `count` bytes of a keyboard value. Data starts after the value id and any parameters.
    public func keyboardValue(_ value: VIAKeyboardValue, parameters: [UInt8] = [], count: Int) async throws -> [UInt8] {
        let reply = try await send(.getKeyboardValue, [value.rawValue] + parameters)
        return try reply.bytes(from: 2 + parameters.count, count: count, command: .getKeyboardValue)
    }

    public func setKeyboardValue(_ value: VIAKeyboardValue, _ bytes: [UInt8]) async throws {
        try await send(.setKeyboardValue, [value.rawValue] + bytes)
    }

    public func uptime() async throws -> UInt32 {
        UInt32(bigEndianBytes: try await keyboardValue(.uptime, count: 4))
    }

    public func firmwareVersion() async throws -> UInt32 {
        UInt32(bigEndianBytes: try await keyboardValue(.firmwareVersion, count: 4))
    }

    /// QMK keycodes version as BCD (0x00000009 is 0.0.9). `nil` when the firmware predates it.
    public func keycodesVersion() async throws -> UInt32? {
        do {
            return UInt32(bigEndianBytes: try await keyboardValue(.keycodesVersion, count: 4))
        } catch VIAError.unhandled {
            return nil
        }
    }

    public func layoutOptions() async throws -> UInt32 {
        UInt32(bigEndianBytes: try await keyboardValue(.layoutOptions, count: 4))
    }

    public func setLayoutOptions(_ options: UInt32) async throws {
        try await setKeyboardValue(.layoutOptions, options.bigEndianBytes)
    }

    /// Makes the keyboard flash its LEDs so the user can tell which board is selected.
    public func indicateDevice() async throws {
        try await setKeyboardValue(.deviceIndication, [0])
    }

    /// Pressed switches, `[row][col]`. Protocol 12 added a row offset so large matrices can be
    /// read in several requests; older firmware returns every row from byte 2.
    /// Recent QMK only reports presses when built with `VIA_INSECURE` or unlocked.
    public func switchMatrixState(rows: Int, cols: Int, protocolVersion: UInt16) async throws -> [[Bool]] {
        let bytesPerRow = (cols + 7) / 8
        var state: [[Bool]] = []
        if protocolVersion >= 12 {
            let rowsPerRequest = max(1, Self.maxChunk / bytesPerRow)
            var offset = 0
            while offset < rows {
                let batch = min(rowsPerRequest, rows - offset)
                let bytes = try await keyboardValue(.switchMatrixState, parameters: [UInt8(offset)], count: batch * bytesPerRow)
                state += Self.unpackMatrixRows(bytes, rows: batch, cols: cols)
                offset += batch
            }
        } else {
            let bytes = try await keyboardValue(.switchMatrixState, count: rows * bytesPerRow)
            state = Self.unpackMatrixRows(bytes, rows: rows, cols: cols)
        }
        return state
    }

    /// Each row is `ceil(cols / 8)` bytes, most significant byte first, bit n is column n.
    static func unpackMatrixRows(_ bytes: [UInt8], rows: Int, cols: Int) -> [[Bool]] {
        let bytesPerRow = (cols + 7) / 8
        return (0..<rows).map { row in
            var value: UInt32 = 0
            for i in 0..<bytesPerRow {
                value = (value << 8) | UInt32(bytes[row * bytesPerRow + i])
            }
            return (0..<cols).map { col in (value >> col) & 1 == 1 }
        }
    }

    // MARK: Keymap

    public func keycode(layer: Int, row: Int, col: Int) async throws -> UInt16 {
        let reply = try await send(.getKeycode, [UInt8(layer), UInt8(row), UInt8(col)])
        return try reply.bigEndianUInt16(at: 4, command: .getKeycode)
    }

    public func setKeycode(_ keycode: UInt16, layer: Int, row: Int, col: Int) async throws {
        try await send(.setKeycode, [UInt8(layer), UInt8(row), UInt8(col)] + keycode.bigEndianBytes)
    }

    /// Reads the whole dynamic keymap (all layers) through the buffer command.
    public func readKeymap(layers: Int, rows: Int, cols: Int) async throws -> Keymap {
        let byteCount = layers * rows * cols * 2
        let bytes = try await readBuffer(command: .getKeymapBuffer, size: byteCount)
        let codes = stride(from: 0, to: bytes.count, by: 2).map { UInt16(bytes[$0]) << 8 | UInt16(bytes[$0 + 1]) }
        return Keymap(layers: layers, rows: rows, cols: cols, codes: codes)
    }

    /// Writes the whole dynamic keymap. Used by restore; single edits use `setKeycode`.
    public func writeKeymap(_ keymap: Keymap) async throws {
        let bytes = keymap.codes.flatMap(\.bigEndianBytes)
        try await writeBuffer(command: .setKeymapBuffer, bytes: bytes)
    }

    public func resetKeymap() async throws {
        try await send(.resetKeymap)
    }

    // MARK: Encoders

    public func encoderKeycode(layer: Int, encoder: Int, clockwise: Bool) async throws -> UInt16 {
        let reply = try await send(.getEncoder, [UInt8(layer), UInt8(encoder), clockwise ? 1 : 0])
        return try reply.bigEndianUInt16(at: 4, command: .getEncoder)
    }

    public func setEncoderKeycode(_ keycode: UInt16, layer: Int, encoder: Int, clockwise: Bool) async throws {
        try await send(.setEncoder, [UInt8(layer), UInt8(encoder), clockwise ? 1 : 0] + keycode.bigEndianBytes)
    }

    public func readEncoders(layers: Int, encoders: Int) async throws -> EncoderMap {
        var map = EncoderMap(layers: layers, encoders: encoders)
        for layer in 0..<layers {
            for encoder in 0..<encoders {
                for clockwise in [false, true] {
                    map[layer, encoder, clockwise] = try await encoderKeycode(layer: layer, encoder: encoder, clockwise: clockwise)
                }
            }
        }
        return map
    }

    // MARK: Custom values (lighting and keyboard-specific menus)

    /// Reads a custom value. `path` is channel, value id and any extra bytes from the
    /// definition's menu `content`; the data follows the path in the reply.
    public func customValue(path: [UInt8], count: Int) async throws -> [UInt8] {
        let reply = try await send(.customGetValue, path)
        return try reply.bytes(from: 1 + path.count, count: count, command: .customGetValue)
    }

    public func setCustomValue(path: [UInt8], _ bytes: [UInt8]) async throws {
        try await send(.customSetValue, path + bytes)
    }

    public func customValue(channel: UInt8, valueID: UInt8, count: Int) async throws -> [UInt8] {
        try await customValue(path: [channel, valueID], count: count)
    }

    public func setCustomValue(channel: UInt8, valueID: UInt8, _ bytes: [UInt8]) async throws {
        try await setCustomValue(path: [channel, valueID], bytes)
    }

    /// Persists a channel's values to EEPROM. Without it, set values are lost on unplug.
    public func saveCustomValues(channel: UInt8) async throws {
        try await send(.customSave, [channel])
    }

    // MARK: Macros

    public func macroCount() async throws -> Int {
        let reply = try await send(.macroGetCount)
        return Int(try reply.byte(at: 1, command: .macroGetCount))
    }

    public func macroBufferSize() async throws -> Int {
        let reply = try await send(.macroGetBufferSize)
        return Int(try reply.bigEndianUInt16(at: 1, command: .macroGetBufferSize))
    }

    public func readMacroBuffer(size: Int) async throws -> [UInt8] {
        try await readBuffer(command: .macroGetBuffer, size: size)
    }

    public func writeMacroBuffer(_ bytes: [UInt8]) async throws {
        try await writeBuffer(command: .macroSetBuffer, bytes: bytes)
    }

    public func resetMacros() async throws {
        try await send(.macroReset)
    }

    // MARK: Dangerous

    /// Wipes keymap, macros and VIA settings back to firmware defaults.
    public func eepromReset() async throws {
        try await send(.eepromReset)
    }

    /// Reboots into the bootloader. The device disappears and does not answer.
    public func jumpToBootloader() async throws {
        _ = try? await transport.exchange([VIACommand.bootloaderJump.rawValue], timeout: .milliseconds(100)) { _ in true }
    }

    // MARK: Buffers

    func readBuffer(command: VIACommand, size: Int) async throws -> [UInt8] {
        guard size <= Int(UInt16.max) else { throw VIAError.invalidArgument("Buffer size \(size) exceeds 16 bits.") }
        var result: [UInt8] = []
        result.reserveCapacity(size)
        var offset = 0
        while offset < size {
            let chunk = min(Self.maxChunk, size - offset)
            let reply = try await send(command, UInt16(offset).bigEndianBytes + [UInt8(chunk)])
            result += try reply.bytes(from: 4, count: chunk, command: command)
            offset += chunk
        }
        return result
    }

    func writeBuffer(command: VIACommand, bytes: [UInt8]) async throws {
        guard bytes.count <= Int(UInt16.max) else { throw VIAError.invalidArgument("Buffer size \(bytes.count) exceeds 16 bits.") }
        var offset = 0
        while offset < bytes.count {
            let chunk = Array(bytes[offset..<min(offset + Self.maxChunk, bytes.count)])
            try await send(command, UInt16(offset).bigEndianBytes + [UInt8(chunk.count)] + chunk)
            offset += chunk.count
        }
    }
}
