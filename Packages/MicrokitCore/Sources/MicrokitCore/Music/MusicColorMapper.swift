/// Turns `AudioFeatures` into a keyboard color, with fast attack and slow release so the lights
/// snap to hits and fade smoothly instead of flickering.
public struct MusicColorMapper: Sendable {
    public var style: MusicStyle
    /// Hue used by Pulse, 0...1.
    public var baseHue: Float
    /// 0.5 (calm) to 2 (jumpy).
    public var sensitivity: Float
    /// Brightness never drops below this share of full, so the board never goes fully dark.
    public var floor: Float

    private var brightness: Float = 0
    private var hue: Float = 0
    private var rainbowHue: Float = 0

    public init(style: MusicStyle = .spectrum, baseHue: Float = 0.75, sensitivity: Float = 1, floor: Float = 0.08) {
        self.style = style
        self.baseHue = baseHue
        self.sensitivity = sensitivity
        self.floor = floor
        hue = baseHue
    }

    public mutating func frame(for features: AudioFeatures) -> MusicLightFrame {
        let gain = max(0.25, sensitivity)
        let target: Float
        let saturation: Float = 1
        switch style {
        case .spectrum:
            let total = features.bass + features.mid + features.treble
            if total > 0.01 {
                // 0 for pure bass, 1 for pure treble; red (0) to blue (0.66).
                let position = (features.mid * 0.5 + features.treble) / total
                hue = blend(hue, position * 0.66, 0.25)
            }
            target = features.level * 0.6 + features.bass * 0.4
        case .pulse:
            hue = baseHue
            target = max(features.bass, features.isBeat ? 1 : 0)
        case .beatRainbow:
            if features.isBeat { rainbowHue = (rainbowHue + 0.13).truncatingRemainder(dividingBy: 1) }
            rainbowHue = (rainbowHue + 0.0015).truncatingRemainder(dividingBy: 1)
            hue = rainbowHue
            target = max(features.level * 0.7, features.isBeat ? 1 : 0)
        }

        let goal = min(1, target * gain)
        if features.isBeat {
            brightness = max(brightness, goal) // a hit flashes at once
        } else if goal > brightness {
            brightness = blend(brightness, goal, 0.7)
        } else {
            brightness = brightness * 0.88 + goal * 0.12
        }
        let shown = floor + (1 - floor) * brightness
        return MusicLightFrame(hue: Self.byte(hue), saturation: Self.byte(saturation), brightness: Self.byte(shown))
    }

    private func blend(_ from: Float, _ to: Float, _ amount: Float) -> Float {
        from + (to - from) * amount
    }

    static func byte(_ value: Float) -> UInt8 {
        UInt8(max(0, min(255, (value * 255).rounded())))
    }
}
