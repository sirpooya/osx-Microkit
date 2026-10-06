import AppKit
import SwiftUI

/// Settings in their own small window. MicroMap showed them in place of the main workspace, which
/// kept them at the main window's 1120 x 700 minimum. Built on first use and reused, so the window
/// keeps its position and the page the user left it on.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    /// `AppRuntime.isAppWindow` reads this to keep the Dock icon while the window is open.
    static let windowIdentifier = NSUserInterfaceItemIdentifier("settings")

    private var window: NSWindow?

    func show(store: AppStore, runtime: AppRuntime) {
        runtime.willShowMainWindow()
        let window = self.window ?? makeWindow(store: store, runtime: runtime)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        // Opens to be read: otherwise the shortcut recorder takes focus.
        window.makeFirstResponder(nil)
    }

    private func makeWindow(store: AppStore, runtime: AppRuntime) -> NSWindow {
        let view = SettingsView(runtime: runtime, store: store) { [weak self] in
            self?.window?.performClose(nil)
        }
        let hosting = NSHostingController(rootView: view)
        // Without this AppKit re-measures the Form's scroll view mid-layout.
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.identifier = Self.windowIdentifier
        window.title = "Microkit Settings"
        // Not resizable: the pages are laid out for one size.
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        window.initialFirstResponder = nil
        // The frame, not the content size: the content runs under the title bar.
        window.setFrame(NSRect(origin: .zero, size: SettingsView.windowSize), display: false)
        window.center()
        return window
    }
}
