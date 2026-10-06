import AppKit
import MicrokitCore
import SwiftUI

/// Music mode: a live visualizer of what is playing, and the controls for the keyboard's lights.
struct MusicScreen: View {
    @Bindable var music: MusicController

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MusicVisualizer(features: music.features, frame: music.frame, isRunning: music.isRunning)
                    .frame(height: 240)
                MusicStartBar(music: music)
                MusicSettingsForm(music: music)
            }
            .padding(24)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }
}
