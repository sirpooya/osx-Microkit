import Testing
@testable import MicrokitCore

struct BackupServiceTests {
    @Test func restoreUndoesChanges() async throws {
        let definition = try Fixtures.creatorMicro()
        let keyboard = VirtualKeyboard()
        var keymap = Keymap(layers: 4, rows: 4, cols: 4)
        for (i, code) in RecordedMicroPad.layer0.enumerated() { keymap[0, i / 4, i % 4] = code }
        await keyboard.setKeymap(keymap)
        var encoders = EncoderMap(layers: 4, encoders: 2)
        encoders[0, 1, true] = 0x00A9
        await keyboard.setEncoders(encoders)
        await keyboard.setCustomValue([2, 1], [0xFF])
        await keyboard.setCustomValue([3, 4], [0x10, 0x20])

        let client = VIAClient(transport: keyboard)
        let service = BackupService(client: client)
        let backup = try await service.read(definition: definition, protocolVersion: 12)
        #expect(backup.keymap == keymap)
        #expect(backup.encoders == encoders)
        #expect(backup.customValues.contains(CustomValueRecord(path: [3, 4], bytes: [0x10, 0x20])))

        // Change things, then restore.
        try await client.setKeycode(0x0004, layer: 0, row: 0, col: 0)
        try await client.setEncoderKeycode(0, layer: 0, encoder: 1, clockwise: true)
        try await client.setCustomValue(channel: 2, valueID: 1, [0x00])
        try await service.restore(backup)

        #expect(await keyboard.keymap == keymap)
        #expect(await keyboard.encoders == encoders)
        #expect(await keyboard.customValues[[2, 1]] == [0xFF])
    }

    @Test func backupSurvivesJSON() throws {
        let backup = KeyboardBackup(name: "Creator Micro", vendorProductId: 0x574CE6E3, protocolVersion: 12,
                                    keymap: Keymap(layers: 1, rows: 1, cols: 2, codes: [0x29, 0x0827]), macroBuffer: [0x68, 0])
        let decoded = try KeyboardBackup.decode(try backup.encoded())
        #expect(decoded.keymap == backup.keymap)
        #expect(decoded.macroBuffer == backup.macroBuffer)
        #expect(decoded.name == backup.name)
    }
}
