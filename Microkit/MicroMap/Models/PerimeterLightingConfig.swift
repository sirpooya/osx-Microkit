import Foundation

/// A preset selectable for one lighting zone. Conforming enums map presets to
/// QMK mode numbers, which are firmware-specific: QMK numbers modes across the
/// effects enabled in the tested Creator Micro firmware only.
protocol LightingZonePreset: Codable, CaseIterable, Identifiable, Hashable, Sendable
where AllCases: RandomAccessCollection {
    var title: String { get }
    var isAnimated: Bool { get }
    var usesColor: Bool { get }
    var isOff: Bool { get }
    func modeByte(forSpeed speed: Double) -> UInt8
}

/// Perimeter presets map to QMK RGB Light modes. The tested firmware enables
/// breathing, rainbow mood, rainbow swirl, snake, knight, christmas, static
/// gradient, and twinkle.
enum PerimeterLightingPreset: String, LightingZonePreset {
    case off
    case solid
    case breathing
    case rainbowMood
    case rainbowSwirl
    case snake
    case knight
    case twinkle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .solid: "Solid color"
        case .breathing: "Breathing"
        case .rainbowMood: "Rainbow mood"
        case .rainbowSwirl: "Rainbow swirl"
        case .snake: "Snake"
        case .knight: "Knight rider"
        case .twinkle: "Twinkle"
        }
    }

    var baseMode: UInt8 {
        switch self {
        case .off: 0
        case .solid: 1
        case .breathing: 2
        case .rainbowMood: 6
        case .rainbowSwirl: 9
        case .snake: 15
        case .knight: 21
        case .twinkle: 35
        }
    }

    /// Mode offsets selectable by the speed control, ordered slow to fast.
    /// Swirl and snake skip the reversed-direction variants so raising the
    /// speed never flips the animation direction.
    var speedVariantOffsets: [UInt8] {
        switch self {
        case .off, .solid: [0]
        case .breathing: [0, 1, 2, 3]
        case .rainbowMood: [0, 1, 2]
        case .rainbowSwirl: [0, 2, 4]
        case .snake: [0, 2, 4]
        case .knight: [0, 1, 2]
        case .twinkle: [0, 1, 2, 3, 4, 5]
        }
    }

    var isAnimated: Bool { speedVariantOffsets.count > 1 }

    /// Rainbow effects generate their own hues and only honor saturation,
    /// which must stay at full scale to render colors instead of white.
    var usesColor: Bool {
        switch self {
        case .off, .rainbowMood, .rainbowSwirl: false
        case .solid, .breathing, .snake, .knight, .twinkle: true
        }
    }

    var isOff: Bool { self == .off }

    func modeByte(forSpeed speed: Double) -> UInt8 {
        let offsets = speedVariantOffsets
        let clamped = min(max(speed, 0), 1)
        let index = Int((clamped * Double(offsets.count - 1)).rounded())
        return baseMode + offsets[index]
    }
}

/// Key-matrix presets map to QMK RGB Matrix modes. The tested firmware enables
/// all 30 optional animations, so solid=1, breathing=5, cycle all=12,
/// raindrops=23, and the framebuffer effects land at 31 and 32. Unlike RGB
/// Light, RGB Matrix honors the raw speed value directly.
enum KeyLightingPreset: String, LightingZonePreset {
    case off
    case solid
    case breathing
    case rainbowCycle
    case raindrops
    case typingHeatmap
    case digitalRain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .solid: "Solid color"
        case .breathing: "Breathing"
        case .rainbowCycle: "Rainbow cycle"
        case .raindrops: "Raindrops"
        case .typingHeatmap: "Typing heatmap"
        case .digitalRain: "Digital rain"
        }
    }

    var mode: UInt8 {
        switch self {
        case .off: 0
        case .solid: 1
        case .breathing: 5
        case .rainbowCycle: 12
        case .raindrops: 23
        case .typingHeatmap: 31
        case .digitalRain: 32
        }
    }

    var isAnimated: Bool {
        switch self {
        case .off, .solid: false
        case .breathing, .rainbowCycle, .raindrops, .typingHeatmap, .digitalRain: true
        }
    }

    var usesColor: Bool {
        switch self {
        case .solid, .breathing: true
        case .off, .rainbowCycle, .raindrops, .typingHeatmap, .digitalRain: false
        }
    }

    var isOff: Bool { self == .off }

    func modeByte(forSpeed speed: Double) -> UInt8 { mode }
}

