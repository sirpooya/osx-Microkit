/// One control of a VIA custom menu, bound to a custom value on the keyboard.
public struct MenuControl: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case range(min: Int, max: Int)
        case dropdown([MenuChoice])
        case toggle(off: Int, on: Int)
        /// Hue and saturation, one byte each.
        case color
        case unsupported(String)
    }

    /// The value's name from the definition, for example `id_qmk_rgblight_brightness`.
    /// `showIf` expressions refer to values by this name.
    public let valueName: String
    public let label: String
    public let kind: Kind
    /// Channel, value id and any extra bytes: what follows the command id on the wire.
    public let path: [UInt8]
    public let showIf: String?

    public var id: String { valueName + path.map(String.init).joined(separator: ".") }
    public var channel: UInt8 { path.first ?? 0 }

    /// Bytes the value occupies on the wire.
    public var byteCount: Int {
        switch kind {
        case .range(_, let max): max > 255 ? 2 : 1
        case .color: 2
        default: 1
        }
    }
}
