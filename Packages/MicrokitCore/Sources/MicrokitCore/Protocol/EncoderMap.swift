/// Rotary encoder keycodes per layer: one for counter-clockwise, one for clockwise.
public struct EncoderMap: Equatable, Sendable, Codable {
    public let layers: Int
    public let encoders: Int
    public private(set) var codes: [UInt16]

    public init(layers: Int, encoders: Int, codes: [UInt16]? = nil) {
        self.layers = layers
        self.encoders = encoders
        self.codes = codes ?? Array(repeating: 0, count: layers * encoders * 2)
        precondition(self.codes.count == layers * encoders * 2, "EncoderMap needs layers x encoders x 2 codes")
    }

    public subscript(layer: Int, encoder: Int, clockwise: Bool) -> UInt16 {
        get { codes[index(layer, encoder, clockwise)] }
        set { codes[index(layer, encoder, clockwise)] = newValue }
    }

    private func index(_ layer: Int, _ encoder: Int, _ clockwise: Bool) -> Int {
        (layer * encoders + encoder) * 2 + (clockwise ? 1 : 0)
    }
}
