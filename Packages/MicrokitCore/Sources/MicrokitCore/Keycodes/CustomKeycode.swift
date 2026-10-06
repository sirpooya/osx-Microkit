/// A keyboard-specific keycode declared by the definition's `customKeycodes`.
/// Entry n is QMK's `QK_KB_n` (0x7E00 + n).
public struct CustomKeycode: Codable, Hashable, Sendable {
    public let name: String
    public let title: String?
    public let shortName: String?

    public init(name: String, title: String? = nil, shortName: String? = nil) {
        self.name = name
        self.title = title
        self.shortName = shortName
    }
}
