/// One color for the keyboard, in the units VIA lighting uses (0...255 each).
public struct MusicLightFrame: Equatable, Sendable {
    public var hue: UInt8
    public var saturation: UInt8
    public var brightness: UInt8

    public init(hue: UInt8, saturation: UInt8, brightness: UInt8) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
}
