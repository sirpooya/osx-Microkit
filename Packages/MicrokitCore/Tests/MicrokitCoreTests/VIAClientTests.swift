import Testing
@testable import MicrokitCore

struct VIAClientTests {
    @Test func readsRecordedMicroPadBasics() async throws {
        let client = VIAClient(transport: RecordedTransport())
        #expect(try await client.protocolVersion() == 12)
        #expect(try await client.layerCount() == 4)
        #expect(try await client.macroCount() == 16)
        #expect(try await client.macroBufferSize() == 823)
        #expect(try await client.firmwareVersion() == 0)
    }

    @Test func missingKeycodesVersionReadsAsNil() async throws {
        let client = VIAClient(transport: RecordedTransport())
        #expect(try await client.keycodesVersion() == nil)
    }

    @Test func readsRecordedEncodersAndLighting() async throws {
        let client = VIAClient(transport: RecordedTransport())
        #expect(try await client.encoderKeycode(layer: 0, encoder: 0, clockwise: false) == 0x002D)
        #expect(try await client.encoderKeycode(layer: 0, encoder: 0, clockwise: true) == 0x002E)
        #expect(try await client.encoderKeycode(layer: 0, encoder: 1, clockwise: false) == 0x00AA)
        #expect(try await client.encoderKeycode(layer: 0, encoder: 1, clockwise: true) == 0x00A9)
        #expect(try await client.customValue(channel: 3, valueID: 1, count: 1) == [0xFD])
        #expect(try await client.customValue(channel: 2, valueID: 2, count: 1) == [0x08])
    }

    @Test func readsWholeKeymapInChunks() async throws {
        let keyboard = VirtualKeyboard()
        var keymap = Keymap(layers: 4, rows: 4, cols: 4)
        for (i, code) in RecordedMicroPad.layer0.enumerated() { keymap[0, i / 4, i % 4] = code }
        keymap[3, 3, 3] = 0x1234
        await keyboard.setKeymap(keymap)

        let read = try await VIAClient(transport: keyboard).readKeymap(layers: 4, rows: 4, cols: 4)
        #expect(read == keymap)
        let bufferReads = await keyboard.log.filter { $0[0] == VIACommand.getKeymapBuffer.rawValue }
        #expect(bufferReads.count == 5) // 128 bytes in chunks of 28
    }

    @Test func setKeycodeChangesOneKey() async throws {
        let keyboard = VirtualKeyboard()
        let client = VIAClient(transport: keyboard)
        try await client.setKeycode(0x0004, layer: 1, row: 2, col: 3)
        #expect(try await client.keycode(layer: 1, row: 2, col: 3) == 0x0004)
        #expect(try await client.keycode(layer: 0, row: 2, col: 3) == 0x0000)
    }

    @Test func writeKeymapRoundTrips() async throws {
        let keyboard = VirtualKeyboard()
        let client = VIAClient(transport: keyboard)
        let codes = (0..<64).map { UInt16($0 * 257) }
        let keymap = Keymap(layers: 4, rows: 4, cols: 4, codes: codes)
        try await client.writeKeymap(keymap)
        #expect(try await client.readKeymap(layers: 4, rows: 4, cols: 4) == keymap)
    }

    @Test func strayReportIsSkipped() async throws {
        let keyboard = VirtualKeyboard()
        var keymap = Keymap(layers: 4, rows: 4, cols: 4)
        keymap[0, 1, 1] = 0x0029
        await keyboard.setKeymap(keymap)
        // A late reply for a different key must not be taken as this one's answer.
        await keyboard.setStrayReport([0x04, 0x00, 0x03, 0x03, 0x12, 0x34])
        let code = try await VIAClient(transport: keyboard).keycode(layer: 0, row: 1, col: 1)
        #expect(code == 0x0029)
    }

    @Test func unhandledCommandThrows() async throws {
        let client = VIAClient(transport: VirtualKeyboard())
        await #expect(throws: VIAError.unhandled(command: VIACommand.customGetValue.rawValue)) {
            try await client.customValue(channel: 9, valueID: 9, count: 1)
        }
    }

    @Test func macroBufferRoundTrips() async throws {
        let keyboard = VirtualKeyboard()
        let client = VIAClient(transport: keyboard)
        let bytes = MacroCodec.encode([[.text("hello")], [.tap(0x28)]])
        try await client.writeMacroBuffer(bytes)
        let read = try await client.readMacroBuffer(size: try await client.macroBufferSize())
        #expect(MacroCodec.decode(read, count: 16).prefix(2) == [[.text("hello")], [.tap(0x28)]])
    }

    @Test(arguments: [UInt16(11), 12, 13])
    func switchMatrixStateFollowsProtocol(protocolVersion: UInt16) async throws {
        let keyboard = VirtualKeyboard()
        await keyboard.setKeycodesVersion(nil, protocolVersion: protocolVersion)
        await keyboard.press(row: 1, col: 2)
        await keyboard.press(row: 3, col: 0)
        let state = try await VIAClient(transport: keyboard).switchMatrixState(rows: 4, cols: 4, protocolVersion: protocolVersion)
        #expect(state[1][2])
        #expect(state[3][0])
        #expect(state.flatMap { $0 }.filter { $0 }.count == 2)
    }

    @Test func unpacksWideMatrixRowsMostSignificantByteFirst() {
        // 10 columns: two bytes per row, high byte first.
        let rows = VIAClient.unpackMatrixRows([0x02, 0x01], rows: 1, cols: 10)
        #expect(rows[0][0])
        #expect(rows[0][9])
        #expect(rows[0].filter { $0 }.count == 2)
    }
}
