/// Encodes and decodes the dynamic macro buffer (qmk_firmware `send_string` format):
/// macros are consecutive NUL-terminated byte strings; plain bytes are typed as ASCII;
/// `0x01` introduces an action: `01 01 kc` tap, `01 02 kc` down, `01 03 kc` up,
/// `01 04 <digits> |` delay in milliseconds.
public enum MacroCodec {
    static let prefix: UInt8 = 0x01
    static let tapCode: UInt8 = 0x01
    static let downCode: UInt8 = 0x02
    static let upCode: UInt8 = 0x03
    static let delayCode: UInt8 = 0x04
    static let delayTerminator: UInt8 = 0x7C // "|"

    /// Splits the buffer into `count` macros. Missing macros are empty.
    public static func decode(_ buffer: [UInt8], count: Int) -> [[MacroStep]] {
        var macros: [[MacroStep]] = []
        var index = 0
        while macros.count < count {
            var steps: [MacroStep] = []
            var text: [UInt8] = []
            func flushText() {
                if !text.isEmpty {
                    steps.append(.text(String(decoding: text, as: UTF8.self)))
                    text.removeAll()
                }
            }
            while index < buffer.count, buffer[index] != 0 {
                let byte = buffer[index]
                if byte == prefix, index + 1 < buffer.count {
                    flushText()
                    let action = buffer[index + 1]
                    switch action {
                    case tapCode, downCode, upCode:
                        guard index + 2 < buffer.count else { index = buffer.count; break }
                        let keycode = buffer[index + 2]
                        steps.append(action == tapCode ? .tap(keycode) : action == downCode ? .down(keycode) : .up(keycode))
                        index += 3
                    case delayCode:
                        var cursor = index + 2
                        var digits = ""
                        while cursor < buffer.count, buffer[cursor] != delayTerminator, buffer[cursor] != 0 {
                            digits.append(Character(UnicodeScalar(buffer[cursor])))
                            cursor += 1
                        }
                        steps.append(.delay(Int(digits) ?? 0))
                        index = cursor < buffer.count && buffer[cursor] == delayTerminator ? cursor + 1 : cursor
                    default:
                        index += 2
                    }
                } else {
                    text.append(byte)
                    index += 1
                }
            }
            flushText()
            macros.append(steps)
            index += 1
        }
        return macros
    }

    public static func encode(_ macros: [[MacroStep]]) -> [UInt8] {
        macros.flatMap { encode(steps: $0) + [0] }
    }

    public static func encode(steps: [MacroStep]) -> [UInt8] {
        steps.flatMap { step -> [UInt8] in
            switch step {
            case .text(let text):
                // Only printable ASCII and the control characters send_string understands survive.
                Array(text.utf8).filter { $0 >= 0x08 && $0 < 0x80 && $0 != prefix }
            case .tap(let keycode):
                [prefix, tapCode, keycode]
            case .down(let keycode):
                [prefix, downCode, keycode]
            case .up(let keycode):
                [prefix, upCode, keycode]
            case .delay(let milliseconds):
                [prefix, delayCode] + Array(String(max(0, milliseconds)).utf8) + [delayTerminator]
            }
        }
    }
}
