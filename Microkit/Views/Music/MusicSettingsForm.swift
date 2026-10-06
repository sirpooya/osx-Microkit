import MicrokitCore
import SwiftUI

struct MusicSettingsForm: View {
    @Bindable var music: MusicController
    @State private var color = Color.purple

    var body: some View {
        Form {
            Section("Style") {
                Picker("Style", selection: $music.style) {
                    ForEach(MusicStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(music.style.summary)
                    .foregroundStyle(.secondary)
                if music.style == .pulse {
                    ColorPicker("Color", selection: $color, supportsOpacity: false)
                }
            }
            Section("Lights") {
                ForEach(music.targets) { target in
                    MusicTargetToggle(music: music, title: target.title)
                }
                .disabled(music.isRunning)
            }
            Section("Feel") {
                LabeledContent("Sensitivity") {
                    Slider(value: $music.sensitivity, in: 0.5...2) {
                        Text("Sensitivity")
                    } minimumValueLabel: {
                        Text("Calm")
                    } maximumValueLabel: {
                        Text("Jumpy")
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }
                LabeledContent("Brightest") {
                    Slider(value: $music.maxBrightness, in: 0.2...1) {
                        Text("Brightest")
                    } minimumValueLabel: {
                        Text("Dim")
                    } maximumValueLabel: {
                        Text("Full")
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(minHeight: 420)
        .onAppear { color = Color(hue: music.hue, saturation: 1, brightness: 1) }
        .onChange(of: color) { updateHue() }
    }

    private func updateHue() {
        guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
        music.hue = rgb.hueComponent
    }
}
