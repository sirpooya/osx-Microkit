import Foundation
import Testing
@testable import MicrokitCore

struct DefinitionTests {
    @Test func decodesCreatorMicro() throws {
        let definition = try Fixtures.creatorMicro()
        #expect(definition.name == "Creator Micro")
        #expect(definition.vendorID == 0x574C)
        #expect(definition.productID == 0xE6E3)
        #expect(definition.matrix == KeyboardMatrix(rows: 4, cols: 4))
        #expect(definition.layouts.keys.count == 16)
        #expect(definition.encoderCount == 2)
        #expect(definition.layouts.keys.first { $0.ei == 1 }.map { [$0.row, $0.col] } == [0, 3])
    }

    @Test func parsesLightingMenus() throws {
        let pages = try Fixtures.creatorMicro().lightingPages
        #expect(pages.map(\.title) == ["Lighting"])
        let sections = try #require(pages.first).sections
        #expect(sections.map(\.title) == ["Underglow", "Backlight", "Indicators"])
        let underglow = sections[0].controls
        #expect(underglow.map(\.valueName) == ["id_qmk_rgblight_brightness", "id_qmk_rgblight_effect", "id_qmk_rgblight_effect_speed", "id_qmk_rgblight_color"])
        #expect(underglow[0].kind == .range(min: 0, max: 255))
        #expect(underglow[0].path == [2, 1])
        #expect(underglow[3].kind == .color)
        #expect(underglow[3].byteCount == 2)
        if case .dropdown(let choices) = underglow[1].kind {
            #expect(choices.first == MenuChoice(label: "All Off", value: 0))
        } else {
            Issue.record("Effect should be a dropdown")
        }
        #expect(underglow[2].showIf == "{id_qmk_rgblight_effect} != 0")
    }

    @Test func rejectsSourceDefinitions() {
        let source = Data(#"{"name":"X","vendorId":"0x1","productId":"0x2","matrix":{"rows":1,"cols":1},"layouts":{"keymap":[["0,0"]]}}"#.utf8)
        #expect(throws: DefinitionError.uncompiledDefinition) {
            try KeyboardDefinition.decode(source)
        }
    }

    @Test func layoutOptionsPackLikeVIA() {
        let groups = [
            LayoutOptionGroup(label: .string("Split Backspace")),
            LayoutOptionGroup(label: .array([.string("Bottom Row"), .string("6.25u"), .string("7u"), .string("Tsangan")])),
            LayoutOptionGroup(label: .string("ISO Enter")),
        ]
        #expect(groups.map(\.bitWidth) == [1, 2, 1])
        #expect(LayoutOptions.pack([1, 2, 1], groups: groups) == 0b1_10_1)
        #expect(LayoutOptions.unpack(0b1_10_1, groups: groups) == [1, 2, 1])
        #expect(LayoutOptions.unpack(0, groups: groups) == [0, 0, 0])
    }

    @Test func visibleKeysPickChosenOption() {
        let base = LayoutKey(row: 0, col: 0, x: 0, y: 0)
        let optionA = LayoutKey(row: 0, col: 1, x: 1, y: 0, w: 2)
        let optionB = LayoutKey(row: 0, col: 1, x: 1, y: 0)
        let layout = KeyboardLayout(width: 3, height: 1, keys: [base], optionKeys: ["0": ["0": [optionA], "1": [optionB]]], labels: [.string("Split")])
        #expect(layout.visibleKeys(choices: [0]) == [base, optionA])
        #expect(layout.visibleKeys(choices: [1]) == [base, optionB])
        #expect(layout.visibleKeys() == [base, optionA])
    }
}
