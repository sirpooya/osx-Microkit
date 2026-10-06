import SwiftUI

/// The definition's key color class: `alpha`, `mod` or `accent`.
enum KeycapStyle {
    case alpha, mod, accent

    init(colorName: String?) {
        switch colorName {
        case "mod": self = .mod
        case "accent": self = .accent
        default: self = .alpha
        }
    }

    var top: AnyShapeStyle {
        switch self {
        case .alpha: AnyShapeStyle(Theme.Keycap.alpha)
        case .mod: AnyShapeStyle(Theme.Keycap.mod)
        case .accent: AnyShapeStyle(Color.accentColor.opacity(0.85))
        }
    }

    var skirt: AnyShapeStyle {
        switch self {
        case .alpha: AnyShapeStyle(Theme.Keycap.alphaSkirt)
        case .mod: AnyShapeStyle(Theme.Keycap.modSkirt)
        case .accent: AnyShapeStyle(Color.accentColor)
        }
    }

    var legend: Color {
        self == .accent ? .white : Theme.Keycap.legend
    }
}
