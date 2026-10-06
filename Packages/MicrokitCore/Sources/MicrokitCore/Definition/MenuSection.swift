/// A titled block of controls inside a menu page, for example "Underglow".
public struct MenuSection: Identifiable, Hashable, Sendable {
    public let title: String
    public let controls: [MenuControl]

    public var id: String { title }
}
