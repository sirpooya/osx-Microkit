import SwiftUI

/// Chooses between several connected keyboards.
struct DevicePicker: View {
    @Environment(DeviceStore.self) private var store
    @State private var selection: UInt64 = 0

    var body: some View {
        Picker("Keyboard", selection: $selection) {
            ForEach(store.sessions) { session in
                Text(session.name).tag(session.id)
            }
        }
        .onAppear { selection = store.selectedSession?.id ?? 0 }
        .onChange(of: selection) { store.selectedID = selection }
    }
}
