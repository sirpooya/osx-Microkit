import Foundation

/// Turns a 16-bit keycode into keycap text, Mac style (⌘0 rather than LGUI(KC_0)).
public struct KeycodeFormatter: Sendable {
    public let table: KeycodeTable
    public let customKeycodes: [CustomKeycode]

    public init(table: KeycodeTable, customKeycodes: [CustomKeycode] = []) {
        self.table = table
        self.customKeycodes = customKeycodes
    }

    public func legend(for code: UInt16) -> KeyLegend {
        if code == 0x0000 {
            return KeyLegend(primary: "", kind: .none, qmkName: "KC_NO", help: "Does nothing")
        }
        if code == 0x0001 {
            return KeyLegend(primary: "▽", kind: .transparent, qmkName: "KC_TRNS", help: "Transparent: uses the key from the layer below")
        }
        if let range = table.range(containing: code), let legend = compositeLegend(code, range: range) {
            return legend
        }
        if let entry = table.entry(for: code) {
            return legend(for: entry)
        }
        return unknown(code)
    }

    /// The legend for a plain table entry, with Mac overrides.
    public func legend(for entry: QMKKeycodeSpec.Entry) -> KeyLegend {
        let label = entry.label ?? Self.readableName(entry.key)
        let help = entry.label.map { "\($0) (\(entry.shortName))" } ?? entry.shortName
        if let mac = MacKeyLabels.byKey[entry.key] {
            return KeyLegend(primary: mac.primary, secondary: mac.secondary, symbol: mac.symbol,
                             kind: Self.kind(forGroup: entry.group), qmkName: entry.shortName, help: help)
        }
        let secondary: String? = entry.key.hasPrefix("KC_KP_") ? "keypad" : nil
        return KeyLegend(primary: label, secondary: secondary, kind: Self.kind(forGroup: entry.group),
                         qmkName: entry.shortName, help: help)
    }

    // MARK: Composite ranges

    private func compositeLegend(_ code: UInt16, range: QMKKeycodeSpec.Range) -> KeyLegend? {
        let offset = code - range.start
        switch range.define {
        case "QK_MODS":
            let mods = ModifierMask(rawValue: UInt8(code >> 8))
            let base = code & 0xFF
            return modsLegend(mods: mods, base: base)
        case "QK_MOD_TAP":
            let mods = ModifierMask(rawValue: UInt8((code >> 8) & 0x1F))
            let base = baseLegend(code & 0xFF)
            return KeyLegend(primary: base.primary, secondary: "hold " + Self.modsText(mods), symbol: base.symbol,
                             kind: .modTap, qmkName: "MT(\(Self.modMacro(mods)), \(base.qmkName))",
                             help: "Tap for \(base.help), hold for \(Self.modsWords(mods))")
        case "QK_LAYER_TAP":
            let layer = Int((code >> 8) & 0x0F)
            let base = baseLegend(code & 0xFF)
            return KeyLegend(primary: base.primary, secondary: "hold L\(layer)", symbol: base.symbol, kind: .layerTap,
                             qmkName: "LT(\(layer), \(base.qmkName))", help: "Tap for \(base.help), hold for layer \(layer)")
        case "QK_LAYER_MOD":
            let layer = Int((offset >> 5) & 0x0F)
            let mods = ModifierMask(rawValue: UInt8(offset & 0x1F))
            return KeyLegend(primary: "L\(layer)", secondary: "+ " + Self.modsText(mods), kind: .layer,
                             qmkName: "LM(\(layer), \(Self.modMacro(mods)))", help: "Hold for layer \(layer) with \(Self.modsWords(mods))")
        case "QK_ONE_SHOT_MOD":
            let mods = ModifierMask(rawValue: UInt8(offset & 0x1F))
            return KeyLegend(primary: Self.modsText(mods), secondary: "one-shot", kind: .modifier,
                             qmkName: "OSM(\(Self.modMacro(mods)))", help: "Next key gets \(Self.modsWords(mods))")
        case "QK_MACRO":
            return KeyLegend(primary: "M\(offset)", secondary: "macro", kind: .macro, qmkName: "QK_MACRO_\(offset)",
                             help: "Plays macro \(offset)")
        case "QK_KB":
            let index = Int(offset)
            if index < customKeycodes.count {
                let custom = customKeycodes[index]
                return KeyLegend(primary: custom.shortName ?? custom.name, kind: .custom, qmkName: "QK_KB_\(index)",
                                 help: custom.title ?? custom.name)
            }
            return KeyLegend(primary: "KB \(index)", secondary: "custom", kind: .custom, qmkName: "QK_KB_\(index)",
                             help: "Keyboard-specific keycode \(index)")
        case "QK_USER":
            return KeyLegend(primary: "USER \(offset)", kind: .custom, qmkName: "QK_USER_\(offset)",
                             help: "User keycode \(offset)")
        case "QK_TAP_DANCE":
            return KeyLegend(primary: "TD \(offset)", secondary: "tap dance", kind: .special, qmkName: "TD(\(offset))",
                             help: "Tap dance \(offset)")
        case "QK_UNICODE":
            let scalar = String(format: "%04X", code & 0x7FFF)
            return KeyLegend(primary: "U+\(scalar)", kind: .special, qmkName: "UC(0x\(scalar))", help: "Types Unicode U+\(scalar)")
        case "QK_UNICODEMAP", "QK_UNICODEMAP_PAIR":
            return KeyLegend(primary: "UM \(code & 0x3FFF)", kind: .special, qmkName: String(format: "0x%04X", code),
                             help: "Unicode map entry")
        default:
            if let action = LayerAction(rangeDefine: range.define) {
                let layer = Int(offset)
                return KeyLegend(primary: "\(action.qmkFunction) \(layer)", secondary: action.shortTitle, kind: .layer,
                                 qmkName: "\(action.qmkFunction)(\(layer))", help: "\(action.title) \(layer)")
            }
            return nil
        }
    }

