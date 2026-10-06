import Foundation
import MicrokitCore
import Observation

/// One connected VIA keyboard: what was read from it, and every change the UI makes to it.
///
/// Writes are applied immediately (like VIA), confirmed by reading the value back, and
/// recorded for undo. Before the first write of a launch, a full backup goes to
/// `AppPaths.backups`.
@MainActor
@Observable
final class KeyboardSession: Identifiable {
    enum Phase: Equatable {
        case loading(String)
        case ready
        case needsDefinition(String)
        case failed(String)
    }

    let id: UInt64
    let info: HIDDeviceInfo
    let client: VIAClient
    @ObservationIgnored private let definitions: DefinitionStore

    private(set) var phase: Phase = .loading("Connecting…")
    private(set) var protocolVersion: UInt16 = 0
    private(set) var keycodesVersion: UInt32?
    private(set) var firmwareVersion: UInt32 = 0
    private(set) var layerCount = 0
    private(set) var definition: KeyboardDefinition?
    private(set) var definitionSource: DefinitionStore.Source?
    private(set) var formatter = KeycodeFormatter(table: .protocol12)
    private(set) var catalog: KeycodeCatalog?
    private(set) var keymap: Keymap?
    private(set) var encoders: EncoderMap?
    private(set) var layoutChoices: [Int] = []
    private(set) var lightingValues: [String: [UInt8]] = [:]
    private(set) var macroCount = 0
    private(set) var macroBufferSize = 0
    private(set) var macros: [[MacroStep]] = []
    private(set) var undoStack: [KeymapEdit] = []
    private(set) var lastBackupURL: URL?
    /// Music mode, when the keyboard has lights with a color control.
    private(set) var music: MusicController?
    /// The most recent failed operation, shown as a banner until dismissed.
    var lastError: String?
    var selectedLayer = 0
    var selection: KeySelection?

    @ObservationIgnored private var lightingPending: [String: (MenuControl, [UInt8])] = [:]
    @ObservationIgnored private var lightingFlush: Task<Void, Never>?
    @ObservationIgnored private var lightingSave: Task<Void, Never>?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// Set for the demo keyboard: the in-memory board standing in for real hardware.
    let demoKeyboard: VirtualKeyboard?

    var isDemo: Bool { demoKeyboard != nil }

    /// The Work Louder Creator Micro (Micro Pad), which gets MicroMap's workspace.
    var isCreatorMicro: Bool { info.vendorID == 0x574C && info.productID == 0xE6E3 }

    init(transport: any ReportTransport, info: HIDDeviceInfo, demoKeyboard: VirtualKeyboard? = nil,
         definitions: DefinitionStore = .shared) {
        id = info.registryID
        self.info = info
        self.demoKeyboard = demoKeyboard
        client = VIAClient(transport: transport)
        self.definitions = definitions
    }

    var name: String { definition?.name ?? info.productName }

    /// Protocol 11 and older number keycodes differently; editing them could write the wrong key.
    var isEditable: Bool { protocolVersion >= KeycodeTable.minimumProtocol }

    var visibleKeys: [LayoutKey] {
        definition?.layouts.visibleKeys(choices: layoutChoices).filter { !$0.isDecal } ?? []
    }

    var lightingPages: [MenuPage] { definition?.lightingPages ?? [] }

    // MARK: Loading

