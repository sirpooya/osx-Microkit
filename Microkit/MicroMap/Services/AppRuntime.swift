import AppKit
import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppRuntime {
    var errorMessage: String?
    private(set) var globalShortcut = GlobalShortcut.stored
    private(set) var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    private(set) var hideDockIconWhenClosed =
        UserDefaults.standard.bool(forKey: AppRuntime.hideDockIconPersistenceKey)

    private static let hideDockIconPersistenceKey = "figmaMicro.hideDockIcon.v1"
    private let opener: FigmaApplicationOpener
    @ObservationIgnored private lazy var hotKeyService = GlobalHotKeyService { [weak self] in
        Task { @MainActor in
            self?.openFigma()
        }
    }

    init(launcher: any ApplicationLaunching = WorkspaceApplicationLauncher()) {
        opener = FigmaApplicationOpener(launcher: launcher)
    }

    func start() {
        do {
            try hotKeyService.register(globalShortcut)
        } catch {
            present(error: error.localizedDescription)
        }
        refreshLaunchAtLoginState()
    }

    /// Persists and re-registers the global shortcut. Returns false when the
    /// system rejects the registration (e.g. the chord is taken); the previous
    /// shortcut is restored in that case.
    @discardableResult
    func setGlobalShortcut(_ shortcut: GlobalShortcut) -> Bool {
        guard shortcut.isValid else { return false }
        let previous = globalShortcut
        do {
            try hotKeyService.register(shortcut)
        } catch {
            try? hotKeyService.register(previous)
            present(error: error.localizedDescription)
            return false
        }
        globalShortcut = shortcut
        shortcut.store()
        return true
    }

    func stop() {
        hotKeyService.unregister()
    }

    func openFigma() {
        opener.openFigma { [weak self] result in
            if case let .failure(error) = result {
                let message = error.localizedDescription
                Task { @MainActor in
                    self?.present(error: message)
                }
            }
        }
    }

    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            present(error: "Launch at Login could not be changed: \(error.localizedDescription)")
        }
        refreshLaunchAtLoginState()
    }

    func refreshLaunchAtLoginState() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setHideDockIconWhenClosed(_ enabled: Bool) {
        hideDockIconWhenClosed = enabled
        UserDefaults.standard.set(enabled, forKey: Self.hideDockIconPersistenceKey)
        if !enabled {
            NSApp.setActivationPolicy(.regular)
        }
    }

    /// Called before the main or settings window is shown from the menu bar or
    /// ⌘, so the app returns to the Dock while a window is open.
    func willShowMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hides the Dock icon once the last app window closes, leaving the app
    /// running with just its menu bar item.
    func appWindowWillClose(_ closingWindow: NSWindow) {
        guard hideDockIconWhenClosed else { return }
        let anotherAppWindowIsVisible = NSApp.windows.contains { window in
            window !== closingWindow && window.isVisible && Self.isAppWindow(window)
        }
        guard !anotherAppWindowIsVisible else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    static func isMainWindow(_ window: NSWindow) -> Bool {
        window.identifier?.rawValue.hasPrefix("main") == true
    }

    /// Microkit: the settings window has its own window now and counts too.
    static func isAppWindow(_ window: NSWindow) -> Bool {
        isMainWindow(window) || window.identifier == SettingsWindowController.windowIdentifier
    }

    private func present(error message: String) {
        errorMessage = message
        if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
