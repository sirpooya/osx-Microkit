import Foundation

/// System/media keycodes from QMK's Basic Keycodes table. These values are
/// written directly through VIA and work for both keys and encoder actions.
enum SystemShortcutCatalog {
    static let actions: [FigmaAction] = [
        action("system-volume-up", "Volume Up", "speaker.plus.fill", 0x00A9, "Vol +"),
        action("system-volume-down", "Volume Down", "speaker.minus.fill", 0x00AA, "Vol −"),
        action("system-mute", "Mute", "speaker.slash.fill", 0x00A8, "Mute"),
        action("system-play-pause", "Play / Pause", "playpause.fill", 0x00AE, "Play"),
        action("system-previous-track", "Previous Track", "backward.end.fill", 0x00AC, "Prev"),
        action("system-next-track", "Next Track", "forward.end.fill", 0x00AB, "Next"),
        action("system-brightness-up", "Brightness Up", "sun.max.fill", 0x00BD, "Bright +"),
        action("system-brightness-down", "Brightness Down", "sun.min.fill", 0x00BE, "Bright −"),
        action("system-mission-control", "Mission Control", "rectangle.3.group", 0x00C1, "Mission"),
        action("system-launchpad", "Launchpad", "square.grid.3x3.fill", 0x00C2, "Launchpad")
    ]

    private static func action(
        _ id: String,
        _ title: String,
        _ symbol: String,
        _ keycode: UInt16,
        _ label: String
    ) -> FigmaAction {
        FigmaAction(
            id: id,
            title: title,
            category: .system,
            symbol: symbol,
            chord: nil,
            assignability: .direct,
            note: "System action written as a native QMK media keycode.",
            qmkKeycode: keycode,
            shortcutLabel: label
        )
    }
}
