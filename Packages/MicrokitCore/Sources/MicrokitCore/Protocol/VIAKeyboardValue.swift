/// Value ids for `getKeyboardValue` / `setKeyboardValue` (`enum via_keyboard_value_id`).
public enum VIAKeyboardValue: UInt8, Sendable {
    case uptime = 0x01
    case layoutOptions = 0x02
    case switchMatrixState = 0x03
    case firmwareVersion = 0x04
    case deviceIndication = 0x05
    /// Added with VIA protocol 13. Older firmware answers `VIACommand.unhandled`.
    case keycodesVersion = 0x06
}
