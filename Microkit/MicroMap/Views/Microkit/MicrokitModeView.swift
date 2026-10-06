import SwiftUI

/// Microkit's own screens inside MicroMap's window: they need the connected Micro Pad's session.
struct MicrokitModeView: View {
    @Environment(DeviceStore.self) private var devices
    let store: AppStore

    var body: some View {
        if let session = store.device.session, session.phase == .ready {
            switch store.mode {
            case .music:
                if let music = session.music {
                    MusicScreen(music: music)
                } else {
                    ContentUnavailableView("No lights to drive", systemImage: "lightbulb.slash")
                }
            case .macros:
                MacrosScreen(session: session)
            case .tester:
                KeyTesterScreen(session: session)
            case .device:
                DeviceScreen(session: session)
            default:
                EmptyView()
            }
        } else {
            MicrokitDisconnectedView()
        }
    }
}
