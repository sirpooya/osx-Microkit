/// Everything the keycode picker offers for one keyboard, grouped into tabs.
public struct KeycodeCatalog: Sendable {
    public let categories: [KeycodeCategory]

    /// - Parameters:
    ///   - lightingModules: the definition's `keycodes` list (for example `qmk_rgblight_keycodes`);
    ///     `nil` or empty shows every lighting group.
    public init(formatter: KeycodeFormatter, layerCount: Int, macroCount: Int, lightingModules: [String]?) {
        let table = formatter.table
        let composer = KeycodeComposer(table: table)

        func option(_ code: UInt16) -> KeycodeOption {
            KeycodeOption(code: code, legend: formatter.legend(for: code))
        }
        func options(_ codes: some Sequence<UInt16>) -> [KeycodeOption] {
            codes.filter { table.entry(for: $0) != nil }.map(option)
        }
        func group(_ name: String) -> [KeycodeOption] {
            table.entries(inGroup: name).map { option($0.code) }
        }

        // Basic
        let letters = options(0x04...0x1D)
        let numbers = options(0x1E...0x27)
        let symbols = options([0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38])
        let shifted = MacKeyLabels.shiftedSymbols.keys.sorted().compactMap { composer.modified($0, with: .shift) }.map(option)
        let editing = options([0x29, 0x2B, 0x2C, 0x28, 0x2A, 0x4C, 0x49, 0x39])
        let navigation = options([0x50, 0x52, 0x51, 0x4F, 0x4A, 0x4D, 0x4B, 0x4E])
        let functionKeys = options(Array(0x3A...0x45) + Array(0x68...0x73))
        let keypad = table.entries(inGroup: "basic").filter { $0.key.hasPrefix("KC_KP_") || $0.key == "KC_NUM_LOCK" }.map { option($0.code) }
        let used = Set((letters + numbers + symbols + editing + navigation + functionKeys + keypad).map(\.code))
        let otherBasic = table.entries(inGroup: "basic").filter { !used.contains($0.code) }.map { option($0.code) }
        let basic = KeycodeCategory(id: "basic", title: "Basic", symbol: "keyboard", sections: [
            KeycodeSection(title: "Letters", options: letters),
            KeycodeSection(title: "Numbers", options: numbers),
            KeycodeSection(title: "Symbols", options: symbols),
            KeycodeSection(title: "Shifted symbols", options: shifted),
            KeycodeSection(title: "Editing", options: editing),
            KeycodeSection(title: "Navigation", options: navigation),
            KeycodeSection(title: "Function keys", options: functionKeys),
            KeycodeSection(title: "Keypad", options: keypad),
            KeycodeSection(title: "Other", options: otherBasic),
        ])

        // Modifiers
        let singleMods: [ModifierMask] = [.control, .option, .shift, .command]
        let rightMods = singleMods.map { $0.union(.rightHand) }
        let combos: [ModifierMask] = [.hyper, .meh, [.control, .option], [.control, .shift], [.option, .shift], [.shift, .command], [.option, .command], [.control, .command]]
        let modifiers = KeycodeCategory(id: "modifiers", title: "Modifiers", symbol: "command", sections: [
            KeycodeSection(title: "Modifiers", options: group("modifiers")),
            KeycodeSection(title: "Combinations", options: combos.compactMap { composer.modified(0, with: $0) }.map(option)),
            KeycodeSection(title: "One-shot (applies to the next key)", options: (singleMods + rightMods + [.hyper, .meh]).compactMap { composer.oneShotMod($0) }.map(option)),
        ])

        // Media and system
        let media = KeycodeCategory(id: "media", title: "Media", symbol: "playpause", sections: [
            KeycodeSection(title: "Media", options: group("media")),
            KeycodeSection(title: "System", options: group("system")),
        ])

        let mouse = KeycodeCategory(id: "mouse", title: "Mouse", symbol: "computermouse", sections: [
            KeycodeSection(title: "Mouse", options: group("mouse")),
        ])

        // Layers
        let layerRange = 0..<max(layerCount, 1)
        let availableActions = LayerAction.allCases.filter { action in table.spec.ranges.contains { $0.define == action.rangeDefine } }
        let layerSections = availableActions.map { action in
            KeycodeSection(title: action.title, options: layerRange.compactMap { composer.layer(action, $0) }.map(option))
        }
        let layers = KeycodeCategory(id: "layers", title: "Layers", symbol: "square.3.layers.3d", sections: layerSections)

        // Macros
        let macros = KeycodeCategory(id: "macros", title: "Macros", symbol: "text.append", sections: [
            KeycodeSection(title: "Macros", options: (0..<macroCount).compactMap { composer.macro($0) }.map(option)),
        ])

        // Lighting
        let lightingGroups = Self.lightingGroups(for: lightingModules)
        let lighting = KeycodeCategory(id: "lighting", title: "Lighting", symbol: "lightbulb", sections: lightingGroups.map { group, title in
            KeycodeSection(title: title, options: table.entries(inGroup: group).map { option($0.code) })
        })

        // Custom keycodes from the definition
        let custom = KeycodeCategory(id: "custom", title: "Custom", symbol: "star", sections: [
            KeycodeSection(title: "This keyboard", options: formatter.customKeycodes.indices.compactMap { composer.custom($0) }.map(option)),
        ])

        // Quantum and the rest
        let special = KeycodeCategory(id: "special", title: "Special", symbol: "sparkles", sections: [
            KeycodeSection(title: "Empty", options: [option(0x0000), option(0x0001)]),
            KeycodeSection(title: "Quantum", options: group("quantum")),
            KeycodeSection(title: "Magic (changes how keys behave)", options: group("magic")),
            KeycodeSection(title: "Swap hands", options: group("swap_hands")),
            KeycodeSection(title: "Audio", options: group("audio")),
            KeycodeSection(title: "Connection", options: group("connection")),
            KeycodeSection(title: "Programmable buttons", options: group("programmable_button")),
            KeycodeSection(title: "Joystick", options: group("joystick")),
            KeycodeSection(title: "MIDI", options: group("midi")),
            KeycodeSection(title: "Steno", options: group("steno")),
            KeycodeSection(title: "Sequencer", options: group("sequencer")),
        ])

        categories = [basic, modifiers, media, layers, macros, lighting, mouse, custom, special].filter { !$0.isEmpty }
    }

