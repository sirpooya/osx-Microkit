import SwiftUI

@main
struct MicrokitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var devices: DeviceStore
    @State private var store: AppStore

    init() {
        let devices = DeviceStore()
        _devices = State(initialValue: devices)
        _store = State(initialValue: AppStore(devices: devices))
    }

    var body: some Scene {
        // One window: openWindow(id:) from the menu bar or ⌘, fronts it instead of opening another.
        Window("Microkit", id: "main") {
            MainWindowView(store: store, runtime: appDelegate.runtime)
                .environment(devices)
                .frame(minWidth: 1_120, minHeight: 700)
                .background(StatusItemConnector(controller: appDelegate.statusItem, store: store))
                .task { await devices.run() }
                .task {
                    store.startLightingMonitoring()
                    SnapshotDriver.runIfRequested(store: store)
                    // QC: `--mode=music` (actions, lights, music, macros, tester, device) opens a mode.
                    // One token on purpose: a bare word after a flag reads as a file to open, and
                    // then the window never appears.
                    let modeFlag = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--mode=") }
                    if let value = modeFlag?.dropFirst("--mode=".count), let mode = AppMode(rawValue: String(value)) {
                        store.mode = mode
                    }
                    // QC: `--settings` opens the settings window, `--settings=keyboard` (general, about) a page.
                    let arguments = ProcessInfo.processInfo.arguments
                    if let flag = arguments.first(where: { $0 == "--settings" || $0.hasPrefix("--settings=") }) {
                        if let page = SettingsPage(rawValue: String(flag.dropFirst("--settings=".count))) {
                            store.settingsPage = page
                        }
                        SettingsWindowController.shared.show(store: store, runtime: appDelegate.runtime)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_311, height: 820)
        .commands {
            SettingsCommands(store: store, runtime: appDelegate.runtime)
            CommandGroup(replacing: .newItem) {
                Button(devices.hasDemo ? "Remove Demo Keyboard" : "Add Demo Keyboard", action: toggleDemo)
            }
            CommandGroup(after: .sidebar) {
                Button("Refresh Controller") { store.refreshDevice() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Divider()
                Button("Open Figma") { appDelegate.runtime.openFigma() }
            }
        }
        // The menu bar item is AppKit (`StatusItemController`): MenuBarExtra cannot tell a right
        // click from a left one.
    }

    private func toggleDemo() {
        Task { devices.hasDemo ? await devices.removeDemo() : await devices.addDemo() }
    }
}
