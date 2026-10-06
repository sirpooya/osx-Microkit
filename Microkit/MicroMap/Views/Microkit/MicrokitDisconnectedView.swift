import SwiftUI

/// Shown by Microkit's screens when no Creator Micro is ready; offers the demo board.
struct MicrokitDisconnectedView: View {
    @Environment(DeviceStore.self) private var devices

    var body: some View {
        ContentUnavailableView {
            Label("Connect your Creator Micro", systemImage: "cable.connector")
        } description: {
            Text("Plug in the Micro Pad with a USB cable, or look around with a pretend one.")
        } actions: {
            Button("Try the Demo Micro Pad", action: addDemo)
                .buttonStyle(.borderedProminent)
                .disabled(devices.hasDemo)
        }
    }

    private func addDemo() {
        Task { await devices.addDemo() }
    }
}
