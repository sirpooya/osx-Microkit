/// What the keycode picker is about to change.
enum KeySelection: Hashable, Sendable {
    /// A switch in the matrix (also the press action of a knob).
    case key(row: Int, col: Int)
    /// One turn direction of a rotary encoder.
    case encoder(index: Int, clockwise: Bool)
}
