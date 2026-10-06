import SwiftUI

struct SidebarView: View {
    @Environment(DeviceStore.self) private var store
    @Binding var section: AppSection?

    var body: some View {
        List(selection: $section) {
            if let session = store.selectedSession {
                Section {
                    DeviceHeader(session: session)
                }
                if session.phase == .ready {
                    Section("Configure") {
                        ForEach(sections(for: session)) { item in
                            Label(item.title, systemImage: item.symbol)
                                .badge(item == .music && session.music?.isRunning == true ? Text("Live") : nil)
                                .tag(item)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if store.sessions.count > 1 {
                DevicePicker()
                    .padding(10)
            }
        }
    }

    private func sections(for session: KeyboardSession) -> [AppSection] {
        AppSection.allCases.filter { item in
            switch item {
            case .lighting: !session.lightingPages.isEmpty
            case .music: session.music != nil
            case .macros: session.macroCount > 0
            default: true
            }
        }
    }
}
