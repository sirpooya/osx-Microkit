/// Builds composite keycodes (mod combos, mod-tap, layer keys) from the table's ranges,
/// so the numbers always match the firmware's keycode version.
public struct KeycodeComposer: Sendable {
    public let table: KeycodeTable

    public init(table: KeycodeTable) {
        self.table = table
    }

    func start(_ define: String) -> UInt16? {
        table.spec.ranges.first { $0.define == define }?.start
    }

    /// Modifiers held while `base` is pressed, for example ⌘0.
    public func modified(_ base: UInt16, with mods: ModifierMask) -> UInt16? {
        // QK_MODS starts at 0x0100: the mask itself is the high byte.
        guard base <= 0xFF, !mods.subtracting(.rightHand).isEmpty, start("QK_MODS") != nil else { return nil }
        return UInt16(mods.rawValue) << 8 | base
    }

    /// Tap for `base`, hold for `mods`.
    public func modTap(_ base: UInt16, mods: ModifierMask) -> UInt16? {
        guard base <= 0xFF, !mods.subtracting(.rightHand).isEmpty, let start = start("QK_MOD_TAP") else { return nil }
        return start | UInt16(mods.rawValue) << 8 | base
    }

    /// Tap for `base`, hold for `layer` (layers 0 to 15).
    public func layerTap(_ base: UInt16, layer: Int) -> UInt16? {
        guard base <= 0xFF, (0..<16).contains(layer), let start = start("QK_LAYER_TAP") else { return nil }
        return start | UInt16(layer) << 8 | base
    }

    /// Hold for `layer` with `mods` active (layers 0 to 15).
    public func layerMod(layer: Int, mods: ModifierMask) -> UInt16? {
        guard (0..<16).contains(layer), let start = start("QK_LAYER_MOD") else { return nil }
        return start | UInt16(layer) << 5 | UInt16(mods.rawValue)
    }

    public func layer(_ action: LayerAction, _ layer: Int) -> UInt16? {
        guard (0..<32).contains(layer), let start = start(action.rangeDefine) else { return nil }
        return start | UInt16(layer)
    }

    public func oneShotMod(_ mods: ModifierMask) -> UInt16? {
        guard !mods.subtracting(.rightHand).isEmpty, let start = start("QK_ONE_SHOT_MOD") else { return nil }
        return start | UInt16(mods.rawValue)
    }

    public func macro(_ index: Int) -> UInt16? {
        guard let start = start("QK_MACRO"), index >= 0, index < 128 else { return nil }
        return start + UInt16(index)
    }

    public func custom(_ index: Int) -> UInt16? {
        guard let start = start("QK_KB"), index >= 0, index < 64 else { return nil }
        return start + UInt16(index)
    }
}
