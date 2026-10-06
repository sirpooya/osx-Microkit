import SwiftUI

struct SessionView: View {
    @Bindable var session: KeyboardSession
    let section: AppSection

    var body: some View {
        Group {
            switch session.phase {
            case .loading(let message):
                ProgressView(message)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .needsDefinition(let message):
                NeedsDefinitionView(session: session, message: message)
            case .failed(let message):
                ContentUnavailableView {
                    Label("The keyboard is not responding", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: retry)
                }
            case .ready:
                switch section {
                case .keymap: KeymapScreen(session: session)
                case .lighting: LightingScreen(session: session)
                case .music:
                    if let music = session.music {
                        MusicScreen(music: music)
                    }
                case .macros: MacrosScreen(session: session)
                case .keyTester: KeyTesterScreen(session: session)
                case .device: DeviceScreen(session: session)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let error = session.lastError {
                ErrorBanner(message: error, dismiss: dismissError)
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: session.lastError)
    }

    private func retry() {
        session.start()
    }

    private func dismissError() {
        session.lastError = nil
    }
}
