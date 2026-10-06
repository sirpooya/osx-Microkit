import MicrokitCore

/// Microkit: turns Microkit's VIA keycode catalog into MicroMap actions with raw keycodes, so the
/// sidebar offers media keys, layer switches, macros and lighting next to the Figma shortcuts.
/// IDs are `via-XXXX` (the keycode in hex), stable across launches.
enum KeyboardActionCatalog {
    /// Built from the protocol 12 tables before any keyboard connects, so saved assignments
    /// that use these actions always resolve.
    @MainActor static let defaultActions = actions(from: KeycodeCatalog(
        formatter: KeycodeFormatter(table: .protocol12), layerCount: 4, macroCount: 16, lightingModules: nil))

    static func actions(from catalog: KeycodeCatalog) -> [FigmaAction] {
        var seen = Set<UInt16>()
        var result: [FigmaAction] = []
        for category in catalog.categories {
            let target: ShortcutCategory
            switch category.id {
            case "media": target = .media
            case "layers": target = .layers
            case "macros": target = .macros
            case "lighting", "custom": target = .lighting
            case "basic", "modifiers", "mouse", "special": target = .keys
            default: continue
            }
            for option in category.sections.flatMap(\.options) where option.code > 1 && seen.insert(option.code).inserted {
                result.append(action(for: option, category: target))
            }
        }
        return result
    }

    static func id(for keycode: UInt16) -> String {
        "via-" + String(keycode, radix: 16, uppercase: true).leftPadded(to: 4)
    }

    private static func action(for option: KeycodeOption, category: ShortcutCategory) -> FigmaAction {
        let legend = option.legend
        return FigmaAction(
            id: id(for: option.code),
            title: legend.help,
            category: category,
            symbol: legend.symbol ?? "keyboard",
            chord: nil,
            assignability: .direct,
            note: "QMK keycode \(legend.qmkName)",
            qmkKeycode: option.code,
            shortcutLabel: legend.symbol == nil ? legend.primary : (legend.secondary ?? legend.primary)
        )
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