    func start() {
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    func stop() {
        music?.disconnect()
        loadTask?.cancel()
        lightingFlush?.cancel()
        lightingSave?.cancel()
    }

    func load(refreshDefinition: Bool = false) async {
        do {
            phase = .loading("Reading firmware…")
            protocolVersion = try await client.protocolVersion()
            keycodesVersion = protocolVersion >= 13 ? try await client.keycodesVersion() : nil
            firmwareVersion = (try? await client.firmwareVersion()) ?? 0
            layerCount = try await client.layerCount()

            phase = .loading("Loading layout…")
            let vendorProductID = KeyboardDefinition.vendorProductID(vendorID: info.vendorID, productID: info.productID)
            let loaded: DefinitionStore.Loaded
            do {
                loaded = try await definitions.load(vendorProductID: vendorProductID, refresh: refreshDefinition)
            } catch {
                phase = .needsDefinition(error.localizedDescription)
                return
            }
            try await apply(definition: loaded.definition, source: loaded.source)
            phase = .ready
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func apply(definition: KeyboardDefinition, source: DefinitionStore.Source) async throws {
        self.definition = definition
        definitionSource = source
        let table = KeycodeTable.forFirmware(protocolVersion: protocolVersion, keycodesVersion: keycodesVersion)
        formatter = KeycodeFormatter(table: table, customKeycodes: definition.customKeycodes ?? [])

        phase = .loading("Reading keymap…")
        keymap = try await client.readKeymap(layers: layerCount, rows: definition.matrix.rows, cols: definition.matrix.cols)
        encoders = definition.encoderCount > 0 ? try await client.readEncoders(layers: layerCount, encoders: definition.encoderCount) : nil
        let groups = definition.layouts.optionGroups
        layoutChoices = groups.isEmpty ? [] : LayoutOptions.unpack(try await client.layoutOptions(), groups: groups)

        phase = .loading("Reading lighting…")
        var values: [String: [UInt8]] = [:]
        for control in definition.lightingPages.flatMap({ $0.sections.flatMap(\.controls) }) {
            if case .unsupported = control.kind { continue }
            if let bytes = try? await client.customValue(path: control.path, count: control.byteCount) {
                values[control.id] = bytes
            }
        }
        lightingValues = values

        phase = .loading("Reading macros…")
        macroCount = (try? await client.macroCount()) ?? 0
        if macroCount > 0 {
            macroBufferSize = try await client.macroBufferSize()
            macros = MacroCodec.decode(try await client.readMacroBuffer(size: macroBufferSize), count: macroCount)
        }

        catalog = KeycodeCatalog(formatter: formatter, layerCount: layerCount, macroCount: macroCount, lightingModules: definition.keycodes)
        if music == nil {
            let targets = MusicTarget.targets(in: definition.lightingPages)
            music = targets.isEmpty ? nil : MusicController(client: client, targets: targets)
        }
        selectedLayer = min(selectedLayer, max(layerCount - 1, 0))
    }

    func importDefinition(from url: URL) async {
        do {
            let definition = try definitions.importDefinition(from: url)
            guard definition.vendorID == info.vendorID, definition.productID == info.productID else {
                definitions.removeImported(vendorProductID: definition.vendorProductId)
                lastError = String(format: "That definition is for %04X:%04X, but this keyboard is %@.", definition.vendorID, definition.productID, info.idText)
                return
            }
            await load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func forgetImportedDefinition() async {
        guard let definition else { return }
        definitions.removeImported(vendorProductID: definition.vendorProductId)
        await load()
    }

    // MARK: Keymap

    func keycode(for key: LayoutKey) -> UInt16 {
        guard let keymap, keymap.contains(layer: selectedLayer, row: key.row, col: key.col) else { return 0 }
        return keymap[selectedLayer, key.row, key.col]
    }

    func keycode(for selection: KeySelection) -> UInt16? {
        switch selection {
        case .key(let row, let col):
            guard let keymap, keymap.contains(layer: selectedLayer, row: row, col: col) else { return nil }
            return keymap[selectedLayer, row, col]
        case .encoder(let index, let clockwise):
            guard let encoders, index < encoders.encoders, selectedLayer < encoders.layers else { return nil }
            return encoders[selectedLayer, index, clockwise]
        }
    }

    func encoderCode(_ index: Int, clockwise: Bool) -> UInt16? {
        guard let encoders, index < encoders.encoders, selectedLayer < encoders.layers else { return nil }
        return encoders[selectedLayer, index, clockwise]
    }

    func legend(for code: UInt16) -> KeyLegend { formatter.legend(for: code) }

    /// The layout key a selection points at (the knob for an encoder selection).
    func layoutKey(for selection: KeySelection) -> LayoutKey? {
        switch selection {
        case .key(let row, let col): visibleKeys.first { $0.row == row && $0.col == col }
        case .encoder(let index, _): visibleKeys.first { $0.ei == index }
        }
    }

    func select(_ key: LayoutKey) {
        selection = .key(row: key.row, col: key.col)
    }

    /// Writes `code` to the selected key or knob direction on the current layer.
    func assign(_ code: UInt16) async {
        guard isEditable, let selection, let previous = keycode(for: selection) else { return }
        guard previous != code else {
            advanceSelection()
            return
        }
        do {
            try await ensureBackup()
            let confirmed = try await write(code, to: selection, layer: selectedLayer)
            undoStack.append(KeymapEdit(layer: selectedLayer, selection: selection, previous: previous, new: confirmed))
            advanceSelection()
        } catch {
            lastError = "Could not change the key: \(error.localizedDescription)"
        }
    }

    /// One write for MicroMap's Apply: backup first, then write and read back. No undo entry and
    /// no selection change, since MicroMap keeps its own draft.
    @discardableResult
    func writeKeycode(_ code: UInt16, to selection: KeySelection, layer: Int) async throws -> UInt16 {
        guard isEditable else { throw VIAError.invalidArgument("This firmware is read-only in Microkit.") }
        try await ensureBackup()
        return try await write(code, to: selection, layer: layer)
    }

    /// A live lighting value with no save to EEPROM (MicroMap scenes, like music mode).
    func setLiveLighting(path: [UInt8], bytes: [UInt8]) async throws {
        guard isEditable else { return }
        try await client.setCustomValue(path: path, bytes)
        if let control = lightingPages.flatMap({ $0.sections.flatMap(\.controls) }).first(where: { $0.path == path }) {
            lightingValues[control.id] = bytes
        }
    }

    func undo() async {
        guard let edit = undoStack.popLast() else { return }
        do {
            _ = try await write(edit.previous, to: edit.selection, layer: edit.layer)
            selectedLayer = edit.layer
            selection = edit.selection
        } catch {
            undoStack.append(edit)
            lastError = "Could not undo: \(error.localizedDescription)"
        }
    }

    private func write(_ code: UInt16, to selection: KeySelection, layer: Int) async throws -> UInt16 {
        switch selection {
        case .key(let row, let col):
            try await client.setKeycode(code, layer: layer, row: row, col: col)
            let confirmed = try await client.keycode(layer: layer, row: row, col: col)
            keymap?[layer, row, col] = confirmed
            return confirmed
        case .encoder(let index, let clockwise):
            try await client.setEncoderKeycode(code, layer: layer, encoder: index, clockwise: clockwise)
            let confirmed = try await client.encoderKeycode(layer: layer, encoder: index, clockwise: clockwise)
            encoders?[layer, index, clockwise] = confirmed
            return confirmed
        }
    }

    /// Moves to the next key in reading order, like VIA. Knob directions stay put.
    private func advanceSelection() {
        guard case .key(let row, let col) = selection else { return }
        let ordered = visibleKeys.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        guard let index = ordered.firstIndex(where: { $0.row == row && $0.col == col }), index + 1 < ordered.count else { return }
        select(ordered[index + 1])
    }

    func resetKeymap() async {
        guard isEditable, let definition else { return }
        do {
            try await ensureBackup()
            try await client.resetKeymap()
            keymap = try await client.readKeymap(layers: layerCount, rows: definition.matrix.rows, cols: definition.matrix.cols)
            if definition.encoderCount > 0 {
                encoders = try await client.readEncoders(layers: layerCount, encoders: definition.encoderCount)
            }
            undoStack.removeAll()
        } catch {
            lastError = "Could not reset the keymap: \(error.localizedDescription)"
        }
    }

    // MARK: Layout options

    func setLayoutChoice(_ choice: Int, group: Int) async {
        guard let definition, group < layoutChoices.count else { return }
        var choices = layoutChoices
        choices[group] = choice
        do {
            try await ensureBackup()
            try await client.setLayoutOptions(LayoutOptions.pack(choices, groups: definition.layouts.optionGroups))
            layoutChoices = choices
        } catch {
            lastError = "Could not change the layout: \(error.localizedDescription)"
        }
    }

    // MARK: Lighting

    func lightingValue(_ control: MenuControl) -> [UInt8] {
        lightingValues[control.id] ?? Array(repeating: 0, count: control.byteCount)
    }

    /// First byte of every value, by name, for `showIf` expressions.
    var lightingVariables: [String: Int] {
        var variables: [String: Int] = [:]
        for control in lightingPages.flatMap({ $0.sections.flatMap(\.controls) }) {
            if let first = lightingValues[control.id]?.first { variables[control.valueName] = Int(first) }
        }
        return variables
    }

    /// Updates the value at once and streams it to the keyboard. Rapid changes (a dragged
    /// slider) are coalesced, and the value is saved to EEPROM shortly after the last change.
    func setLighting(_ control: MenuControl, bytes: [UInt8]) {
        guard isEditable, music?.isRunning != true else { return }
        lightingValues[control.id] = bytes
        lightingPending[control.id] = (control, bytes)
        if lightingFlush == nil {
            lightingFlush = Task { await flushLighting() }
        }
        lightingSave?.cancel()
        let channel = control.channel
        lightingSave = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await lightingFlush?.value
            do {
                try await ensureBackup()
                try await client.saveCustomValues(channel: channel)
            } catch {
                lastError = "Could not save lighting: \(error.localizedDescription)"
            }
        }
    }

    private func flushLighting() async {
        while let (key, item) = lightingPending.first {
            lightingPending[key] = nil
            do {
                try await client.setCustomValue(path: item.0.path, item.1)
            } catch {
                lastError = "Could not change \(item.0.label): \(error.localizedDescription)"
            }
        }
        lightingFlush = nil
    }

    // MARK: Macros

    func macroByteCount(_ macros: [[MacroStep]]) -> Int {
        MacroCodec.encode(macros).count
    }

    func saveMacros(_ newMacros: [[MacroStep]]) async -> Bool {
        let bytes = MacroCodec.encode(newMacros)
        guard bytes.count <= macroBufferSize else {
            lastError = "The macros need \(bytes.count) bytes, but the keyboard only has room for \(macroBufferSize)."
            return false
        }
        do {
            try await ensureBackup()
            try await client.writeMacroBuffer(bytes)
            macros = MacroCodec.decode(try await client.readMacroBuffer(size: macroBufferSize), count: macroCount)
            return true
        } catch {
            lastError = "Could not save macros: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: Tools

    func identify() async {
        do {
            try await client.indicateDevice()
        } catch {
            lastError = "The keyboard did not respond to identify: \(error.localizedDescription)"
        }
    }

    func matrixState() async throws -> [[Bool]] {
        guard let definition else { return [] }
        return try await client.switchMatrixState(rows: definition.matrix.rows, cols: definition.matrix.cols, protocolVersion: protocolVersion)
    }

    func makeBackup() async throws -> KeyboardBackup {
        guard let definition else { throw VIAError.invalidArgument("No layout loaded.") }
        return try await BackupService(client: client).read(definition: definition, protocolVersion: protocolVersion)
    }

    func restore(_ backup: KeyboardBackup) async {
        guard isEditable else { return }
        guard backup.vendorProductId == definition?.vendorProductId else {
            lastError = "That backup belongs to a different keyboard (\(backup.name))."
            return
        }
        do {
            try await ensureBackup()
            try await BackupService(client: client).restore(backup)
            undoStack.removeAll()
            await load()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Writes a full backup before the first change of this launch.
    private func ensureBackup() async throws {
        guard lastBackupURL == nil else { return }
        let backup = try await makeBackup()
        try FileManager.default.createDirectory(at: AppPaths.backups, withIntermediateDirectories: true)
        let stamp = backup.createdAt.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted))
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = AppPaths.backups.appending(path: "\(safeName) \(stamp).json")
        try backup.encoded().write(to: url, options: .atomic)
        lastBackupURL = url
    }
}
