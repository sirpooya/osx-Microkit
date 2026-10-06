/// One pickable keycode.
public struct KeycodeOption: Identifiable, Hashable, Sendable {
    public let code: UInt16
    public let legend: KeyLegend

    public var id: UInt16 { code }

    public init(code: UInt16, legend: KeyLegend) {
        self.code = code
        self.legend = legend
    }

    /// Lowercased text the picker's search field matches against.
    public var searchText: String {
        [legend.primary, legend.secondary ?? "", legend.qmkName, legend.help].joined(separator: " ").lowercased()
    }
}
