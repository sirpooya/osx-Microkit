import SwiftUI

/// MicroMap's workspace for the Creator Micro (and when nothing is plugged in); Microkit's
/// general VIA screens for any other keyboard.
struct MainWindowView: View {
    @Environment(DeviceStore.self) private var devices
    let store: AppStore
    let runtime: AppRuntime

    var body: some View {
        if let session = devices.selectedSession, !session.isCreatorMicro {
            RootView()
        } else {
            ContentView(store: store, runtime: runtime)
        }
    }
}
