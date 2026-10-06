/// A top-level menu of a definition, for example "Lighting".
public struct MenuPage: Identifiable, Hashable, Sendable {
    public let title: String
    public let sections: [MenuSection]

    public var id: String { title }
}
