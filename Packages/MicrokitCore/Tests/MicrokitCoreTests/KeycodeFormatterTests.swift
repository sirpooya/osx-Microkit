import Testing
@testable import MicrokitCore

struct KeycodeFormatterTests {
    let formatter: KeycodeFormatter

    init() throws {
        let definition = try Fixtures.creatorMicro()
        formatter = KeycodeFormatter(table: .protocol12, customKeycodes: definition.customKeycodes ?? [])
    }

    @Test(arguments: [
        (UInt16(0x0827), "⌘0", KeyLegend.Kind.combo, "LGUI(KC_0)"),
        (0x0029, "esc", .basic, "KC_ESC"),
        (0x0A20, "⇧⌘3", .combo, "LSG(KC_3)"),
        (0x7700, "M0", .macro, "QK_MACRO_0"),
        (0x5201, "TO 1", .layer, "TO(1)"),
        (0x0041, "F8", .basic, "KC_F8"),
        (0x021E, "!", .basic, "LSFT(KC_1)"),
        (0x0001, "▽", .transparent, "KC_TRNS"),
        (0x0F00, "⌃⌥⇧⌘", .modifier, "HYPR(KC_NO)"),
    ])
    func microPadAnchors(code: UInt16, primary: String, kind: KeyLegend.Kind, qmkName: String) {
        let legend = formatter.legend(for: code)
        #expect(legend.primary == primary)
        #expect(legend.kind == kind)
        #expect(legend.qmkName == qmkName)
    }

    @Test func customKeycodeUsesDefinitionName() {
        let legend = formatter.legend(for: 0x7E01)
        #expect(legend.kind == .custom)
        #expect(legend.primary == "R_M_MOD")
    }

    @Test func mediaKeysCarrySymbols() {
        #expect(formatter.legend(for: 0x00AA).symbol == "speaker.wave.1.fill")
        #expect(formatter.legend(for: 0x00A9).symbol == "speaker.wave.3.fill")
        #expect(formatter.legend(for: 0x00AE).symbol == "playpause.fill")
    }

    @Test func lightingKeysWithoutQMKLabelGetReadableNames() {
        let legend = formatter.legend(for: 0x782B)
        #expect(legend.kind == .lighting)
        #expect(legend.primary == "RGB Mode Plain")
    }

    @Test func modTapAndLayerTap() {
        let modTap = formatter.legend(for: 0x2104)
        #expect(modTap.primary == "A")
        #expect(modTap.secondary == "hold ⌃")
        #expect(modTap.qmkName == "MT(MOD_LCTL, KC_A)")

        let layerTap = formatter.legend(for: 0x412C)
        #expect(layerTap.primary == "space")
        #expect(layerTap.secondary == "hold L1")
        #expect(layerTap.qmkName == "LT(1, KC_SPC)")
    }

    @Test func unknownCodeShowsHex() {
        let legend = formatter.legend(for: 0x7FFF)
        #expect(legend.primary.hasPrefix("USER") || legend.primary == "0x7FFF")
    }

    @Test func composerMatchesAnchors() {
        let composer = KeycodeComposer(table: .protocol12)
        #expect(composer.modified(0x27, with: .command) == 0x0827)
        #expect(composer.modified(0x20, with: [.shift, .command]) == 0x0A20)
        #expect(composer.layer(.to, 1) == 0x5201)
        #expect(composer.layer(.momentary, 2) == 0x5222)
        #expect(composer.macro(0) == 0x7700)
        #expect(composer.custom(1) == 0x7E01)
        #expect(composer.modTap(0x04, mods: .control) == 0x2104)
        #expect(composer.layerTap(0x2C, layer: 1) == 0x412C)
        #expect(composer.modified(0x04, with: []) == nil)
    }

    @Test func tableFollowsFirmwareVersion() {
        #expect(KeycodeTable.forFirmware(protocolVersion: 12, keycodesVersion: nil) === KeycodeTable.protocol12)
        #expect(KeycodeTable.forFirmware(protocolVersion: 13, keycodesVersion: 0x08) === KeycodeTable.keycodes8)
        #expect(KeycodeTable.forFirmware(protocolVersion: 13, keycodesVersion: 0x09) === KeycodeTable.keycodes9)
    }

    @Test func catalogHasLayersMacrosAndSearch() throws {
        let definition = try Fixtures.creatorMicro()
        let catalog = KeycodeCatalog(formatter: formatter, layerCount: 4, macroCount: 16, lightingModules: definition.keycodes)
        let layers = try #require(catalog.categories.first { $0.id == "layers" })
        #expect(layers.sections.allSatisfy { $0.options.count == 4 })
        let macros = try #require(catalog.categories.first { $0.id == "macros" })
        #expect(macros.sections.first?.options.count == 16)
        let custom = try #require(catalog.categories.first { $0.id == "custom" })
        #expect(custom.sections.first?.options.first?.code == 0x7E00)
        #expect(catalog.search("volume up").contains { $0.code == 0x00A9 })
        #expect(catalog.search("").isEmpty)
    }
}
