/// Every keycode of the dynamic keymap, stored like the firmware does: layer, then row, then column.
public struct Keymap: Equatable, Sendable, Codable {
    public let layers: Int
    public let rows: Int
    public let cols: Int
    public private(set) var codes: [UInt16]

    public init(layers: Int, rows: Int, cols: Int, codes: [UInt16]? = nil) {
        self.layers = layers
        self.rows = rows
        self.cols = cols
        self.codes = codes ?? Array(repeating: 0, count: layers * rows * cols)
        precondition(self.codes.count == layers * rows * cols, "Keymap needs layers x rows x cols codes")
    }

    public subscript(layer: Int, row: Int, col: Int) -> UInt16 {
        get { codes[index(layer, row, col)] }
        set { codes[index(layer, row, col)] = newValue }
    }

    public func contains(layer: Int, row: Int, col: Int) -> Bool {
        (0..<layers).contains(layer) && (0..<rows).contains(row) && (0..<cols).contains(col)
    }

    private func index(_ layer: Int, _ row: Int, _ col: Int) -> Int {
        (layer * rows + row) * cols + col
    }
}
