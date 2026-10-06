/// Indexed lookup over one `QMKKeycodeSpec`.
public final class KeycodeTable: Sendable {
    public let spec: QMKKeycodeSpec
    private let byCode: [UInt16: QMKKeycodeSpec.Entry]
    private let byName: [String: UInt16]

    init(spec: QMKKeycodeSpec) {
        self.spec = spec
        byCode = Dictionary(spec.keycodes.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
        var names: [String: UInt16] = [:]
        for entry in spec.keycodes {
            for name in [entry.key] + entry.aliases where names[name] == nil {
                names[name] = entry.code
            }
        }
        byName = names
    }

    /// QMK 0.0.7 numbering: what VIA protocol 12 firmware uses.
    public static let protocol12 = KeycodeTable(spec: .v0_0_7)
    public static let keycodes8 = KeycodeTable(spec: .v0_0_8)
    public static let keycodes9 = KeycodeTable(spec: .v0_0_9)

    /// The oldest protocol whose keycode numbering these tables match. Protocol 11 and older
    /// number macros, layers and lighting differently.
    public static let minimumProtocol: UInt16 = 12

    /// Picks the table that matches the firmware. Protocol 13 reports its keycodes version.
    public static func forFirmware(protocolVersion: UInt16, keycodesVersion: UInt32?) -> KeycodeTable {
        guard protocolVersion >= 13, let keycodesVersion else { return protocol12 }
        return keycodesVersion >= 0x09 ? keycodes9 : keycodes8
    }

    public func entry(for code: UInt16) -> QMKKeycodeSpec.Entry? { byCode[code] }

    public func code(named name: String) -> UInt16? { byName[name] }

    /// The narrowest range holding `code` (QK_UNICODEMAP before QK_UNICODE).
    public func range(containing code: UInt16) -> QMKKeycodeSpec.Range? {
        spec.ranges.filter { $0.contains(code) }.min { $0.size < $1.size }
    }

    public func entries(inGroup group: String) -> [QMKKeycodeSpec.Entry] {
        spec.keycodes.filter { $0.group == group }
    }
}
