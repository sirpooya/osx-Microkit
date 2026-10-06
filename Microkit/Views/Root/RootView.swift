import SwiftUI

/// Sidebar with the keyboard and its sections; detail shows the chosen section.
struct RootView: View {
    @Environment(DeviceStore.self) private var store
    @State private var section: AppSection? = RootView.launchSection

    var body: some View {
        NavigationSplitView {
            SidebarView(section: $section)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            DetailView(section: section ?? .keymap)
        }
        .task { await store.run() }
    }

    /// `--section lighting` (or keymap, macros, keyTester, device) opens a section at launch.
    static var launchSection: AppSection {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--section"), index + 1 < arguments.count,
              let section = AppSection(rawValue: arguments[index + 1]) else { return .keymap }
        return section
    }
}
