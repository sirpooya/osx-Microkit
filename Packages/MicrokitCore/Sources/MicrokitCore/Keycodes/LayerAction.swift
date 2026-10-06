/// The layer keycodes that take only a layer number.
public enum LayerAction: String, CaseIterable, Sendable {
    case momentary, toggle, to, tapToggle, oneShot, defaultLayer, persistentDefault

    /// The QMK range holding this action.
    public var rangeDefine: String {
        switch self {
        case .momentary: "QK_MOMENTARY"
        case .toggle: "QK_TOGGLE_LAYER"
        case .to: "QK_TO"
        case .tapToggle: "QK_LAYER_TAP_TOGGLE"
        case .oneShot: "QK_ONE_SHOT_LAYER"
        case .defaultLayer: "QK_DEF_LAYER"
        case .persistentDefault: "QK_PERSISTENT_DEF_LAYER"
        }
    }

    /// QMK function name, for example `MO`.
    public var qmkFunction: String {
        switch self {
        case .momentary: "MO"
        case .toggle: "TG"
        case .to: "TO"
        case .tapToggle: "TT"
        case .oneShot: "OSL"
        case .defaultLayer: "DF"
        case .persistentDefault: "PDF"
        }
    }

    public var title: String {
        switch self {
        case .momentary: "Hold for layer"
        case .toggle: "Toggle layer"
        case .to: "Switch to layer"
        case .tapToggle: "Hold or tap-toggle layer"
        case .oneShot: "One-shot layer"
        case .defaultLayer: "Set default layer"
        case .persistentDefault: "Set default layer (saved)"
        }
    }

    public var shortTitle: String {
        switch self {
        case .momentary: "hold"
        case .toggle: "toggle"
        case .to: "go to"
        case .tapToggle: "tap-toggle"
        case .oneShot: "one-shot"
        case .defaultLayer: "default"
        case .persistentDefault: "default"
        }
    }

    init?(rangeDefine: String) {
        guard let action = Self.allCases.first(where: { $0.rangeDefine == rangeDefine }) else { return nil }
        self = action
    }
}
