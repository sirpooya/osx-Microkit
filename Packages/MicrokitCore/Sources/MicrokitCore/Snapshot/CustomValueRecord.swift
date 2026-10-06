/// One custom (menu) value captured in a backup.
public struct CustomValueRecord: Codable, Hashable, Sendable {
    public let path: [UInt8]
    public let bytes: [UInt8]

    public init(path: [UInt8], bytes: [UInt8]) {
        self.path = path
        self.bytes = bytes
    }
}
