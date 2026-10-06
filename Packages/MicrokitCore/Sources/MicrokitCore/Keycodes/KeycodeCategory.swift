/// A tab of the keycode picker.
public struct KeycodeCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// SF Symbol name for the tab.
    public let symbol: String
    public let sections: [KeycodeSection]

    public init(id: String, title: String, symbol: String, sections: [KeycodeSection]) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.sections = sections.filter { !$0.options.isEmpty }
    }

    public var isEmpty: Bool { sections.isEmpty }
}
