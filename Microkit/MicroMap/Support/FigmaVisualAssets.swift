import AppKit
import SwiftUI

extension Color {
    static let figmaCharcoal = Color(red: 49 / 255, green: 49 / 255, blue: 49 / 255)
    // Microkit: key base fills from the Work Louder x Figma "Key" component set (node 2003:517).
    static let figmaRed = Color(hex: 0xFA5737)
    static let figmaPink = Color(hex: 0xFF8076)
    static let figmaPurple = Color(hex: 0xA85FF5)
    static let figmaBlue = Color(hex: 0x2BC7F8)
    static let figmaGreen = Color(hex: 0x01D488)
    static let figmaKeyBlack = Color(hex: 0x2B2B2B)

    fileprivate init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

@MainActor
enum FigmaAssetLoader {
    private static var cache: [String: NSImage] = [:]

    @MainActor
    static func image(named fileName: String) -> NSImage? {
        if let cached = cache[fileName] { return cached }

        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "MicroMap/FigmaAssets")
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "FigmaAssets")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
        guard let url, let image = NSImage(contentsOf: url) else {
            return nil
        }
        cache[fileName] = image
        return image
    }
}

struct FigmaAssetImage: View {
    let fileName: String
    var template = false

    var body: some View {
        if let image = FigmaAssetLoader.image(named: fileName) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(template ? .template : .original)
                .aspectRatio(contentMode: .fit)
        }
    }
}

struct ActionGlyph: View {
    let action: FigmaAction?
    var size: CGFloat = 22
    var tint: Color = .white

    /// Microkit: the newer "Tool Icon" set (`tool-*.svg`) draws a 16 pt glyph on a 40 pt grid,
    /// MicroMap's MicroIcons about a 22 pt glyph on a 32 pt grid. Tool Icons are drawn this much
    /// larger so a glyph of either set comes out the same size in the same `size` slot.
    static let toolIconScale: CGFloat = (22.0 / 32.0) / (16.0 / 40.0)

