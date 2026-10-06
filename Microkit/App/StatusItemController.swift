import AppKit
import SwiftUI

/// The menu bar item. AppKit instead of SwiftUI's MenuBarExtra, which cannot tell clicks apart:
/// a left click opens the main window, a right click or Control-click shows the menu.
@MainActor
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private var runtime: AppRuntime?
    private var store: AppStore?
    /// SwiftUI's openWindow, handed over by `StatusItemConnector` (only a view can read it).
    private var openWindow: OpenWindowAction?

    func install(runtime: AppRuntime) {
        guard statusItem == nil else { return }
        self.runtime = runtime
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "MicrokitStatusItem"
        item.behavior = []
        if let button = item.button {
            button.image = MicroMapMenuBarIcon.image
            button.setAccessibilityLabel("Microkit")
            button.target = self
            button.action = #selector(buttonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    func connect(store: AppStore, openWindow: OpenWindowAction) {
        self.store = store
        self.openWindow = openWindow
    }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            openMainWindow()
        }
    }

    private func showMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        if let status = connectionStatus {
            let item = NSMenuItem(title: status, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(menuItem("Open Microkit", #selector(openMainWindow)))
        menu.addItem(menuItem("Settings…", #selector(openSettings)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Microkit", #selector(quit)))
        // Attached only while it shows: with a menu attached, a left click would open it too.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openMainWindow() {
        runtime?.willShowMainWindow()
        if let openWindow {
            openWindow(id: "main")
        } else {
            NSApp.windows.first(where: AppRuntime.isMainWindow)?.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openSettings() {
        guard let store, let runtime else { return }
        SettingsWindowController.shared.show(store: store, runtime: runtime)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private var connectionStatus: String? {
        guard let store else { return nil }
        switch store.device.state {
        case .connected: return "Device · Connected"
        case .disconnected: return "Controller disconnected"
        case .unavailable: return "Controller unavailable"
        }
    }
}

/// Hands the status item the store and SwiftUI's openWindow, which only a view can read.
struct StatusItemConnector: View {
    let controller: StatusItemController
    let store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .onAppear { controller.connect(store: store, openWindow: openWindow) }
    }
}
