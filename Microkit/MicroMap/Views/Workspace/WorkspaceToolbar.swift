import SwiftUI

/// Toolbar row spanning the window to the right of the sidebar: window title,
/// refresh action, and the controller connection pill.
struct WorkspaceToolbar: View {
    @Bindable var store: AppStore
    @State private var isRefreshHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Text("Figma Creator Micro")
                .font(FMTheme.headline)
                .foregroundStyle(FMTheme.textPrimary)

            Spacer(minLength: 0)

            Button {
                store.refreshDevice()
            } label: {
                FigmaAssetImage(fileName: "refresh.svg", template: true)
                    .foregroundStyle(FMTheme.textPrimary)
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(store.isRefreshingDevice ? 360 : 0))
                    .animation(
                        store.isRefreshingDevice
                            ? .linear(duration: 0.65).repeatForever(autoreverses: false)
                            : .easeOut(duration: 0.15),
                        value: store.isRefreshingDevice
                    )
                    .frame(width: 24, height: 24)
                    .background(
                        isRefreshHovered ? FMTheme.hoverFill : .clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .padding(2)
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isRefreshHovered = $0 }
            .animation(.easeOut(duration: 0.10), value: isRefreshHovered)
            .help("Refresh controller connection (⇧⌘R)")

            ConnectionStatusPill(state: store.device.state)
        }
        .padding(.horizontal, 12)
        .frame(height: FMTheme.toolbarHeight - 1)
        .background(FMTheme.panel)
    }
}

/// Connection state capsule from the design: a colored dot plus a short label.
struct ConnectionStatusPill: View {
    let state: ControllerConnectionState

    private var configuration: (title: String, tint: Color, help: String) {
        switch state {
        case .disconnected:
            ("Not connected", FMTheme.disconnectedRed, "Creator Micro is not connected")
        case .connected:
            ("Connected", FMTheme.connectedGreen, "Device is connected")
        case .unavailable(let message):
            ("Access blocked", FMTheme.blockedOrange, message)
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(configuration.tint)
                .frame(width: 9, height: 9)
            Text(configuration.title)
                .font(FMTheme.captionEmphasized)
                .foregroundStyle(FMTheme.textPrimary)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(height: 28)
        .background(
            Capsule().fill(FMTheme.controlSurface)
        )
        .overlay(
            Capsule().stroke(FMTheme.separator, lineWidth: 1)
        )
        .help(configuration.help)
        .accessibilityElement(children: .combine)
    }
}
