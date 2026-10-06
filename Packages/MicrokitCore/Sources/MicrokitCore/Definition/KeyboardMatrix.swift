public struct KeyboardMatrix: Codable, Hashable, Sendable {
    public let rows: Int
    public let cols: Int

    public init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }
}