    var body: some View {
        Group {
            if let asset = action?.figmaAssetName {
                let scale = asset.hasPrefix("tool-") ? Self.toolIconScale : 1
                FigmaAssetImage(fileName: asset, template: true)
                    .frame(width: size * scale, height: size * scale)
            } else {
                Color.clear
            }
        }
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum KeycapColor: String, Codable, CaseIterable, Identifiable {
    case red
    case pink
    case purple
    case blue
    case green

    var id: String { rawValue }

    /// Microkit: named after the Figma "Key" variants. The raw values stay: they are stored in drafts.
    var title: String {
        switch self {
        case .pink: "Coral"
        case .purple: "Violet"
        default: rawValue.capitalized
        }
    }
    var inventoryLimit: Int { 3 }

    var appearance: FigmaKeyAppearance {
        switch self {
        case .red: .red
        case .pink: .pink
        case .purple: .purple
        case .blue: .blue
        case .green: .green
        }
    }

    var swatch: Color {
        switch self {
        case .red: .figmaRed
        case .pink: .figmaPink
        case .purple: .figmaPurple
        case .blue: .figmaBlue
        case .green: .figmaGreen
        }
    }
}

extension FigmaAction {
    var figmaAssetName: String? {
        switch id {
        case "system-open-figma": "Figma Logo.svg"
        // Microkit: the Tool Icon set (node 2003:489) where it has a glyph for the action.
        case "tools-move": "tool-move.svg"
        case "tools-frame", "selection-frame": "tool-frame.svg"
        case "tools-rectangle": "tool-rectangle.svg"
        case "tools-pen", "shape-pen": "tool-pen.svg"
        case "transform-edit": "tool-edit-vector.svg"
        case "tools-ellipse": "Ellipse.svg"
        case "tools-pencil", "shape-pencil": "Pencil.svg"
        case "tools-text": "Text.svg"
        case "tools-line": "Line.svg"
        case "tools-arrow": "Arrow.svg"
        case "tools-comments": "Comment.svg"
        case "selection-lock": "Lock.svg"
        case "zoom-pan": "Hand.svg"
        case "essential-component-search", "components-search", "edit-find": "Search.svg"
        case "transform-mask": "Mask.svg"
        case "transform-place", "edit-copy-png": "Image.svg"
        case "essential-actions": "Resources.svg"
        case "text-link": "Constrain.svg"
        case "components-create": "Component.svg"
        case "essential-present": "Play.svg"
        case "arrange-align-left": "Layout Align Left.svg"
        case "arrange-center-horizontal": "Layout Align Horiz Centers.svg"
        case "arrange-align-right": "Layout Align Right.svg"
        case "arrange-align-top": "Layout Align Top.svg"
        case "arrange-center-vertical": "Layout Align Vertical Centers.svg"
        case "arrange-align-bottom": "Layout Align Bottom.svg"
        case "arrange-distribute-vertical": "Distribute Vertical Spacing.svg"
        case "arrange-distribute-horizontal": "Distribute Horiz Spacing.svg"
        default: nil
        }
    }
}

enum FigmaKeyAppearance {
    case black
    case red
    case pink
    case purple
    case blue
    case green
    case figma
    case layers

    static func appearance(for slotID: String) -> FigmaKeyAppearance {
        switch slotID {
        case "key-2": .red
        case "key-11": .figma
        case "key-12": .blue
        case "key-13": .green
        case "key-14": .layers
        default: .black
        }
    }

    var supportsPrintedIcon: Bool {
        switch self {
        case .black: true
        case .red, .pink, .purple, .blue, .green, .figma, .layers: false
        }
    }
}

struct FigmaKeySurface: View {
    let appearance: FigmaKeyAppearance

    // Microkit: drawn from the Figma "Key" components instead of MicroMap's Btn=*.png textures.
    var body: some View {
        switch appearance {
        case .figma:
            Color.clear
        case .layers:
            Color.clear
        case .black:
            FigmaKeycap(style: .black)
        case .red:
            FigmaKeycap(style: .red)
        case .pink:
            FigmaKeycap(style: .coral)
        case .purple:
            FigmaKeycap(style: .violet)
        case .blue:
            FigmaKeycap(style: .blue)
        case .green:
            FigmaKeycap(style: .green)
        }
    }
}

/// Microkit: one keycap of the "Key" component set on the "new" page of the Work Louder x Figma
/// file (node 2003:517), drawn natively because its SVG export relies on blur and blend effects
/// that NSImage does not render. All numbers are that component's, on its 100 pt grid: a key base
/// (corner 24) with a soft glow of its own color 16 pt up, and an "indented circle" inset 11.16 pt,
/// a two-tone gradient with a light rim along its bottom edge, blended onto the base.
struct FigmaKeycap: View {
    struct Style {
        var base: Color
        var glow: Color
        var circleOpacity: Double = 1
        var blend: BlendMode = .hardLight
        var shade: Color
        var light: Color
        var rim: Color
        var rimOffset: CGFloat = 3
        var rimBlur: CGFloat = 0

        static let red = Style(
            base: .figmaRed, glow: Color(hex: 0xFA5737, opacity: 0.2), circleOpacity: 0.4,
            shade: .black.opacity(0.25), light: .white.opacity(0.07), rim: .white.opacity(0.35)
        )
        static let coral = Style(
            base: .figmaPink, glow: Color(hex: 0xFF8076, opacity: 0.2), blend: .overlay,
            shade: .black.opacity(0.25), light: .white.opacity(0.11), rim: .white.opacity(0.25),
            rimOffset: 2, rimBlur: 1
        )
        static let violet = Style(
            base: .figmaPurple, glow: Color(hex: 0xA85FF5, opacity: 0.2), blend: .overlay,
            shade: .black.opacity(0.25), light: .white.opacity(0.3), rim: .white.opacity(0.35)
        )
        static let blue = Style(
            base: .figmaBlue, glow: Color(hex: 0x2BC7F8, opacity: 0.2),
            shade: Color(hex: 0x002A69, opacity: 0.14), light: Color(hex: 0x48E9FF, opacity: 0.33),
            rim: .white.opacity(0.35)
        )
        static let green = Style(
            base: .figmaGreen, glow: Color(hex: 0x01D488, opacity: 0.2),
            shade: .black.opacity(0.12), light: Color(hex: 0xC7FF9B, opacity: 0.49), rim: .white.opacity(0.35)
        )
        static let black = Style(
            base: .figmaKeyBlack, glow: .white.opacity(0.03),
            shade: .black.opacity(0.3), light: .white.opacity(0.1), rim: .white.opacity(0.15)
        )
    }

    let style: Style

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let unit = side / 100

            ZStack {
                RoundedRectangle(cornerRadius: 24 * unit)
                    .fill(style.base)
                    .shadow(color: style.glow, radius: 7 * unit, y: -16 * unit)

                indentedCircle(unit: unit)
                    .frame(width: 77.6835 * unit, height: 77.6835 * unit)
            }
            .frame(width: side, height: side)
            .compositingGroup()
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func indentedCircle(unit: CGFloat) -> some View {
        ZStack {
            // The circle's drop shadow is clipped to outside the circle, which leaves a light rim
            // showing below its bottom edge.
            KeycapRim(offset: style.rimOffset * unit)
                .fill(style.rim)
                .blur(radius: style.rimBlur * unit)

            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: style.shade, location: 0),
                            .init(color: style.shade.opacity(0), location: 0.489583),
                            .init(color: style.light.opacity(0), location: 0.520833),
                            .init(color: style.light, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .compositingGroup()
        .opacity(style.circleOpacity)
        .blendMode(style.blend)
    }
}

/// The part of the circle moved down by `offset` that falls outside the circle itself.
private struct KeycapRim: Shape {
    var offset: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: rect.offsetBy(dx: 0, dy: offset))
            .subtracting(Path(ellipseIn: rect))
    }
}
