import Foundation

public enum VIAError: Error, Equatable, Sendable, LocalizedError {
    /// No matching reply arrived in time.
    case timeout(command: UInt8)
    /// The firmware answered 0xFF: it does not support this command or value id.
    case unhandled(command: UInt8)
    /// The reply was shorter than the data it should carry.
    case malformedReply(command: UInt8)
    /// The HID layer failed (device unplugged, permission, I/O error).
    case transport(String)
    /// The arguments cannot be encoded (layer, row, offset out of range).
    case invalidArgument(String)

    public var errorDescription: String? {
        switch self {
        case .timeout(let command):
            String(format: "The keyboard did not answer command 0x%02X.", command)
        case .unhandled(let command):
            String(format: "The keyboard does not support command 0x%02X.", command)
        case .malformedReply(let command):
            String(format: "The keyboard sent a malformed reply to command 0x%02X.", command)
        case .transport(let message):
            message
        case .invalidArgument(let message):
            message
        }
    }
}
