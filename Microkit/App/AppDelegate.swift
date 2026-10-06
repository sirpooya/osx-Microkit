import AppKit

/// MicroMap's delegate (runtime services: global Figma shortcut, launch at login, dock icon) merged
/// with Microkit's quit hook (music mode puts the keyboard's lighting back first).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let runtime = AppRuntime()
    let statusItem = StatusItemController()

    /// Runs before quitting. Set by `DeviceStore`.
    static var beforeQuit: (@MainActor () async -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        runtime.start()
        statusItem.install(runtime: runtime)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: nil)
    }

    // AppKit posts window notifications on the main thread.
    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, AppRuntime.isAppWindow(window) else { return }
        runtime.appWindowWillClose(window)
    }

    /// The menu bar item keeps Microkit available after the window closes, like MicroMap.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let hook = Self.beforeQuit else { return .terminateNow }
        Self.beforeQuit = nil
        var replied = false
        func reply() {
            guard !replied else { return }
            replied = true
            sender.reply(toApplicationShouldTerminate: true)
        }
        Task { @MainActor in
            await hook()
            reply()
        }
        // Never hang the quit on an unresponsive keyboard.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            reply()
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        runtime.stop()
    }
}
