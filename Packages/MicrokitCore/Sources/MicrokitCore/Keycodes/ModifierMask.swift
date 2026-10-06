/// QMK's 5-bit modifier mask used by mod combos, mod-tap, layer-mod and one-shot mods.
/// Bit 4 marks every modifier in the mask as right-hand.
public struct ModifierMask: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) { self.rawValue = rawValue & 0x1F }

    public static let control = ModifierMask(rawValue: 0x01)
    public static let shift = ModifierMask(rawValue: 0x02)
    public static let option = ModifierMask(rawValue: 0x04)
    public static let command = ModifierMask(rawValue: 0x08)
    public static let rightHand = ModifierMask(rawValue: 0x10)

    /// Ctrl+Shift+Alt+Gui, QMK's Hyper.
    public static let hyper: ModifierMask = [.control, .shift, .option, .command]
    /// Ctrl+Shift+Alt, QMK's Meh.
    public static let meh: ModifierMask = [.control, .shift, .option]

    /// Mac glyphs in Apple's canonical order: ⌃ ⌥ ⇧ ⌘.
    public var glyphs: String {
        var text = ""
        if contains(.control) { text += "⌃" }
        if contains(.option) { text += "⌥" }
        if contains(.shift) { text += "⇧" }
        if contains(.command) { text += "⌘" }
        return text
    }

    /// QMK macro names, for example `LCTL | LGUI`.
    public var qmkName: String {
        let side = contains(.rightHand) ? "R" : "L"
        var parts: [String] = []
        if contains(.control) { parts.append(side + "CTL") }
        if contains(.shift) { parts.append(side + "SFT") }
        if contains(.option) { parts.append(side + "ALT") }
        if contains(.command) { parts.append(side + "GUI") }
        return parts.isEmpty ? "0" : parts.joined(separator: " | ")
    }
}
