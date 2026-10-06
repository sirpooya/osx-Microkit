import Foundation

enum QMKKeycodeEncoder {
    static func encode(
        _ action: FigmaAction,
        layout: ResolvedKeyboardLayout = .genericUS
    ) -> UInt16? {
        if let qmkKeycode = action.qmkKeycode { return qmkKeycode }
        guard let chord = action.hardwareChord ?? action.chord else { return nil }
        let resolvedLayout = action.keyResolution == .physical ? .genericUS : layout
        return encode(chord, layout: resolvedLayout)
    }

    static func encode(
        _ chord: KeyChord,
        layout: ResolvedKeyboardLayout = .genericUS
    ) -> UInt16? {
        var modifiers = chord.modifiers
        let base: UInt8

        if let resolvedStroke = layout.stroke(for: chord.key) {
            base = resolvedStroke.keycode
            for modifier in resolvedStroke.modifiers where !modifiers.contains(modifier) {
                modifiers.append(modifier)
            }
        } else {
            guard var genericBase = baseKeycode(for: chord.key) else { return nil }
            if chord.key == "+" {
                genericBase = 0x2E
                if !modifiers.contains(.shift) { modifiers.append(.shift) }
            }
            base = genericBase
        }

        let modifierBits = modifiers.reduce(UInt16(0)) { partial, modifier in
            partial | mask(for: modifier)
        }
        return UInt16(base) | modifierBits
    }

    private static func mask(for modifier: KeyModifier) -> UInt16 {
        switch modifier {
        case .control: 0x0100
        case .shift: 0x0200
        case .option: 0x0400
        case .command: 0x0800
        }
    }

    private static func baseKeycode(for key: String) -> UInt8? {
        let upper = key.uppercased()
        if upper.count == 1, let scalar = upper.unicodeScalars.first {
            switch scalar.value {
            case 65...90: return UInt8(0x04 + scalar.value - 65)
            case 49...57: return UInt8(0x1E + scalar.value - 49)
            case 48: return 0x27
            default: break
            }
        }

        return [
            "ENTER": 0x28, "RETURN": 0x28, "ESC": 0x29, "ESCAPE": 0x29,
            "DELETE": 0x2A, "BACKSPACE": 0x2A, "TAB": 0x2B, "SPACE": 0x2C,
            "-": 0x2D, "=": 0x2E, "+": 0x2E, "[": 0x2F, "]": 0x30,
            "\\": 0x31, ";": 0x33, "'": 0x34, "`": 0x35, ",": 0x36,
            ".": 0x37, "<": 0x36, ">": 0x37, "/": 0x38, "HOME": 0x4A, "END": 0x4D,
            "PAGEUP": 0x4B, "PAGEDOWN": 0x4E,
            "→": 0x4F, "←": 0x50, "↓": 0x51, "↑": 0x52,
            "CONTROL": 0xE0, "SHIFT": 0xE1, "OPTION": 0xE2, "COMMAND": 0xE3
        ][upper]
    }

    /// Maps the macOS virtual key codes of non-printable keys to the key
    /// names this encoder understands. The shortcut recorder feeds recorded
    /// events through this single table so its vocabulary can never drift
    /// from `baseKeycode`/`keyName`.
    static func specialKeyName(forMacKeyCode keyCode: UInt16) -> String? {
        switch keyCode {
        case 36, 76: "Enter"
        case 48: "Tab"
        case 49: "Space"
        case 51, 117: "Delete"
        case 53: "Esc"
        case 115: "Home"
        case 116: "PageUp"
        case 119: "End"
        case 121: "PageDown"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default: nil
        }
    }

    /// Decodes the subset of ordinary QMK chords the app can also encode.
    /// Media/system values are resolved through SystemShortcutCatalog first.
    /// Printable keys are named through the resolved layout when one is
    /// provided, so imported shortcuts show the key actually printed on the
    /// user's keyboard instead of its US-QWERTY position.
    static func decode(
        _ keycode: UInt16,
        layout: ResolvedKeyboardLayout = .genericUS
    ) -> KeyChord? {
        let allowedModifierMask: UInt16 = 0x0F00
        guard keycode & 0xF000 == 0 else { return nil }
        let base = UInt8(keycode & 0x00FF)
        guard let key = layout.keyName(forKeycode: base) ?? keyName(for: base) else { return nil }

        var modifiers: [KeyModifier] = []
        if keycode & 0x0100 != 0 { modifiers.append(.control) }
        if keycode & 0x0400 != 0 { modifiers.append(.option) }
        if keycode & 0x0200 != 0 { modifiers.append(.shift) }
        if keycode & 0x0800 != 0 { modifiers.append(.command) }
        guard keycode & ~(allowedModifierMask | 0x00FF) == 0 else { return nil }
        return KeyChord(modifiers: modifiers, key: key)
    }

    private static func keyName(for keycode: UInt8) -> String? {
        switch keycode {
        case 0x04...0x1D:
            return String(UnicodeScalar(UInt8(ascii: "A") + keycode - 0x04))
        case 0x1E...0x26:
            return String(Int(keycode - 0x1E) + 1)
        case 0x27: return "0"
        default:
            return [
                0x28: "Enter", 0x29: "Esc", 0x2A: "Delete", 0x2B: "Tab", 0x2C: "Space",
                0x2D: "-", 0x2E: "=", 0x2F: "[", 0x30: "]", 0x31: "\\",
                0x33: ";", 0x34: "'", 0x35: "`", 0x36: ",", 0x37: ".", 0x38: "/",
                0x4A: "Home", 0x4B: "PageUp", 0x4D: "End", 0x4E: "PageDown",
                0x4F: "→", 0x50: "←", 0x51: "↓", 0x52: "↑"
            ][keycode]
        }
    }
}
