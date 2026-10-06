/// What the analyzer heard in one moment of audio. Every value is normalized to 0...1.
public struct AudioFeatures: Equatable, Sendable {
    /// Loudness of the bands, low to high, for an on-screen spectrum.
    public var bands: [Float]
    public var bass: Float
    public var mid: Float
    public var treble: Float
    /// Overall loudness.
    public var level: Float
    /// A kick or other bass hit started now.
    public var isBeat: Bool

    public init(bands: [Float] = [], bass: Float = 0, mid: Float = 0, treble: Float = 0, level: Float = 0, isBeat: Bool = false) {
        self.bands = bands
        self.bass = bass
        self.mid = mid
        self.treble = treble
        self.level = level
        self.isBeat = isBeat
    }

    public static let silence = AudioFeatures()
}
