/// One entry of a dropdown control.
public struct MenuChoice: Identifiable, Hashable, Sendable {
    public let label: String
    public let value: Int

    public var id: Int { value }
}