    private func modsLegend(mods: ModifierMask, base: UInt16) -> KeyLegend {
        let baseLegend = baseLegend(base)
        let qmkName = "\(Self.modsFunctionName(mods))(\(baseLegend.qmkName))"
        if mods == .shift, let shifted = MacKeyLabels.shiftedSymbols[base] {
            return KeyLegend(primary: shifted, kind: .basic, qmkName: qmkName, help: "\(shifted) (Shift + \(baseLegend.help))")
        }
        if base == 0 {
            let name = mods == .hyper ? "hyper" : mods == .meh ? "meh" : nil
            return KeyLegend(primary: Self.modsText(mods), secondary: name, kind: .modifier, qmkName: qmkName,
                             help: Self.modsWords(mods))
        }
        let text = baseLegend.symbol == nil ? Self.modsText(mods) + baseLegend.primary : Self.modsText(mods)
        return KeyLegend(primary: text, secondary: baseLegend.symbol == nil ? nil : baseLegend.primary, symbol: nil,
                         kind: .combo, qmkName: qmkName, help: "\(Self.modsWords(mods)) + \(baseLegend.help)")
    }

    private func baseLegend(_ base: UInt16) -> KeyLegend {
        if let entry = table.entry(for: base) {
            return legend(for: entry)
        }
        return unknown(base)
    }

    private func unknown(_ code: UInt16) -> KeyLegend {
        let hex = String(format: "0x%04X", code)
        return KeyLegend(primary: hex, kind: .unknown, qmkName: hex, help: "Keycode \(hex)")
    }

    // MARK: Helpers

    /// Glyphs, with an "R" when the right-hand bit is set.
    static func modsText(_ mods: ModifierMask) -> String {
        (mods.contains(.rightHand) ? "R" : "") + mods.glyphs
    }

    static func modsWords(_ mods: ModifierMask) -> String {
        var words: [String] = []
        if mods.contains(.control) { words.append("Control") }
        if mods.contains(.option) { words.append("Option") }
        if mods.contains(.shift) { words.append("Shift") }
        if mods.contains(.command) { words.append("Command") }
        let text = words.joined(separator: "+")
        return mods.contains(.rightHand) ? "Right " + text : text
    }

    /// `MOD_LCTL | MOD_LGUI`, as used inside MT, LM and OSM.
    static func modMacro(_ mods: ModifierMask) -> String {
        mods.qmkName.split(separator: " | ").map { "MOD_" + $0 }.joined(separator: " | ")
    }

    /// QMK wrapper names: LGUI(kc), LSG(kc), HYPR(kc) and the generic fallback.
    static func modsFunctionName(_ mods: ModifierMask) -> String {
        let side = mods.contains(.rightHand) ? "R" : "L"
        switch mods.subtracting(.rightHand) {
        case .control: return side + "CTL"
        case .shift: return side + "SFT"
        case .option: return side + "ALT"
        case .command: return side + "GUI"
        case .hyper: return "HYPR"
        case .meh: return "MEH"
        default:
            var letters = ""
            if mods.contains(.control) { letters += "C" }
            if mods.contains(.shift) { letters += "S" }
            if mods.contains(.option) { letters += "A" }
            if mods.contains(.command) { letters += "G" }
            return side + letters
        }
    }

    /// `RGB_MODE_PLAIN` becomes `RGB Mode Plain`.
    static func readableName(_ key: String) -> String {
        var name = key
        for prefix in ["KC_", "QK_"] where name.hasPrefix(prefix) {
            name.removeFirst(prefix.count)
        }
        return name.split(separator: "_").map { word in
            word.count <= 3 ? String(word) : word.prefix(1) + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }

    static func kind(forGroup group: String) -> KeyLegend.Kind {
        switch group {
        case "basic": .basic
        case "modifiers": .modifier
        case "media", "system": .media
        case "mouse": .mouse
        case "backlight", "underglow", "rgb", "rgb_matrix", "led_matrix": .lighting
        case "macro": .macro
        case "kb", "user": .custom
        default: .special
        }
    }
}
