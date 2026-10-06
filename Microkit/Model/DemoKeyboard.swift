import MicrokitCore

/// A pretend Work Louder Micro Pad, loaded with what the real one on the desk held on
/// 2026-10-04: keymap, knobs, lighting and macro M0. Changes stay in memory.
enum DemoKeyboard {
    static let info = HIDDeviceInfo(registryID: UInt64.max, productName: "Micro Pad (demo)", manufacturer: "Work Louder",
                                    vendorID: 0x574C, productID: 0xE6E3, transport: "Demo")

    static func makeMicroPad() async -> VirtualKeyboard {
        let keyboard = VirtualKeyboard(layers: 4, rows: 4, cols: 4, encoders: 2, macroCount: 16, macroBufferSize: 823)
        var keymap = Keymap(layers: 4, rows: 4, cols: 4)
        let layer0: [UInt16] = [
            0x0827, 0x0029, 0x00AB, 0x00AE,
            0x782B, 0x782C, 0x782F, 0x7E01,
            0x7700, 0x782D, 0x7832, 0x0041,
            0x7820, 0x0A20, 0x0837, 0x5201,
        ]
        let layer1: [UInt16] = [
            0x0001, 0x0001, 0x00AC, 0x00A8,
            0x001E, 0x001F, 0x0020, 0x0021,
            0x0022, 0x0023, 0x0024, 0x0025,
            0x5200, 0x0001, 0x0001, 0x5202,
        ]
        for (index, code) in layer0.enumerated() { keymap[0, index / 4, index % 4] = code }
        for (index, code) in layer1.enumerated() { keymap[1, index / 4, index % 4] = code }
        for layer in 2..<4 {
            for index in 0..<16 { keymap[layer, index / 4, index % 4] = 0x0001 }
            keymap[layer, 3, 3] = 0x5200
        }
        await keyboard.setKeymap(keymap)

        var encoders = EncoderMap(layers: 4, encoders: 2)
        for layer in 0..<4 {
            encoders[layer, 0, false] = 0x002D
            encoders[layer, 0, true] = 0x002E
            encoders[layer, 1, false] = 0x00AA
            encoders[layer, 1, true] = 0x00A9
        }
        await keyboard.setEncoders(encoders)

        // M0: hold Shift, hold Command, type "s", release both.
        await keyboard.setMacroBuffer([0x01, 0x02, 0xE1, 0x01, 0x02, 0xE3, 0x73, 0x01, 0x03, 0xE1, 0x01, 0x03, 0xE3, 0x00])

        // Lighting as found: underglow (channel 2), RGB matrix backlight (3), Work Louder indicators (0).
        let values: [[UInt8]: [UInt8]] = [
            [2, 1]: [0xFF], [2, 2]: [0x08], [2, 3]: [0x03], [2, 4]: [0xA0, 0xFF],
            [3, 1]: [0xFD], [3, 2]: [0x0A], [3, 3]: [0xFF], [3, 4]: [0x00, 0x00],
            [0, 1]: [0x03],
        ]
        for (path, bytes) in values { await keyboard.setCustomValue(path, bytes) }
        return keyboard
    }
}
