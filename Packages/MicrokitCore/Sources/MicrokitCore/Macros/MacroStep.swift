/// One action of a dynamic macro, as stored in the firmware's macro buffer.
public enum MacroStep: Hashable, Sendable, Codable {
    /// ASCII text, typed character by character.
    case text(String)
    /// Press and release a basic keycode (0x00 to 0xFF).
    case tap(UInt8)
    /// Press and hold a basic keycode.
    case down(UInt8)
    /// Release a basic keycode.
    case up(UInt8)
    /// Wait, in milliseconds.
    case delay(Int)
}
