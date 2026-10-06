import AppKit
import SwiftUI

/// Development utility: when launched with FM_SNAPSHOT_DIR set, walks the
/// main UI states, writes a PNG of the window for each into that directory,
/// and terminates. Captures use NSView.cacheDisplay, so no screen-recording
/// permission is needed. Used to verify the UI against the Figma mockups.
@MainActor
enum SnapshotDriver {
    static func runIfRequested(store: AppStore) {
        if ProcessInfo.processInfo.environment["FM_DEBUG_WINDOW"] != nil {
            Task { await debugWindow() }
            return
        }
        guard let directory = ProcessInfo.processInfo.environment["FM_SNAPSHOT_DIR"] else { return }
        if ProcessInfo.processInfo.environment["FM_SNAPSHOT_APPSTORE"] != nil {
            Task { await runAppStore(store: store, directory: directory) }
            return
        }
        Task {
            await run(store: store, directory: directory)
        }
    }

    /// Marketing captures for App Store Connect: 1280×800 points on a 2×
    /// display produces the accepted 2560×1600 pixel size. Light appearance
    /// only; runs with the real connected controller so the connection badge
    /// and imported layout are genuine.
    private static func runAppStore(store: AppStore, directory: String) async {
        // The connect handshake plus the 4-layer layout scan takes ~3 s;
        // captures must show the settled, connected state.
        try? await Task.sleep(for: .seconds(5))
        guard let window = NSApp.windows.first(where: { $0.isVisible }) else {
            fputs("SnapshotDriver: no visible window\n", stderr)
            exit(1)
        }
        window.setContentSize(NSSize(width: 1280, height: 800))
        NSApp.appearance = NSAppearance(named: .aqua)
        window.appearance = NSAppearance(named: .aqua)

        // A fresh capture environment starts with an empty draft. Dismiss the
        // first-connect import dialog, then stage a populated demo layout so
        // the marketing shots show printed keycaps instead of a blank board.
        if store.showsInitialDeviceImportChoice {
            store.importInitialDeviceShortcuts()
            // Let the "Layout loaded" toast expire before capturing.
            try? await Task.sleep(for: .seconds(4))
        }
        let demoLayout: [(String, String)] = [
            ("key-1", "tools-move"), ("key-2", "tools-frame"),
            ("key-3", "tools-pen"), ("key-4", "tools-text"),
            ("key-5", "tools-rectangle"), ("key-6", "tools-ellipse"),
            ("key-7", "tools-comments"), ("key-8", "essential-component-search"),
            ("key-9", "selection-lock"), ("key-10", "zoom-pan"),
            ("key-12", "arrange-align-left"), ("key-13", "transform-mask"),
            ("encoder-b-left", "zoom-out"), ("encoder-b-right", "zoom-in"),
            ("encoder-b-press", "zoom-fit"), ("encoder-a-press", "essential-actions")
        ]
        store.currentLayer = 0
        for (slot, action) in demoLayout {
            store.assign(actionID: action, to: slot)
        }

        store.mode = .actions
        store.selectedSlotID = "key-5"
        await snap(window, directory, "01-actions-key")

        store.selectedSlotID = "encoder-b-press"
        await snap(window, directory, "02-actions-dial")

        store.selectedSlotID = nil
        store.searchText = "pen"
        await snap(window, directory, "03-actions-search")
        store.searchText = ""

        store.mode = .lights
        store.selectedLightingTarget = .perimeterActiveFigma
        await snap(window, directory, "04-lights-perimeter")

        store.selectedLightingTarget = .keyCaps
        await snap(window, directory, "05-lights-keys")

        exit(0)
    }

    private static func debugWindow() async {
        try? await Task.sleep(for: .seconds(2))
        for window in NSApp.windows where window.isVisible {
            let mask = window.styleMask
            print("""
            window: \(window.title)
              styleMask.fullSizeContentView: \(mask.contains(.fullSizeContentView))
              titlebarAppearsTransparent: \(window.titlebarAppearsTransparent)
              frame: \(window.frame)
              contentView.frame: \(window.contentView?.frame ?? .zero)
              contentLayoutRect: \(window.contentLayoutRect)
              closeButton.frame: \(window.standardWindowButton(.closeButton)?.frame ?? .zero)
              miniaturizeButton.frame: \(window.standardWindowButton(.miniaturizeButton)?.frame ?? .zero)
              zoomButton.frame: \(window.standardWindowButton(.zoomButton)?.frame ?? .zero)
            """)
        }
        exit(0)
    }

    private static func run(store: AppStore, directory: String) async {
        try? await Task.sleep(for: .seconds(1))
        guard let window = NSApp.windows.first(where: { $0.isVisible }) else {
            fputs("SnapshotDriver: no visible window\n", stderr)
            exit(1)
        }
        window.setContentSize(NSSize(width: 1311, height: 820))

        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            // App-level override: window-level assignment proved unreliable
            // when the system appearance differs from the requested one.
            NSApp.appearance = NSAppearance(named: appearance)
            window.appearance = NSAppearance(named: appearance)
            let suffix = appearance == .aqua ? "light" : "dark"

            store.mode = .actions
            store.selectedSlotID = "key-5"
            await snap(window, directory, "actions-key-\(suffix)")

            store.selectedSlotID = "encoder-b-press"
            await snap(window, directory, "actions-dial-\(suffix)")

            store.selectedSlotID = "encoder-a-press"
            await snap(window, directory, "actions-scroller-\(suffix)")

            store.selectedSlotID = nil
            await snap(window, directory, "actions-empty-\(suffix)")

            store.searchText = "pen"
            await snap(window, directory, "actions-search-\(suffix)")
            store.searchText = ""

            store.mode = .lights
            store.selectedLightingTarget = .perimeterActiveFigma
            await snap(window, directory, "lights-perimeter-\(suffix)")

            store.selectedLightingTarget = .keyCaps
            await snap(window, directory, "lights-keys-\(suffix)")

            // Microkit: settings have their own window now; capture them with the
            // `--settings=<page>` launch flag instead.
            store.mode = .actions
        }
        exit(0)
    }

    private static func snap(_ window: NSWindow, _ directory: String, _ name: String) async {
        // The shell cannot create directories inside the sandbox container;
        // only the app itself can.
        try? FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
        try? await Task.sleep(for: .milliseconds(350))
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
        } catch {
            // The app is sandboxed: a directory outside the container fails
            // here. Fail loudly so a stale-snapshot run cannot masquerade as
            // a fresh one.
            fputs("SnapshotDriver: cannot write \(url.path): \(error)\n", stderr)
            exit(1)
        }
    }
}
