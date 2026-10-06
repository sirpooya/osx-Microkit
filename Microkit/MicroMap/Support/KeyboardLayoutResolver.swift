import Carbon
import Foundation

struct KeyboardLayoutPreference: RawRepresentable, Hashable, Identifiable, Sendable {
    static let storageKey = "figmaMicro.keyboardLayout.v1"
    private static let inputSourcePrefix = "input-source:"

    static let automatic = Self(rawValue: "automatic")
    /// Kept as an always-available fallback and for migration from v1.
    static let genericUS = Self(rawValue: "genericUS")

    let rawValue: String
    var id: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static func inputSource(_ identifier: String) -> Self {
        Self(rawValue: inputSourcePrefix + identifier)
    }

    var inputSourceIdentifier: String? {
        guard rawValue.hasPrefix(Self.inputSourcePrefix) else { return nil }
        return String(rawValue.dropFirst(Self.inputSourcePrefix.count))
    }

    static var current: KeyboardLayoutPreference {
        guard let rawValue = UserDefaults.standard.string(forKey: storageKey) else { return .automatic }
        return Self(rawValue: rawValue)
    }
}

struct KeyboardLayoutChoice: Identifiable, Hashable, Sendable {
    let preference: KeyboardLayoutPreference
    let title: String
    var id: String { preference.id }
}

/// Owns the distributed-notification token and unregisters it when its store
/// goes away. Foundation's opaque token predates Swift concurrency; access is
/// confined to initialization and deinitialization.
final class KeyboardInputSourceObservation: @unchecked Sendable {
    private let token: NSObjectProtocol

    init(token: NSObjectProtocol) {
        self.token = token
    }

    deinit {
        DistributedNotificationCenter.default.removeObserver(token)
    }
}

struct ResolvedKeyboardStroke: Equatable, Sendable {
    let keycode: UInt8
    let modifiers: [KeyModifier]
}

struct ResolvedKeyboardLayout: Sendable {
    let identifier: String
    let displayName: String
    private let strokes: [String: ResolvedKeyboardStroke]
    private let keyNamesByKeycode: [UInt8: String]

    static let genericUS = ResolvedKeyboardLayout(
        identifier: "generic-us",
        displayName: "Generic / US QWERTY",
        strokes: [:]
    )

    init(identifier: String, displayName: String, strokes: [String: ResolvedKeyboardStroke]) {
        self.identifier = identifier
        self.displayName = displayName
        self.strokes = strokes
        var reverse: [UInt8: String] = [:]
        for (key, stroke) in strokes where stroke.modifiers.isEmpty {
            let display = key.count == 1 ? key.uppercased() : key
            if let existing = reverse[stroke.keycode], existing <= display { continue }
            reverse[stroke.keycode] = display
        }
        keyNamesByKeycode = reverse
    }

    func stroke(for key: String) -> ResolvedKeyboardStroke? {
        strokes[Self.lookupKey(for: key)]
    }

    /// Inverse of `stroke(for:)` for unmodified keys: names the character the
    /// active layout prints at a HID position, so decoded hardware keycodes
    /// display the user's actual key. Ties resolve deterministically.
    func keyName(forKeycode keycode: UInt8) -> String? {
        keyNamesByKeycode[keycode]
    }

    private static func lookupKey(for key: String) -> String {
        // Figma labels its comma/period typography shortcuts with angle
        // brackets. Shift belongs to the action, not implicitly to the key.
        switch key {
        case "<": ","
        case ">": "."
        default: key.lowercased()
        }
    }
}

@MainActor
enum KeyboardLayoutResolver {
    private static var cachedLayouts: [String: ResolvedKeyboardLayout] = [:]

    static func resolve(_ preference: KeyboardLayoutPreference) -> ResolvedKeyboardLayout {
        if preference == .genericUS { return .genericUS }
        if preference == .automatic { return currentMacOSLayout() ?? .genericUS }
        guard let identifier = preference.inputSourceIdentifier,
              let metadata = sourceMetadata(includeAllInstalled: true)
                .first(where: { $0.identifier == identifier })
        else { return currentMacOSLayout() ?? .genericUS }
        return resolvedLayout(from: metadata) ?? currentMacOSLayout() ?? .genericUS
    }

