import MicrokitCore
import SwiftUI

/// Spectrum bars over a glow in the color the keyboard is showing right now.
struct MusicVisualizer: View {
    let features: AudioFeatures
    let frame: MusicLightFrame
    let isRunning: Bool

    var body: some View {
        let color = Color(hue: Double(frame.hue) / 255, saturation: Double(frame.saturation) / 255,
                          brightness: isRunning ? max(0.25, Double(frame.brightness) / 255) : 0.25)
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black)
            RadialGradient(colors: [color.opacity(isRunning ? 0.9 : 0.3), color.opacity(0)], center: .bottom,
                           startRadius: 10, endRadius: 360)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            SpectrumBars(bands: features.bands, color: color)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            if !isRunning {
                Text("Press Start, then play some music.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .animation(.linear(duration: 0.05), value: features)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRunning ? "Live music visualizer" : "Music visualizer, stopped")
    }
}
