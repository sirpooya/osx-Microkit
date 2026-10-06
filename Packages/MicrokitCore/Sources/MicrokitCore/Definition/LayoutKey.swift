/// One key of a compiled VIA v3 definition (KLE already parsed by VIA's build).
/// Positions and sizes are in key units (1u = one standard key pitch).
public struct LayoutKey: Codable, Hashable, Sendable {
    public var row: Int
    public var col: Int
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    /// Rotation in degrees, clockwise, around (`rx`, `ry`).
    public var r: Double
    public var rx: Double
    public var ry: Double
    /// Second rectangle of stepped keys such as ISO Enter, relative to (`x`, `y`).
    public var x2: Double?
    public var y2: Double?
    public var w2: Double?
    public var h2: Double?
    /// Rotary encoder index when this key is a knob.
    public var ei: Int?
    /// `alpha`, `mod` or `accent`.
    public var color: String?
    /// Decal: drawn but not a real key.
    public var d: Bool?

    public init(row: Int, col: Int, x: Double, y: Double, w: Double = 1, h: Double = 1, r: Double = 0, rx: Double = 0, ry: Double = 0,
                x2: Double? = nil, y2: Double? = nil, w2: Double? = nil, h2: Double? = nil, ei: Int? = nil, color: String? = nil, d: Bool? = nil) {
        self.row = row
        self.col = col
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.r = r
        self.rx = rx
        self.ry = ry
        self.x2 = x2
        self.y2 = y2
        self.w2 = w2
        self.h2 = h2
        self.ei = ei
        self.color = color
        self.d = d
    }

    enum CodingKeys: String, CodingKey {
        case row, col, x, y, w, h, r, rx, ry, x2, y2, w2, h2, ei, color, d
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        row = try c.decode(Int.self, forKey: .row)
        col = try c.decode(Int.self, forKey: .col)
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0
        w = try c.decodeIfPresent(Double.self, forKey: .w) ?? 1
        h = try c.decodeIfPresent(Double.self, forKey: .h) ?? 1
        r = try c.decodeIfPresent(Double.self, forKey: .r) ?? 0
        rx = try c.decodeIfPresent(Double.self, forKey: .rx) ?? 0
        ry = try c.decodeIfPresent(Double.self, forKey: .ry) ?? 0
        x2 = try c.decodeIfPresent(Double.self, forKey: .x2)
        y2 = try c.decodeIfPresent(Double.self, forKey: .y2)
        w2 = try c.decodeIfPresent(Double.self, forKey: .w2)
        h2 = try c.decodeIfPresent(Double.self, forKey: .h2)
        ei = try c.decodeIfPresent(Int.self, forKey: .ei)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        d = try c.decodeIfPresent(Bool.self, forKey: .d)
    }

    public var isDecal: Bool { d ?? false }
    public var isEncoder: Bool { ei != nil }
}
