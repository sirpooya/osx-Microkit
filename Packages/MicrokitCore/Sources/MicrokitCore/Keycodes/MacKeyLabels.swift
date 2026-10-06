/// Mac-style keycap text for keys whose QMK label reads like a PC keyboard.
/// Keyed by the canonical QMK name. Anything missing falls back to QMK's own label.
enum MacKeyLabels {
    struct Label {
        let primary: String
        let secondary: String?
        let symbol: String?

        init(_ primary: String, _ secondary: String? = nil, symbol: String? = nil) {
            self.primary = primary
            self.secondary = secondary
            self.symbol = symbol
        }
    }

    static let byKey: [String: Label] = [
        "KC_ENTER": Label("↩", "return"),
        "KC_ESCAPE": Label("esc"),
        "KC_BACKSPACE": Label("⌫", "delete"),
        "KC_TAB": Label("⇥", "tab"),
        "KC_SPACE": Label("space"),
        "KC_CAPS_LOCK": Label("⇪", "caps lock"),
        "KC_DELETE": Label("⌦", "fwd delete"),
        "KC_INSERT": Label("ins"),
        "KC_HOME": Label("↖", "home"),
        "KC_END": Label("↘", "end"),
        "KC_PAGE_UP": Label("⇞", "page up"),
        "KC_PAGE_DOWN": Label("⇟", "page down"),
        "KC_LEFT": Label("←"),
        "KC_RIGHT": Label("→"),
        "KC_UP": Label("↑"),
        "KC_DOWN": Label("↓"),
        "KC_PRINT_SCREEN": Label("prt sc"),
        "KC_SCROLL_LOCK": Label("scr lk"),
        "KC_PAUSE": Label("pause"),
        "KC_NUM_LOCK": Label("num lk"),
        "KC_APPLICATION": Label("☰", "menu"),
        "KC_KP_ENTER": Label("⌤", "keypad"),

        "KC_LEFT_CTRL": Label("⌃", "control"),
        "KC_LEFT_SHIFT": Label("⇧", "shift"),
        "KC_LEFT_ALT": Label("⌥", "option"),
        "KC_LEFT_GUI": Label("⌘", "command"),
        "KC_RIGHT_CTRL": Label("⌃", "right ctrl"),
        "KC_RIGHT_SHIFT": Label("⇧", "right shift"),
        "KC_RIGHT_ALT": Label("⌥", "right opt"),
        "KC_RIGHT_GUI": Label("⌘", "right cmd"),

        "KC_AUDIO_MUTE": Label("mute", symbol: "speaker.slash.fill"),
        "KC_AUDIO_VOL_UP": Label("vol +", symbol: "speaker.wave.3.fill"),
        "KC_AUDIO_VOL_DOWN": Label("vol −", symbol: "speaker.wave.1.fill"),
        "KC_KB_MUTE": Label("mute", symbol: "speaker.slash"),
        "KC_KB_VOLUME_UP": Label("vol +", symbol: "speaker.wave.3"),
        "KC_KB_VOLUME_DOWN": Label("vol −", symbol: "speaker.wave.1"),
        "KC_MEDIA_NEXT_TRACK": Label("next", symbol: "forward.end.fill"),
        "KC_MEDIA_PREV_TRACK": Label("previous", symbol: "backward.end.fill"),
        "KC_MEDIA_STOP": Label("stop", symbol: "stop.fill"),
        "KC_MEDIA_PLAY_PAUSE": Label("play/pause", symbol: "playpause.fill"),
        "KC_MEDIA_FAST_FORWARD": Label("fast fwd", symbol: "forward.fill"),
        "KC_MEDIA_REWIND": Label("rewind", symbol: "backward.fill"),
        "KC_MEDIA_EJECT": Label("eject", symbol: "eject.fill"),
        "KC_MEDIA_SELECT": Label("media", symbol: "music.note"),
        "KC_BRIGHTNESS_UP": Label("bright +", symbol: "sun.max.fill"),
        "KC_BRIGHTNESS_DOWN": Label("bright −", symbol: "sun.min.fill"),
        "KC_MISSION_CONTROL": Label("mission ctl", symbol: "rectangle.3.group"),
        "KC_LAUNCHPAD": Label("launchpad", symbol: "square.grid.3x3.fill"),
        "KC_SYSTEM_POWER": Label("power", symbol: "power"),
        "KC_SYSTEM_SLEEP": Label("sleep", symbol: "moon.fill"),
        "KC_SYSTEM_WAKE": Label("wake", symbol: "sun.horizon.fill"),
        "KC_CALCULATOR": Label("calc", symbol: "plus.forwardslash.minus"),
        "KC_MAIL": Label("mail", symbol: "envelope.fill"),
        "KC_MY_COMPUTER": Label("computer", symbol: "desktopcomputer"),
        "KC_WWW_SEARCH": Label("search", symbol: "magnifyingglass"),
        "KC_WWW_HOME": Label("home", symbol: "house.fill"),
        "KC_WWW_BACK": Label("back", symbol: "chevron.backward"),
        "KC_WWW_FORWARD": Label("forward", symbol: "chevron.forward"),
        "KC_WWW_STOP": Label("stop", symbol: "xmark"),
        "KC_WWW_REFRESH": Label("refresh", symbol: "arrow.clockwise"),
        "KC_WWW_FAVORITES": Label("favorites", symbol: "star.fill"),
        "KC_ASSISTANT": Label("assistant", symbol: "mic.fill"),
        "KC_CONTROL_PANEL": Label("settings", symbol: "gearshape.fill"),
    ]

    /// US layout: what Shift plus a basic key types.
    static let shiftedSymbols: [UInt16: String] = [
        0x1E: "!", 0x1F: "@", 0x20: "#", 0x21: "$", 0x22: "%", 0x23: "^", 0x24: "&", 0x25: "*",
        0x26: "(", 0x27: ")", 0x2D: "_", 0x2E: "+", 0x2F: "{", 0x30: "}", 0x31: "|", 0x33: ":",
        0x34: "\"", 0x35: "~", 0x36: "<", 0x37: ">", 0x38: "?",
    ]
}
