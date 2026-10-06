import AppKit
import SwiftUI

/// Measured visual constants. Keyboard sizes are fractions of one key unit (1u).
enum Theme {
    enum Keyboard {
        static let maxUnit: CGFloat = 64
        static let minUnit: CGFloat = 30
        static let gapFraction: CGFloat = 0.07
        static let cornerFraction: CGFloat = 0.14
        static let dishInsetFraction: CGFloat = 0.08
        static let dishTopFraction: CGFloat = 0.03
        static let dishBottomFraction: CGFloat = 0.13
        static let canvasPadding: CGFloat = 28
        /// The keyboard never takes more than this share of the keymap screen's height.
        static let maxHeightShare: CGFloat = 0.5
        static let selectionLineWidth: CGFloat = 2.5
    }

    enum Picker {
        static let cellSize: CGFloat = 54
        static let cellSpacing: CGFloat = 6
        static let categoryWidth: CGFloat = 168
    }

    enum Keycap {
        static let alpha = dynamic(light: NSColor(white: 0.985, alpha: 1), dark: NSColor(white: 0.30, alpha: 1))
        static let alphaSkirt = dynamic(light: NSColor(white: 0.86, alpha: 1), dark: NSColor(white: 0.20, alpha: 1))
        static let mod = dynamic(light: NSColor(white: 0.90, alpha: 1), dark: NSColor(white: 0.23, alpha: 1))
        static let modSkirt = dynamic(light: NSColor(white: 0.78, alpha: 1), dark: NSColor(white: 0.15, alpha: 1))
        static let legend = dynamic(light: NSColor(white: 0.12, alpha: 1), dark: NSColor(white: 0.94, alpha: 1))
        static let plate = dynamic(light: NSColor(white: 0.80, alpha: 1), dark: NSColor(white: 0.10, alpha: 1))
        static let tested = Color.green
    }

    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) == nil ? light : dark
        })
    }
}
