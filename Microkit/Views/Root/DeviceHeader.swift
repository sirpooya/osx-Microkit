import SwiftUI

/// The connected keyboard at the top of the sidebar.
struct DeviceHeader: View {
    let session: KeyboardSession

    var body: some View {
        HStack(spacing: 10) {
            Image(session.info.vendorID == 0x574C ? "WorkLouderMark" : "")
                .resizable()
                .renderingMode(.template)
                .frame(width: 22, height: 22)
                .opacity(session.info.vendorID == 0x574C ? 1 : 0)
                .overlay {
                    if session.info.vendorID != 0x574C {
                        Image(systemName: "keyboard")
                    }
                }
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var status: String {
        switch session.phase {
        case .ready: session.isDemo ? "Demo, not a real keyboard" : "Connected · \(session.info.transport)"
        case .loading(let message): message
        case .needsDefinition: "Needs a layout"
        case .failed: "Not responding"
        }
    }
}
