import AppKit
import SwiftUI

/// Start and stop, plus what is going on.
struct MusicStartBar: View {
    let music: MusicController
    @State private var isBusy = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Button(action: toggle) {
                    Label(music.isRunning ? "Stop" : "Start", systemImage: music.isRunning ? "stop.fill" : "play.fill")
                        .frame(minWidth: 90)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status)
                        .font(.headline)
                    Text("Listens to everything playing on this Mac. Your keyboard's saved lighting is untouched and comes back when you stop.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if case .failed(let message) = music.state {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if music.isRunning && music.silentFor > 6 {
                HStack {
                    Label("Not hearing anything. If music is playing, allow Microkit under System Audio Recording.", systemImage: "speaker.slash")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Privacy Settings", action: openPrivacySettings)
                }
            }
        }
    }

    private var status: String {
        switch music.state {
        case .off: "Off"
        case .running: "Live"
        case .failed: "Could not start"
        }
    }

    private func toggle() {
        isBusy = true
        Task {
            if music.isRunning { await music.stop() } else { await music.start() }
            isBusy = false
        }
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