    static var availableChoices: [KeyboardLayoutChoice] {
        var choices = [KeyboardLayoutChoice(preference: .automatic, title: "Automatic (recommended)")]
        let installed = sourceMetadata(includeAllInstalled: false)
            .filter { layoutData(source: $0.source) != nil }
            .sorted {
                let comparison = $0.displayName.localizedStandardCompare($1.displayName)
                return comparison == .orderedSame
                    ? $0.identifier < $1.identifier
                    : comparison == .orderedAscending
            }

        var seen = Set<String>()
        for metadata in installed where seen.insert(metadata.identifier).inserted {
            choices.append(KeyboardLayoutChoice(
                preference: .inputSource(metadata.identifier),
                title: metadata.displayName
            ))
        }

        // Keep a persisted manual choice visible even if the user later
        // disables that input source. Without a matching Picker tag SwiftUI
        // renders an empty selection and gives no explanation for the fallback.
        let persisted = KeyboardLayoutPreference.current
        if let persistedIdentifier = persisted.inputSourceIdentifier,
           !seen.contains(persistedIdentifier) {
            let installedMetadata = sourceMetadata(includeAllInstalled: true)
                .first(where: { $0.identifier == persistedIdentifier })
            choices.append(KeyboardLayoutChoice(
                preference: persisted,
                title: installedMetadata.map { "\($0.displayName) (not enabled)" }
                    ?? "Unavailable layout (\(persistedIdentifier))"
            ))
        }
        choices.append(KeyboardLayoutChoice(
            preference: .genericUS,
            title: "US QWERTY (built-in fallback)"
        ))
        return choices
    }

    static var currentInputSourceName: String {
        currentSourceMetadata()?.displayName ?? "Unavailable"
    }

    static var currentInputSourcePreference: KeyboardLayoutPreference? {
        currentSourceMetadata().map { .inputSource($0.identifier) }
    }

    static var effectiveShortcutLayoutName: String {
        resolve(KeyboardLayoutPreference.current).displayName
    }

    static func effectiveShortcutLayoutName(for rawPreference: String) -> String {
        resolve(KeyboardLayoutPreference(rawValue: rawPreference)).displayName
    }

    static func inputSourceDidChange() {
        // Input source identifiers normally change as well, but clearing the
        // cache also covers layouts that are modified or replaced in place.
        cachedLayouts.removeAll()
    }

