/// One entry of `layouts.labels`: a plain string is an on/off toggle, an array is
/// `[title, choice0, choice1, ...]`.
public struct LayoutOptionGroup: Hashable, Sendable {
    public let title: String
    public let choices: [String]
    public let isToggle: Bool

    init(label: JSONValue) {
        if let array = label.array, let first = array.first?.string {
            title = first
            choices = array.dropFirst().compactMap(\.string)
            isToggle = false
        } else {
            title = label.string ?? "Option"
            choices = ["Off", "On"]
            isToggle = true
        }
    }

    /// Bits this group takes in the packed 32-bit value: VIA's `minBitSize`.
    var bitWidth: Int {
        let count = max(choices.count, 2)
        var bits = 1
        while (1 << bits) < count { bits += 1 }
        return bits
    }
}
