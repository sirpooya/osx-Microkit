/// What to print on a keycap for one keycode.
public struct KeyLegend: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case basic, modifier, media, mouse, combo, modTap, layerTap, layer, macro, lighting,
             custom, special, transparent, none, unknown
    }

    /// Main text: a character, glyph or short word.
    public var primary: String
    /// Optional smaller second line.
    public var secondary: String?
    /// SF Symbol shown instead of `primary` when the UI can draw symbols.
    public var symbol: String?
    public var kind: Kind
    /// QMK spelling, for example `LGUI(KC_0)` or `TO(1)`. Shown in tooltips and search.
    public var qmkName: String
    /// Plain-language description for tooltips and accessibility.
    public var help: String

    public init(primary: String, secondary: String? = nil, symbol: String? = nil, kind: Kind, qmkName: String, help: String) {
        self.primary = primary
        self.secondary = secondary
        self.symbol = symbol
        self.kind = kind
        self.qmkName = qmkName
        self.help = help
    }
}
