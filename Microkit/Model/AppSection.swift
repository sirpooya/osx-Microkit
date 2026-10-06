/// The sidebar destinations for a connected keyboard.
enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case keymap, lighting, music, macros, keyTester, device

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keymap: "Keymap"
        case .lighting: "Lighting"
        case .music: "Music"
        case .macros: "Macros"
        case .keyTester: "Key Tester"
        case .device: "Device"
        }
    }

    var symbol: String {
        switch self {
        case .keymap: "keyboard"
        case .lighting: "lightbulb.max"
        case .music: "waveform"
        case .macros: "text.append"
        case .keyTester: "hand.tap"
        case .device: "info.circle"
        }
    }
}