struct LightingZoneConfig<Preset: LightingZonePreset>: Codable, Equatable, Sendable {
    var preset: Preset
    /// 0...1 of the VIA brightness range; the firmware caps output at 150/255.
    var brightness: Double
    /// 0...1 — perimeter presets select speed variants, key presets send it raw.
    var speed: Double
    /// 0...1 around the hue wheel.
    var hue: Double
    /// 0...1; 0 renders white.
    var saturation: Double

    var modeByte: UInt8 { preset.modeByte(forSpeed: speed) }
    var brightnessByte: UInt8 { Self.byte(brightness) }
    var speedByte: UInt8 { Self.byte(speed) }
    var hueByte: UInt8 { Self.byte(hue) }
    var saturationByte: UInt8 { preset.usesColor ? Self.byte(saturation) : 255 }

    private static func byte(_ unit: Double) -> UInt8 {
        UInt8(min(255, max(0, (unit * 255).rounded())))
    }
}

typealias PerimeterLightingConfig = LightingZoneConfig<PerimeterLightingPreset>
typealias KeyLightingConfig = LightingZoneConfig<KeyLightingPreset>

extension PerimeterLightingConfig {
    static let off = PerimeterLightingConfig(
        preset: .off, brightness: 0, speed: 0, hue: 0, saturation: 0
    )
}

extension KeyLightingConfig {
    static let off = KeyLightingConfig(
        preset: .off, brightness: 0, speed: 0, hue: 0, saturation: 0
    )
}

struct LightingConfiguration: Codable, Equatable, Sendable {
    var inFigma: PerimeterLightingConfig
    var outsideFigma: PerimeterLightingConfig
    var keysInFigma: KeyLightingConfig
    var onlyUseKeyLightingInFigma: Bool

    static let `default` = LightingConfiguration(
        inFigma: .init(preset: .rainbowSwirl, brightness: 200 / 255, speed: 0.5, hue: 0.5, saturation: 1),
        outsideFigma: .init(preset: .breathing, brightness: 40 / 255, speed: 0, hue: 0, saturation: 0),
        keysInFigma: .init(preset: .solid, brightness: 1, speed: 0.5, hue: 138 / 255, saturation: 210 / 255),
        onlyUseKeyLightingInFigma: true
    )

    init(
        inFigma: PerimeterLightingConfig,
        outsideFigma: PerimeterLightingConfig,
        keysInFigma: KeyLightingConfig,
        onlyUseKeyLightingInFigma: Bool = true
    ) {
        self.inFigma = inFigma
        self.outsideFigma = outsideFigma
        self.keysInFigma = keysInFigma
        self.onlyUseKeyLightingInFigma = onlyUseKeyLightingInFigma
    }

    // Configurations persisted before key lighting existed lack the key zone;
    // fall back to the default so perimeter settings survive the upgrade.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inFigma = try container.decode(PerimeterLightingConfig.self, forKey: .inFigma)
        outsideFigma = try container.decode(PerimeterLightingConfig.self, forKey: .outsideFigma)
        keysInFigma = try container.decodeIfPresent(KeyLightingConfig.self, forKey: .keysInFigma)
            ?? Self.default.keysInFigma
        onlyUseKeyLightingInFigma = try container.decodeIfPresent(
            Bool.self,
            forKey: .onlyUseKeyLightingInFigma
        ) ?? true
    }
}
