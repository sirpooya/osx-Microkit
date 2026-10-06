extension UInt16 {
    var bigEndianBytes: [UInt8] { [UInt8(self >> 8), UInt8(self & 0xFF)] }
}

extension UInt32 {
    var bigEndianBytes: [UInt8] { [UInt8(self >> 24), UInt8((self >> 16) & 0xFF), UInt8((self >> 8) & 0xFF), UInt8(self & 0xFF)] }

    init(bigEndianBytes bytes: [UInt8]) {
        self = bytes.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }
}

extension Array where Element == UInt8 {
    func byte(at index: Int, command: VIACommand) throws -> UInt8 {
        guard index < count else { throw VIAError.malformedReply(command: command.rawValue) }
        return self[index]
    }

    func bigEndianUInt16(at index: Int, command: VIACommand) throws -> UInt16 {
        guard index + 1 < count else { throw VIAError.malformedReply(command: command.rawValue) }
        return UInt16(self[index]) << 8 | UInt16(self[index + 1])
    }

    func bytes(from index: Int, count length: Int, command: VIACommand) throws -> [UInt8] {
        guard index + length <= count else { throw VIAError.malformedReply(command: command.rawValue) }
        return Array(self[index..<index + length])
    }
}
