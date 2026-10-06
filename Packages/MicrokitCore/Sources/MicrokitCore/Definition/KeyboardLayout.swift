/// `layouts` of a compiled definition.
public struct KeyboardLayout: Codable, Hashable, Sendable {
    public let width: Double
    public let height: Double
    public let keys: [LayoutKey]
    /// Group index, then choice index, then the keys that choice adds.
    public let optionKeys: [String: [String: [LayoutKey]]]?
    public let labels: [JSONValue]?

    public init(width: Double, height: Double, keys: [LayoutKey], optionKeys: [String: [String: [LayoutKey]]]? = nil, labels: [JSONValue]? = nil) {
        self.width = width
        self.height = height
        self.keys = keys
        self.optionKeys = optionKeys
        self.labels = labels
    }

    public var optionGroups: [LayoutOptionGroup] {
        (labels ?? []).map(LayoutOptionGroup.init(label:))
    }

    /// Base keys plus the keys of the chosen option in each group (choice 0 when unknown).
    public func visibleKeys(choices: [Int] = []) -> [LayoutKey] {
        var result = keys
        for (group, options) in optionKeys ?? [:] {
            guard let groupIndex = Int(group) else { continue }
            let choice = groupIndex < choices.count ? choices[groupIndex] : 0
            result += options[String(choice)] ?? options["0"] ?? []
        }
        return result
    }

    /// Every key of every option, for counting encoders.
    var allKeys: [LayoutKey] {
        keys + (optionKeys ?? [:]).values.flatMap { $0.values.flatMap { $0 } }
    }
}
