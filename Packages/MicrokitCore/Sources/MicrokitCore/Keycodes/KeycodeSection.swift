/// A titled group of keycodes inside a category, for example "Letters".
public struct KeycodeSection: Identifiable, Hashable, Sendable {
    public let title: String
    public let options: [KeycodeOption]

    public var id: String { title }

    public init(title: String, options: [KeycodeOption]) {
        self.title = title
        self.options = options
    }
}
