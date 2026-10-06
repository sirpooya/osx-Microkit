import SwiftUI

/// Shows the chosen section, or why it cannot be shown yet.
struct DetailView: View {
    @Environment(DeviceStore.self) private var store
    let section: AppSection

    var body: some View {
        Group {
            if let message = store.monitorError {
                ContentUnavailableView("Keyboards unavailable", systemImage: "exclamationmark.lock", description: Text(message))
            } else if let session = store.selectedSession {
                SessionView(session: session, section: section)
            } else {
                NoKeyboardView()
            }
        }
        .navigationTitle(store.selectedSession?.name ?? "Microkit")
    }
}
