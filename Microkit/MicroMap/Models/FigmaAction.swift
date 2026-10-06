import Foundation

enum ShortcutCategory: String, Codable, CaseIterable, Identifiable {
    case essential = "Essential"
    case tools = "Tools"
    case view = "View"
    case zoom = "Zoom"
    case text = "Text"
    case shape = "Shape"
    case selection = "Selection"
    case cursor = "Cursor"
    case edit = "Edit"
    case transform = "Transform"
    case arrange = "Arrange"
    case components = "Components"
    // Microkit: every VIA keycode, so keys can do more than Figma shortcuts.
    case keys = "Keys"
    case media = "Media"
    case layers = "Layers"
    case macros = "Macros"
    case lighting = "Lighting"
    case system = "System"
    case custom = "Custom"

    var id: String { rawValue }

    /// Microkit's keycode groups start collapsed: they are long.
    var startsCollapsed: Bool {
        [.keys, .media, .layers, .macros, .lighting].contains(self)
    }

    /// Sidebar label from the design; raw values stay stable for decoding.
    var displayName: String {
        self == .essential ? "Essentials" : rawValue
    }

    var symbol: String {
        switch self {
        case .essential: "sparkles"
        case .tools: "hammer"
        case .view: "eye"
        case .zoom: "magnifyingglass"
        case .text: "textformat"
        case .shape: "square.on.circle"
        case .selection: "rectangle.dashed"
        case .cursor: "cursorarrow.motionlines"
        case .edit: "slider.horizontal.3"
        case .transform: "arrow.up.left.and.arrow.down.right"
        case .arrange: "square.3.layers.3d"
        case .components: "circle.grid.2x2"
        case .keys: "keyboard"
        case .media: "playpause"
        case .layers: "square.3.layers.3d"
        case .macros: "text.append"
        case .lighting: "lightbulb"
        case .system: "gearshape"
        case .custom: "keyboard"
        }
    }
}

enum KeyModifier: String, Codable, CaseIterable {
    case control
    case option
    case shift
    case command

    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }
}

struct KeyChord: Codable, Hashable {
    let modifiers: [KeyModifier]
    let key: String

    var tokens: [String] { modifiers.map(\.symbol) + [key] }
    var displayName: String { tokens.joined(separator: " ") }
}

/// How Figma/Electron matches the shortcut key. Most commands match the
/// character produced by the active macOS layout. A small class of application
/// accelerators (notably Command+digit) matches the physical ANSI key instead.
enum ShortcutKeyResolution: String, Codable, Hashable {
    case character
    case physical
}

enum Assignability: String, Codable {
    case direct
    case macro
    case mouseRequired
    case systemRequired

    var label: String {
        switch self {
        case .direct: "Ready"
        case .macro: "Macro"
        case .mouseRequired: "Mouse gesture"
        case .systemRequired: "System key"
        }
    }

    var symbol: String {
        switch self {
        case .direct: "checkmark.circle.fill"
        case .macro: "ellipsis.rectangle"
        case .mouseRequired: "computermouse"
        case .systemRequired: "exclamationmark.triangle"
        }
    }
}

struct FigmaAction: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let category: ShortcutCategory
    let symbol: String
    let chord: KeyChord?
    /// Optional canonical chord sent to hardware when Figma displays an alias
    /// (for example Zoom in is shown as Command-+ but accepts Command-=).
    let hardwareChord: KeyChord?
    let keyResolution: ShortcutKeyResolution?
    let assignability: Assignability
    let note: String?
    /// A raw VIA/QMK keycode for media keys and imported hardware mappings.
    /// Normal Figma/custom keyboard chords leave this nil and are encoded for
    /// the user's selected keyboard layout at write time.
    let qmkKeycode: UInt16?
    let shortcutLabel: String?

    init(
        id: String,
        title: String,
        category: ShortcutCategory,
        symbol: String,
        chord: KeyChord?,
        hardwareChord: KeyChord? = nil,
        keyResolution: ShortcutKeyResolution? = nil,
        assignability: Assignability,
        note: String?,
        qmkKeycode: UInt16? = nil,
        shortcutLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.symbol = symbol
        self.chord = chord
        self.hardwareChord = hardwareChord
        self.keyResolution = keyResolution
        self.assignability = assignability
        self.note = note
        self.qmkKeycode = qmkKeycode
        self.shortcutLabel = shortcutLabel
    }

    var isDirectlyAssignable: Bool {
        assignability == .direct && (chord != nil || qmkKeycode != nil)
    }

    /// Sidebar search: matches the title or the shortcut chord, e.g. "⌘ K".
    /// An empty or whitespace-only query matches everything.
    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(trimmed)
            || chord?.displayName.localizedCaseInsensitiveContains(trimmed) == true
            || shortcutLabel?.localizedCaseInsensitiveContains(trimmed) == true
    }
}
