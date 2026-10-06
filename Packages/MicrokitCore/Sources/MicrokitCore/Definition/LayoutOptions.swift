/// VIA's packing of layout choices into the 32-bit `layoutOptions` keyboard value
/// (the-via/app `src/utils/bit-pack.ts`): the first group sits in the highest used bits,
/// the last group in the lowest.
public enum LayoutOptions {
    public static func unpack(_ packed: UInt32, groups: [LayoutOptionGroup]) -> [Int] {
        var bits = packed
        var result: [Int] = []
        for group in groups.reversed() {
            let mask = UInt32((1 << group.bitWidth) - 1)
            result.insert(Int(bits & mask), at: 0)
            bits >>= UInt32(group.bitWidth)
        }
        return result
    }

    public static func pack(_ choices: [Int], groups: [LayoutOptionGroup]) -> UInt32 {
        zip(choices, groups).reduce(UInt32(0)) { packed, pair in
            (packed << UInt32(pair.1.bitWidth)) | UInt32(pair.0)
        }
    }
}
