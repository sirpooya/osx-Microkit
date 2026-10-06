import Foundation

/// Everything VIA can change on a keyboard, captured so it can be put back exactly.
public struct KeyboardBackup: Codable, Equatable, Sendable {
    public var formatVersion = 1
    public var name: String
    public var vendorProductId: UInt32
    public var protocolVersion: UInt16
    public var createdAt: Date
    public var keymap: Keymap
    public var encoders: EncoderMap?
    /// The raw macro buffer, byte for byte.
    public var macroBuffer: [UInt8]?
    public var layoutOptions: UInt32?
    public var customValues: [CustomValueRecord]

    public init(name: String, vendorProductId: UInt32, protocolVersion: UInt16, createdAt: Date = .now, keymap: Keymap,
                encoders: EncoderMap? = nil, macroBuffer: [UInt8]? = nil, layoutOptions: UInt32? = nil, customValues: [CustomValueRecord] = []) {
        self.name = name
        self.vendorProductId = vendorProductId
        self.protocolVersion = protocolVersion
        self.createdAt = createdAt
        self.keymap = keymap
        self.encoders = encoders
        self.macroBuffer = macroBuffer
        self.layoutOptions = layoutOptions
        self.customValues = customValues
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> KeyboardBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(KeyboardBackup.self, from: data)
    }
}