    static func observeInputSourceChanges(
        _ handler: @escaping @MainActor @Sendable () -> Void
    ) -> KeyboardInputSourceObservation {
        let token = DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                inputSourceDidChange()
                handler()
            }
        }
        return KeyboardInputSourceObservation(token: token)
    }

    private static func currentMacOSLayout() -> ResolvedKeyboardLayout? {
        guard let metadata = currentSourceMetadata() else { return nil }
        return resolvedLayout(from: metadata)
    }

    private static func resolvedLayout(from metadata: SourceMetadata) -> ResolvedKeyboardLayout? {
        if let cached = cachedLayouts[metadata.identifier] { return cached }

        guard let data = layoutData(source: metadata.source) else { return nil }
        guard let bytePointer = CFDataGetBytePtr(data) else { return nil }

        let modifierCandidates: [([KeyModifier], UInt32)] = [
            ([], 0),
            ([.shift], UInt32(shiftKey >> 8)),
            ([.option], UInt32(optionKey >> 8)),
            ([.option, .shift], UInt32((optionKey | shiftKey) >> 8)),
        ]
        // The rebound pointer is only valid inside the closure, so the whole
        // translation loop runs within it.
        let strokes = bytePointer.withMemoryRebound(
            to: UCKeyboardLayout.self,
            capacity: 1
        ) { keyboardLayout in
            var strokes: [String: ResolvedKeyboardStroke] = [:]
            for (virtualKey, hidUsage) in macVirtualKeyToHIDUsage {
                for (modifiers, carbonModifiers) in modifierCandidates {
                    guard let output = translatedOutput(
                        keyboardLayout: keyboardLayout,
                        virtualKey: virtualKey,
                        carbonModifiers: carbonModifiers
                    ), output.count == 1 else { continue }

                    let lookupKey = output.lowercased()
                    let candidate = ResolvedKeyboardStroke(keycode: hidUsage, modifiers: modifiers)
                    if let existing = strokes[lookupKey],
                       existing.modifiers.count <= candidate.modifiers.count {
                        continue
                    }
                    strokes[lookupKey] = candidate
                }
            }
            return strokes
        }

        let layout = ResolvedKeyboardLayout(
            identifier: metadata.identifier,
            displayName: metadata.displayName,
            strokes: strokes
        )
        cachedLayouts[metadata.identifier] = layout
        return layout
    }

    private static func translatedOutput(
        keyboardLayout: UnsafePointer<UCKeyboardLayout>,
        virtualKey: UInt16,
        carbonModifiers: UInt32
    ) -> String? {
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var characterCount = 0
        let status = UCKeyTranslate(
            keyboardLayout,
            virtualKey,
            UInt16(kUCKeyActionDown),
            carbonModifiers,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &characterCount,
            &characters
        )
        guard status == noErr, characterCount > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: characterCount)
    }

    private struct SourceMetadata {
        let source: TISInputSource
        let identifier: String
        let displayName: String
    }

    private static func currentSourceMetadata() -> SourceMetadata? {
        guard let unmanagedSource = TISCopyCurrentKeyboardLayoutInputSource() else { return nil }
        let source = unmanagedSource.takeRetainedValue()
        let identifier = propertyString(source: source, key: kTISPropertyInputSourceID)
            ?? "unknown-input-source"
        let displayName = propertyString(source: source, key: kTISPropertyLocalizedName)
            ?? identifier
        return SourceMetadata(source: source, identifier: identifier, displayName: displayName)
    }

    private static func sourceMetadata(includeAllInstalled: Bool) -> [SourceMetadata] {
        guard let unmanagedSources = TISCreateInputSourceList(nil, includeAllInstalled) else { return [] }
        let sources = unmanagedSources.takeRetainedValue() as NSArray
        return sources.compactMap { value in
            let source = value as! TISInputSource
            guard let identifier = propertyString(source: source, key: kTISPropertyInputSourceID)
            else { return nil }
            let displayName = propertyString(source: source, key: kTISPropertyLocalizedName)
                ?? identifier
            return SourceMetadata(source: source, identifier: identifier, displayName: displayName)
        }
    }

    private static func layoutData(source: TISInputSource) -> CFData? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
    }

    private static func propertyString(source: TISInputSource, key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    // Carbon virtual key codes translated to the USB HID usages understood by
    // QMK/VIA. Includes the ANSI block plus the ISO section key used by many
    // European keyboards.
    private static let macVirtualKeyToHIDUsage: [UInt16: UInt8] = [
        0x00: 0x04, 0x01: 0x16, 0x02: 0x07, 0x03: 0x09,
        0x04: 0x0B, 0x05: 0x0A, 0x06: 0x1D, 0x07: 0x1B,
        0x08: 0x06, 0x09: 0x19, 0x0A: 0x64, 0x0B: 0x05,
        0x0C: 0x14, 0x0D: 0x1A, 0x0E: 0x08, 0x0F: 0x15,
        0x10: 0x1C, 0x11: 0x17, 0x12: 0x1E, 0x13: 0x1F,
        0x14: 0x20, 0x15: 0x21, 0x16: 0x23, 0x17: 0x22,
        0x18: 0x2E, 0x19: 0x26, 0x1A: 0x24, 0x1B: 0x2D,
        0x1C: 0x25, 0x1D: 0x27, 0x1E: 0x30, 0x1F: 0x12,
        0x20: 0x18, 0x21: 0x2F, 0x22: 0x0C, 0x23: 0x13,
        0x25: 0x0F, 0x26: 0x0D, 0x27: 0x34, 0x28: 0x0E,
        0x29: 0x33, 0x2A: 0x31, 0x2B: 0x36, 0x2C: 0x38,
        0x2D: 0x11, 0x2E: 0x10, 0x2F: 0x37, 0x32: 0x35,
    ]
}
