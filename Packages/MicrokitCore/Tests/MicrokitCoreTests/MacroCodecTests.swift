import Testing
@testable import MicrokitCore

struct MacroCodecTests {
    @Test func encodesTheFirmwareFormat() {
        let bytes = MacroCodec.encode(steps: [.text("hi"), .tap(0x28), .delay(100), .down(0xE3), .up(0xE3)])
        #expect(bytes == [0x68, 0x69, 0x01, 0x01, 0x28, 0x01, 0x04, 0x31, 0x30, 0x30, 0x7C, 0x01, 0x02, 0xE3, 0x01, 0x03, 0xE3])
    }

    @Test func roundTripsSeveralMacros() {
        let macros: [[MacroStep]] = [
            [.text("hello world")],
            [],
            [.down(0xE3), .tap(0x06), .up(0xE3), .delay(25), .text("ok")],
        ]
        let decoded = MacroCodec.decode(MacroCodec.encode(macros) + [0, 0, 0], count: 5)
        #expect(Array(decoded.prefix(3)) == macros)
        #expect(decoded.count == 5)
        #expect(decoded[3].isEmpty)
    }

    @Test func dropsCharactersTheFirmwareCannotType() {
        #expect(MacroCodec.encode(steps: [.text("a\u{01}é")]) == [0x61])
    }
}