    /// Case-insensitive search across every category, without duplicates.
    public func search(_ text: String) -> [KeycodeOption] {
        let terms = text.lowercased().split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return [] }
        var seen = Set<UInt16>()
        var results: [KeycodeOption] = []
        for option in categories.flatMap({ $0.sections.flatMap(\.options) }) where !seen.contains(option.code) {
            let haystack = option.searchText
            if terms.allSatisfy({ haystack.contains($0) }) {
                seen.insert(option.code)
                results.append(option)
            }
        }
        return results
    }

    /// QMK keycode groups to show for the definition's lighting modules, with section titles.
    static func lightingGroups(for modules: [String]?) -> [(String, String)] {
        let all: [(String, String)] = [
            ("backlight", "Backlight"),
            ("underglow", "RGB underglow"),
            ("rgb", "RGB underglow modes"),
            ("rgb_matrix", "RGB matrix"),
            ("led_matrix", "LED matrix"),
        ]
        guard let modules, !modules.isEmpty else { return all }
        var wanted = Set<String>()
        for module in modules {
            if module.contains("backlight") || module == "qmk_lighting" { wanted.insert("backlight") }
            if module.contains("rgblight") || module.contains("underglow") || module == "qmk_lighting" { wanted.formUnion(["underglow", "rgb"]) }
            if module.contains("rgb_matrix") { wanted.insert("rgb_matrix") }
            if module.contains("led_matrix") { wanted.insert("led_matrix") }
        }
        return wanted.isEmpty ? all : all.filter { wanted.contains($0.0) }
    }
}
