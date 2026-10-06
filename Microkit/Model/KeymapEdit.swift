/// One applied keymap change, kept so it can be undone.
struct KeymapEdit: Sendable {
    let layer: Int
    let selection: KeySelection
    let previous: UInt16
    let new: UInt16
}
