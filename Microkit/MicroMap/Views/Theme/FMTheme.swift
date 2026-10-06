import AppKit
import SwiftUI

/// Design tokens transcribed from the Figma Micro App file (page "Agent").
/// Light values match the mockups exactly; dark values are derived from the
/// same roles using macOS dark-appearance conventions.
enum FMTheme {
    // MARK: Colors

    /// Window content backdrop behind the controller preview (`--fm-color-canvas`).
    static let canvas = dynamicColor(light: NSColor(hex: 0xF5F5F5), dark: NSColor(hex: 0x1E1E20))

    /// Toolbar and inspector surfaces (`--fm-color-panel`).
    static let panel = dynamicColor(light: NSColor(hex: 0xFCFCFD), dark: NSColor(hex: 0x28282A))

    /// Sidebar, cards, and floating-bar surfaces (`--fm-color-control-surface`).
    static let controlSurface = dynamicColor(light: .white, dark: NSColor(hex: 0x2E2E31))

    /// Search field, unassigned chips, and unselected keycap rows.
    static let fieldFill = dynamicColor(light: NSColor(hex: 0xF2F3F8), dark: NSColor(hex: 0x3A3A3E))

    /// Background of the expanded, selected action group.
    static let groupFill = dynamicColor(
        light: NSColor(hex: 0xF4F9FF),
        dark: NSColor(hex: 0x2A3038)
    )

    /// Header row of the expanded, selected action group.
    static let groupHeaderFill = dynamicColor(
        light: NSColor(hex: 0xE8F4FE),
        dark: NSColor(hex: 0x32404E)
    )

    /// Selected row in the sidebar mode switcher and lights target list.
    static let navSelectionFill = dynamicColor(
        light: NSColor(hex: 0xF0F0F2),
        dark: NSColor(white: 1, alpha: 0.10)
    )

    /// Subtle pointer hover used by interactive sidebar rows.
    static let hoverFill = dynamicColor(
        light: NSColor(white: 0, alpha: 0.045),
        dark: NSColor(white: 1, alpha: 0.065)
    )

    /// Hairlines between panels and sections (`--fm-color-separator`).
    static let separator = Color(nsColor: .separatorColor)

    /// Border of white value chips (assigned shortcut, selected keycap color).
    static let chipBorder = dynamicColor(
        light: NSColor(hex: 0xE7E9EF),
        dark: NSColor(white: 1, alpha: 0.14)
    )

    /// Midpoint detent dot inside the FMSlider track.
    static let sliderDot = dynamicColor(
        light: NSColor(hex: 0xC2C4CB),
        dark: NSColor(white: 1, alpha: 0.30)
    )

    /// Border of keycap chips inside shortcut rows.
    static let keycapBorder = dynamicColor(
        light: NSColor(hex: 0xDEDFE0),
        dark: NSColor(white: 1, alpha: 0.18)
    )

    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let accent = Color(nsColor: .controlAccentColor)

    static let connectedGreen = Color(nsColor: .systemGreen)
    static let disconnectedRed = Color(nsColor: .systemRed)
    static let blockedOrange = Color(nsColor: .systemOrange)

    /// Ephemeral confirmation surface. Intentionally stays dark in both
    /// appearances to match Figma's in-canvas toast treatment.
    static let toastBackground = Color(
        .sRGB,
        red: 45 / 255,
        green: 45 / 255,
        blue: 45 / 255,
        opacity: 1
    )
    static let toastText = Color.white

    // MARK: Typography (Figma Micro styles; Inter in the mockups maps to SF)

    /// Figma Micro/Headline — 13 semibold.
    static let headline = Font.system(size: 13, weight: .semibold)
    /// Figma Micro/Body — 13 regular.
    static let body = Font.system(size: 13)
    /// Figma Micro/Caption — 11 regular.
    static let caption = Font.system(size: 11)
    /// Figma Micro/Caption Emphasized — 11 medium.
    static let captionEmphasized = Font.system(size: 11, weight: .medium)
    /// Value chips inside inspector fields.
    static let chip = Font.system(size: 11)

    // MARK: Metrics

    static let sidebarWidth: CGFloat = 275
    static let inspectorWidth: CGFloat = 208
    static let toolbarHeight: CGFloat = 52
    static let rowHeight: CGFloat = 32

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Hairline used between the fixed columns of the main window.
struct FMPanelDivider: View {
    var body: some View {
        Rectangle()
            .fill(FMTheme.separator)
            .frame(width: 1)
    }
}

/// Full-width hairline between inspector sections.
struct FMSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(FMTheme.separator)
            .frame(height: 1)
    }
}
