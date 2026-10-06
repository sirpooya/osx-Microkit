/// A light zone music mode can drive: a definition menu section with a color control,
/// such as "Underglow" (rgblight) or "Backlight" (RGB matrix).
public struct MusicTarget: Identifiable, Hashable, Sendable {
    public let title: String
    public let channel: UInt8
    public let colorPath: [UInt8]
    public let brightnessPath: [UInt8]?
    /// Top of the brightness control's range (255 on most boards).
    public let brightnessMax: Int
    public let effectPath: [UInt8]?
    /// The effect value that shows one solid color ("Solid Color" in VIA menus, else 1).
    public let solidEffect: UInt8

    public var id: String { title + "\(channel)" }

    /// Every zone in the definition's menus that has a color control.
    public static func targets(in pages: [MenuPage]) -> [MusicTarget] {
        pages.flatMap(\.sections).compactMap { section in
            guard let color = section.controls.first(where: { $0.kind == .color }) else { return nil }
            let sameChannel = section.controls.filter { $0.channel == color.channel }
            let brightness = sameChannel.first { control in
                if case .range = control.kind { return control.valueName.contains("brightness") }
                return false
            }
            let effect = sameChannel.first { control in
                if case .dropdown = control.kind { return control.valueName.contains("effect") && !control.valueName.contains("speed") }
                return false
            }
            var brightnessMax = 255
            if let brightness, case .range(_, let max) = brightness.kind { brightnessMax = max }
            var solid: UInt8 = 1
            if let effect, case .dropdown(let choices) = effect.kind,
               let choice = choices.first(where: { $0.label.lowercased().hasPrefix("solid") }) {
                solid = UInt8(clamping: choice.value)
            }
            return MusicTarget(title: section.title, channel: color.channel, colorPath: color.path,
                               brightnessPath: brightness?.path, brightnessMax: brightnessMax, effectPath: effect?.path, solidEffect: solid)
        }
    }
}
