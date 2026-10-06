/// Command ids from qmk_firmware `quantum/via.h` (`enum via_command_id`).
public enum VIACommand: UInt8, Sendable, CaseIterable {
    case getProtocolVersion = 0x01
    case getKeyboardValue = 0x02
    case setKeyboardValue = 0x03
    case getKeycode = 0x04
    case setKeycode = 0x05
    case resetKeymap = 0x06
    case customSetValue = 0x07
    case customGetValue = 0x08
    case customSave = 0x09
    case eepromReset = 0x0A
    case bootloaderJump = 0x0B
    case macroGetCount = 0x0C
    case macroGetBufferSize = 0x0D
    case macroGetBuffer = 0x0E
    case macroSetBuffer = 0x0F
    case macroReset = 0x10
    case getLayerCount = 0x11
    case getKeymapBuffer = 0x12
    case setKeymapBuffer = 0x13
    case getEncoder = 0x14
    case setEncoder = 0x15

    /// Reply byte 0 when the firmware does not know the command or the value id.
    public static let unhandled: UInt8 = 0xFF

    /// How many request bytes after the command id the firmware sends back unchanged.
    /// `via.c` answers in the same buffer it received, so these bytes identify which
    /// request a reply belongs to.
    public var echoLength: Int {
        switch self {
        case .getProtocolVersion, .macroGetCount, .macroGetBufferSize, .getLayerCount,
             .resetKeymap, .eepromReset, .bootloaderJump, .macroReset:
            0
        case .getKeyboardValue, .setKeyboardValue, .customSave:
            1
        case .customSetValue, .customGetValue:
            2
        case .getKeycode, .getKeymapBuffer, .setKeymapBuffer, .macroGetBuffer, .macroSetBuffer, .getEncoder:
            3
        case .setKeycode, .setEncoder:
            5
        }
    }

    /// Commands that change what is stored on the keyboard.
    public var writes: Bool {
        switch self {
        case .setKeyboardValue, .setKeycode, .resetKeymap, .customSetValue, .customSave, .eepromReset,
             .bootloaderJump, .macroSetBuffer, .macroReset, .setKeymapBuffer, .setEncoder:
            true
        default:
            false
        }
    }
}
