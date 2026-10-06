import AppKit
import SwiftUI

/// Menu bar glyph rendered as a template so it follows the menu bar appearance.
@MainActor
enum MicroMapMenuBarIcon {
    static var image: NSImage {
        // Microkit: our own glyph (Assets.xcassets/MenuBarIcon) instead of MicroMap's menu-bar-icon.png.
        guard let asset = NSImage(named: "MenuBarIcon"),
              let icon = asset.copy() as? NSImage
        else { return NSImage() }
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = true
        return icon
    }
}

// Microkit: MicroMap's MenuBarContent became `StatusItemController` (left click opens the window).

/// No Settings scene, so ⌘, opens Microkit's own settings window.
struct SettingsCommands: Commands {
    let store: AppStore
    let runtime: AppRuntime

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                // Microkit: its own window instead of a screen inside the main window.
                SettingsWindowController.shared.show(store: store, runtime: runtime)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
