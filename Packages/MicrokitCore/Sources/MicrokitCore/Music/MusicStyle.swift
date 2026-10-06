/// How sound turns into light.
public enum MusicStyle: String, CaseIterable, Identifiable, Sendable, Codable {
    /// Color follows where the sound sits: bass red, mids green, treble blue.
    case spectrum
    /// Your chosen color, breathing with the bass.
    case pulse
    /// The color jumps around the rainbow on every beat.
    case beatRainbow

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .spectrum: "Spectrum"
        case .pulse: "Pulse"
        case .beatRainbow: "Beat Rainbow"
        }
    }

    public var summary: String {
        switch self {
        case .spectrum: "Color follows the sound: deep bass is red, vocals green, cymbals blue."
        case .pulse: "Your color, breathing with the bass."
        case .beatRainbow: "Jumps to a new color on every beat."
        }
    }
}
