import Foundation
import Observation
import OSLog

/// Corrupted UserDefaults payloads are dropped and replaced by defaults;
/// this log trail is the only way to see that it happened.
let persistenceLogger = Logger(subsystem: "in.pooya.microkit", category: "Persistence")

/// Top-level mode selected in the sidebar: key mapping or lighting presets, plus Microkit's
/// own screens (music, macros, key tester, device).
enum AppMode: String, CaseIterable, Identifiable {
    case actions
    case lights
    case music
    case macros
    case tester
    case device

    var id: String { rawValue }

    var title: String {
        switch self {
        case .actions: "Actions"
        case .lights: "Lights"
        case .music: "Music"
        case .macros: "Macros"
        case .tester: "Key Tester"
        case .device: "Device"
        }
    }

    var iconAssetName: String {
        switch self {
        case .actions: "flash-on.svg"
        case .lights: "sun.svg"
        default: ""
        }
    }

    /// SF Symbol for Microkit's modes, which have no MicroMap artwork.
    var systemSymbol: String? {
        switch self {
        case .actions, .lights: nil
        case .music: "waveform"
        case .macros: "text.append"
        case .tester: "hand.tap"
        case .device: "externaldrive"
        }
    }

    /// Microkit's screens replace the controller workspace.
    var isMicrokitScreen: Bool { systemSymbol != nil }
}

/// Lighting zone selectable in the sidebar while the Lights mode is active.
enum LightingTarget: String, CaseIterable, Identifiable {
    case perimeterActiveFigma
    case perimeterOtherApps
    case keyCaps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .perimeterActiveFigma: "Perimeter - Active Figma"
        case .perimeterOtherApps: "Perimeter - Other Apps"
        case .keyCaps: "Key Caps"
        }
    }

    var inspectorTitle: String {
        switch self {
        case .perimeterActiveFigma: "Perimeter - Active Figma"
        case .perimeterOtherApps: "Perimeter - Other apps"
        case .keyCaps: "Keys - Active Figma"
        }
    }

    var subtitle: String {
        switch self {
        case .perimeterActiveFigma, .keyCaps: "Figma app is in focus"
        case .perimeterOtherApps: "Figma app is not in focus"
        }
    }

    var iconAssetName: String {
        switch self {
        case .perimeterActiveFigma: "figma-logo-outline.svg"
        case .perimeterOtherApps: "cursor.svg"
        case .keyCaps: "stop-squared.svg"
        }
    }
}

struct AppToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

@MainActor
@Observable
final class AppStore {
    private var builtInActions: [FigmaAction]
    private(set) var customActions: [FigmaAction] = [] {
        didSet { rebuildActionCatalog() }
    }
    private(set) var actions: [FigmaAction] = []
    @ObservationIgnored private var actionsByID: [String: FigmaAction] = [:]
    let device: HIDDeviceService
    /// Hardware keymap writes route through this seam so tests can record
    /// them without a connected controller; production uses `device`.
    @ObservationIgnored var keymapWriter: any ControllerKeymapWriting
    /// Spacing between serialized keymap writes; tests set zero.
    @ObservationIgnored var interWriteDelay: Duration = .milliseconds(15)
    let figmaActivityMonitor = FigmaActivityMonitor()
    let lightingStateMachine = LightingStateMachine()
    let lightingService: ControllerLightingService

    var mode: AppMode = .actions
    var selectedLightingTarget: LightingTarget = .perimeterActiveFigma
    /// Microkit: settings open in their own window (`SettingsWindowController`);
    /// the page selection lives here so the window reopens on it.
    var settingsPage: SettingsPage = .general
    /// Incremented to ask the sidebar to focus its search field (e.g. after
    /// clicking an Unassigned shortcut slot in the inspector).
    var searchFocusRequestID = 0
    var selectedActionID: String?
    var selectedSlotID: String?
    var currentLayer = 0 {
        didSet {
            UserDefaults.standard.set(currentLayer, forKey: layerPersistenceKey)
            updateLighting(layer: currentLayer)
        }
    }
    var searchText = ""
    var nightDimmingEnabled = false {
        didSet {
            UserDefaults.standard.set(nightDimmingEnabled, forKey: nightDimmingPersistenceKey)
            updateLighting()
        }
    }
    var nightLightingBrightness = 0.3 {
        didSet {
            UserDefaults.standard.set(nightLightingBrightness, forKey: nightBrightnessPersistenceKey)
            updateLighting()
        }
    }
    var lightingConfiguration: LightingConfiguration = .default {
        didSet {
            guard lightingConfiguration != oldValue else { return }
            lightingService.configuration = lightingConfiguration
            persistLightingConfiguration()
        }
    }
    var assignments = LayerAssignments()
    var keycapGlyphActionIDs: [String: String] = [:]
    var keycapColors: [String: KeycapColor] = [:]
    var lastSavedAt: Date?
    /// True while the local draft differs from what was last applied to or
    /// imported from the controller. While set, device reconnects keep the
    /// draft instead of re-importing the on-device layout over it.
    private(set) var hasUnappliedChanges = false
    var isApplying = false
    var isRefreshingDevice = false
    var isLoadingDeviceLayout = false
    var showsInitialDeviceImportChoice = false
    var toast: AppToast?
    var applicationError: String?

    private let persistenceKey = "figmaMicro.assignments.v1"
    private let layerPersistenceKey = "figmaMicro.currentLayer.v1"
    private let keycapPersistenceKey = "figmaMicro.keycapGlyphs.v1"
    private let keycapColorPersistenceKey = "figmaMicro.keycapColors.v1"
    private let nightDimmingPersistenceKey = "figmaMicro.nightDimming.v1"
    private let nightBrightnessPersistenceKey = "figmaMicro.nightLightingBrightness.v1"
    private let lightingConfigurationPersistenceKey = "figmaMicro.perimeterLighting.v1"
    private let customActionsPersistenceKey = "figmaMicro.customActions.v1"
    private let initialDeviceImportDecisionKey = "figmaMicro.initialDeviceImportDecision.v1"
    private let unappliedChangesPersistenceKey = "figmaMicro.unappliedChanges.v1"
    @ObservationIgnored private var pendingInitialDeviceLayout: [Int: [String: UInt16]]?

    var nightStartHour = 20 {
        didSet {
            UserDefaults.standard.set(nightStartHour, forKey: nightStartHourPersistenceKey)
            updateLighting()
        }
    }
    var nightEndHour = 7 {
        didSet {
            UserDefaults.standard.set(nightEndHour, forKey: nightEndHourPersistenceKey)
            updateLighting()
        }
    }
    private let nightStartHourPersistenceKey = "figmaMicro.nightStartHour.v1"
    private let nightEndHourPersistenceKey = "figmaMicro.nightEndHour.v1"

    @ObservationIgnored private var brightnessRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var lastAppliedBrightness: Double?
    @ObservationIgnored private var lightingPreviewTask: Task<Void, Never>?
    @ObservationIgnored private var toastDismissTask: Task<Void, Never>?
    @ObservationIgnored private var deviceRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var keyboardInputSourceObserver: KeyboardInputSourceObservation?

    init(devices: DeviceStore) {
        let device = HIDDeviceService(devices: devices)
        self.device = device
        keymapWriter = device
        lightingService = ControllerLightingService(device: device)
        builtInActions = Self.overridingGlobalShortcut(
            in: ShortcutCatalog.load() + SystemShortcutCatalog.actions + KeyboardActionCatalog.defaultActions,
            with: GlobalShortcut.stored
        )
        rebuildActionCatalog()
        hasUnappliedChanges = UserDefaults.standard.bool(forKey: unappliedChangesPersistenceKey)
        restoreCustomActions()
        restoreAssignments()
        restoreKeycapGlyphs()
        restoreKeycapColors()
        migrateSpecialButtons()
        seedKeycapGlyphsIfNeeded()
        seedKeycapColorsIfNeeded()
        if UserDefaults.standard.object(forKey: layerPersistenceKey) != nil {
            currentLayer = min(
                max(UserDefaults.standard.integer(forKey: layerPersistenceKey), ControllerSpecialSlot.layerRange.lowerBound),
                ControllerSpecialSlot.layerRange.upperBound - 1
            )
        }
        // Settings removed in later revisions: the global brightness slider
        // (zone presets own brightness now) and the Layer 0 "Off Mode".
        // Drop their stale stored values.
        UserDefaults.standard.removeObject(forKey: "figmaMicro.lightingBrightness.v1")
        UserDefaults.standard.removeObject(forKey: "figmaMicro.layerZeroOffMode.v1")
        UserDefaults.standard.removeObject(forKey: "figmaMicro.detectFigmaScreenSharing")
        nightDimmingEnabled = UserDefaults.standard.bool(forKey: nightDimmingPersistenceKey)
        if UserDefaults.standard.object(forKey: nightStartHourPersistenceKey) != nil {
            nightStartHour = min(max(UserDefaults.standard.integer(forKey: nightStartHourPersistenceKey), 0), 23)
        }
        if UserDefaults.standard.object(forKey: nightEndHourPersistenceKey) != nil {
            nightEndHour = min(max(UserDefaults.standard.integer(forKey: nightEndHourPersistenceKey), 0), 23)
        }
        if UserDefaults.standard.object(forKey: nightBrightnessPersistenceKey) != nil {
            nightLightingBrightness = min(max(UserDefaults.standard.double(forKey: nightBrightnessPersistenceKey), 0.05), 1.0)
        }
        restoreLightingConfiguration()
        lightingService.configuration = lightingConfiguration

        figmaActivityMonitor.onActivityChanged = { [weak self] isActive in
            self?.updateLighting(isFigmaActive: isActive)
        }
        device.onProtocolReady = { [weak self] in
            guard let self else { return }
            updateLighting()
        }
        device.onKeyboardActions = { [weak self] actions in
            self?.replaceKeyboardActions(actions)
        }
        device.onLayoutReadStarted = { [weak self] in
            self?.isLoadingDeviceLayout = true
        }
        device.onLayoutRead = { [weak self] keycodes in
            self?.handleDeviceLayout(keycodes)
        }
        keyboardInputSourceObserver = KeyboardLayoutResolver.observeInputSourceChanges { [weak self] in
            self?.keyboardInputSourceChanged()
        }
    }

    func filteredActions(in category: ShortcutCategory) -> [FigmaAction] {
        actions.filter { action in
            action.category == category && action.matches(query: searchText)
        }
    }

    var selectedAction: FigmaAction? {
        selectedActionID.flatMap { actionsByID[$0] }
    }

    var selectedSlot: ControllerSlot? {
        ControllerSlot.all.first { $0.id == selectedSlotID }
    }

    var currentLayerName: String {
        layerName(for: currentLayer)
    }

    var currentLayerDescription: String {
        "\(currentLayerName) · VIA \(currentLayer)"
    }

    func layerName(for firmwareLayer: Int) -> String {
        ControllerLayerNaming.name(for: firmwareLayer)
    }

    func startLightingMonitoring() {
        figmaActivityMonitor.start()
        updateLighting(
            layer: currentLayer,
            isFigmaActive: figmaActivityMonitor.isFigmaActive
        )
        startBrightnessRefresh()
    }

    func stopLightingMonitoring() {
        figmaActivityMonitor.stop()
        brightnessRefreshTask?.cancel()
        brightnessRefreshTask = nil
        lightingService.apply(.off, keyState: .off)
    }

    // Zone presets carry their own brightness; night dimming is the only
    // scale ever applied on top of the configured values.
    var effectiveLightingBrightness: Double {
        nightDimmingEnabled && isNightHour ? nightLightingBrightness : 1.0
    }

    var isNightHour: Bool {
        Self.isNightHour(
            Calendar.current.component(.hour, from: Date()),
            from: nightStartHour,
            until: nightEndHour
        )
    }

    /// The night window spans `start ..< end` hours and wraps past midnight
    /// when `start > end`. Equal hours mean an empty window, never a full day.
    nonisolated static func isNightHour(_ hour: Int, from start: Int, until end: Int) -> Bool {
        guard start != end else { return false }
        if start < end { return hour >= start && hour < end }
        return hour >= start || hour < end
    }

    // Reapplies the lighting when the day/night boundary is crossed.
    private func startBrightnessRefresh() {
        brightnessRefreshTask?.cancel()
        brightnessRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self else { return }
                if nightDimmingEnabled, lastAppliedBrightness != effectiveLightingBrightness {
                    updateLighting()
                }
            }
        }
    }

    func setFigmaLighting(_ config: PerimeterLightingConfig) {
        lightingConfiguration.inFigma = config
        previewLighting(perimeter: config, keys: nil)
    }

    func setAmbientLighting(_ config: PerimeterLightingConfig) {
        lightingConfiguration.outsideFigma = config
        previewLighting(perimeter: config, keys: nil)
    }

    func setKeyLighting(_ config: KeyLightingConfig) {
        lightingConfiguration.keysInFigma = config
        previewLighting(perimeter: nil, keys: config)
    }

    func setOnlyUseKeyLightingInFigma(_ enabled: Bool) {
        lightingConfiguration.onlyUseKeyLightingInFigma = enabled
        updateLighting()
    }

    func resetLightingConfiguration() {
        lightingConfiguration = .default
        updateLighting()
        presentToast("Lighting settings reset")
    }

    // Shows the adjusted preset on the hardware right away, then settles back
    // to whatever the current state machine says after a short pause. A nil
    // zone previews that zone's current state-machine configuration.
    private func previewLighting(perimeter: PerimeterLightingConfig?, keys: KeyLightingConfig?) {
        lightingService.preview(
            perimeter: perimeter ?? lightingService.perimeterConfig(for: lightingStateMachine.state),
            keys: keys ?? lightingService.keyConfig(for: currentKeyLightingScene),
            brightnessScale: effectiveLightingBrightness
        )
        lightingPreviewTask?.cancel()
        lightingPreviewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.updateLighting()
        }
    }

    func action(for slotID: String) -> FigmaAction? {
        guard let id = assignments.actionID(for: slotID, layer: currentLayer) else { return nil }
        return actionsByID[id]
    }

    func keycapGlyphAction(for slotID: String) -> FigmaAction? {
        guard let actionID = keycapGlyphActionIDs[slotID],
              let action = actionsByID[actionID],
              action.figmaAssetName != nil
        else { return nil }
        return action
    }

    func keycapAppearance(for slotID: String) -> FigmaKeyAppearance {
        if slotID == ControllerSpecialSlot.figma || slotID == ControllerSpecialSlot.layerSwitch {
            return FigmaKeyAppearance.appearance(for: slotID)
        }
        if keycapGlyphAction(for: slotID) != nil { return .black }
        if let color = keycapColors[slotID] { return color.appearance }
        return FigmaKeyAppearance.appearance(for: slotID)
    }

    func keycapColorCount(_ color: KeycapColor) -> Int {
        keycapColors.values.lazy.filter { $0 == color }.count
    }

    func canUseKeycapColor(_ color: KeycapColor, for slotID: String) -> Bool {
        guard slotID != ControllerSpecialSlot.figma,
              slotID != ControllerSpecialSlot.layerSwitch else { return false }
        return keycapColors[slotID] == color || keycapColorCount(color) < color.inventoryLimit
    }

    func setKeycapColor(_ color: KeycapColor, for slotID: String) {
        guard canUseKeycapColor(color, for: slotID) else { return }
        keycapGlyphActionIDs[slotID] = nil
        keycapColors[slotID] = color
        persistKeycaps()
    }

    func assign(actionID: String, to slotID: String) {
        guard slotID != ControllerSpecialSlot.layerSwitch else { return }
        if slotID == ControllerSpecialSlot.figma,
           actionID != ControllerSpecialSlot.openFigmaAction { return }
        guard let action = actionsByID[actionID], action.isDirectlyAssignable else { return }
        assignments.assign(actionID: actionID, to: slotID, layer: currentLayer)
        selectedSlotID = slotID
        selectedActionID = actionID
        updateKeycap(for: action, slotID: slotID)
        setUnappliedChanges(true)
        persistAssignments()
    }

    @discardableResult
    func createCustomShortcut(title: String, chord: KeyChord) -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let layout = KeyboardLayoutResolver.resolve(KeyboardLayoutPreference.current)
        guard !trimmedTitle.isEmpty,
              QMKKeycodeEncoder.encode(chord, layout: layout) != nil
        else { return false }

        customActions.append(FigmaAction(
            id: "custom-\(UUID().uuidString.lowercased())",
            title: trimmedTitle,
            category: .custom,
            symbol: "keyboard",
            chord: chord,
            assignability: .direct,
            note: "Custom keyboard shortcut",
            shortcutLabel: chord.displayName
        ))
        persistCustomActions()
        presentToast("Custom shortcut saved")
        return true
    }

    /// Updates a custom shortcut in place. Like every other assignment edit
    /// this only changes the local draft; a changed key combination reaches
    /// mapped hardware slots on the next Apply.
    @discardableResult
    func updateCustomShortcut(id: String, title: String, chord: KeyChord?) -> Bool {
        guard let index = customActions.firstIndex(where: { $0.id == id }) else { return false }
        let existing = customActions[index]
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }

        let layout = KeyboardLayoutResolver.resolve(KeyboardLayoutPreference.current)
        let keepsExistingKeycode = chord == existing.chord
        let updatedAction = FigmaAction(
            id: existing.id,
            title: trimmedTitle,
            category: .custom,
            symbol: existing.symbol,
            chord: chord,
            assignability: .direct,
            note: existing.note,
            qmkKeycode: keepsExistingKeycode ? existing.qmkKeycode : nil,
            shortcutLabel: chord?.displayName ?? existing.shortcutLabel
        )

        guard let oldKeycode = QMKKeycodeEncoder.encode(existing, layout: layout),
              let newKeycode = QMKKeycodeEncoder.encode(updatedAction, layout: layout)
        else { return false }

        customActions[index] = updatedAction
        persistCustomActions()
        if oldKeycode == newKeycode {
            presentToast("Custom shortcut renamed")
        } else if mappedSlots(forActionID: id).isEmpty {
            presentToast("Custom shortcut updated")
        } else {
            setUnappliedChanges(true)
            presentToast("Custom shortcut updated · press Apply to update the device")
        }
        return true
    }

    /// Removes a custom shortcut from the catalog and clears its draft
    /// assignments; mapped hardware slots are cleared on the next Apply.
    func deleteCustomShortcut(id: String) {
        guard customActions.contains(where: { $0.id == id }) else { return }

        let mappedSlots = mappedSlots(forActionID: id)
        for mapping in mappedSlots {
            assignments.clear(slotID: mapping.slot.id, layer: mapping.layer)
        }
        customActions.removeAll { $0.id == id }
        if selectedActionID == id { selectedActionID = nil }
        if !mappedSlots.isEmpty { setUnappliedChanges(true) }
        persistAssignments()
        persistCustomActions()
        presentToast(
            mappedSlots.isEmpty
                ? "Custom shortcut deleted"
                : "Custom shortcut deleted · press Apply to update the device"
        )
    }

    private func mappedSlots(forActionID id: String) -> [(layer: Int, slot: ControllerSlot)] {
        assignments.layers.flatMap { layer, values in
            values.compactMap { slotID, actionID in
                guard actionID == id,
                      let slot = ControllerSlot.all.first(where: { $0.id == slotID })
                else { return nil }
                return (layer, slot)
            }
        }
    }

    /// Entry point of the "click Unassigned → search → click an action" flow:
    /// selects the slot being assigned and moves focus to the sidebar search.
    func beginAssignment(for slotID: String) {
        selectedSlotID = slotID
        searchFocusRequestID += 1
    }

    func clearAssignment(for slotID: String) {
        assignments.clear(slotID: slotID, layer: currentLayer)
        setUnappliedChanges(true)
        persistAssignments()
    }

    func selectOrActivate(_ slot: ControllerSlot) {
        if slot.isLayerSwitch {
            currentLayer = (currentLayer + 1) % ControllerSpecialSlot.layerRange.count
            return
        }
        guard !slot.isFigmaButton else { return }
        selectedSlotID = slot.id
    }

    func refreshDevice() {
        deviceRefreshTask?.cancel()
        isRefreshingDevice = true
        device.refresh()
        guard isDeviceConnected else {
            isRefreshingDevice = false
            return
        }
        // Fallback only: the spinner normally stops when the layout read
        // completes in handleDeviceLayout. A full 4-layer scan takes over
        // two seconds, so the timeout must comfortably exceed it.
        deviceRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.isRefreshingDevice = false
        }
    }

    private func handleDeviceLayout(_ keycodes: [Int: [String: UInt16]]) {
        deviceRefreshTask?.cancel()
        isRefreshingDevice = false
        isLoadingDeviceLayout = false
        guard !keycodes.isEmpty else {
            presentToast("Couldn’t load the layout from the device")
            return
        }

        if !UserDefaults.standard.bool(forKey: initialDeviceImportDecisionKey) {
            pendingInitialDeviceLayout = keycodes
            showsInitialDeviceImportChoice = true
            return
        }

        // A reconnect or refresh must never overwrite edits the user hasn't
        // applied yet; the draft stays authoritative until Apply syncs it.
        guard !hasUnappliedChanges else {
            presentToast("Kept your unapplied changes · press Apply to sync the device")
            return
        }

        importDeviceLayout(keycodes)
    }

    func importInitialDeviceShortcuts() {
        guard let keycodes = pendingInitialDeviceLayout else { return }
        pendingInitialDeviceLayout = nil
        showsInitialDeviceImportChoice = false
        UserDefaults.standard.set(true, forKey: initialDeviceImportDecisionKey)
        importDeviceLayout(keycodes)
    }

    /// Clears every user-assignable key and encoder action on all four layers.
    /// The dedicated Figma and Smiley controls are intentionally untouched.
    func startWithFreshDeviceLayout() {
        guard keymapWriter.canWriteKeymap else {
            presentToast("Connect the device to start fresh")
            return
        }

        showsInitialDeviceImportChoice = false
        isApplying = true
        Task { [weak self] in
            guard let self else { return }
            var cleared = 0
            for layer in ControllerSpecialSlot.layerRange {
                for slot in ControllerSlot.all where slot.isUserAssignable {
                    guard keymapWriter.clear(slot: slot, layer: layer) else {
                        isApplying = false
                        presentToast("Couldn’t clear the controller layout")
                        return
                    }
                    cleared += 1
                    try? await Task.sleep(for: interWriteDelay)
                }
            }

            var freshAssignments = LayerAssignments()
            freshAssignments.enforceSpecialAssignments()
            assignments = freshAssignments
            selectedActionID = nil
            selectedSlotID = nil
            pendingInitialDeviceLayout = nil
            persistAssignments()
            setUnappliedChanges(false)
            UserDefaults.standard.set(true, forKey: initialDeviceImportDecisionKey)
            isApplying = false
            presentToast("Started fresh · cleared \(cleared) mappings")
        }
    }

    private func importDeviceLayout(_ keycodes: [Int: [String: UInt16]]) {
        let layout = KeyboardLayoutResolver.resolve(KeyboardLayoutPreference.current)
        var actionsByKeycode: [UInt16: FigmaAction] = [:]
        for action in actions where action.isDirectlyAssignable {
            guard let keycode = QMKKeycodeEncoder.encode(action, layout: layout) else { continue }
            if actionsByKeycode[keycode] == nil {
                actionsByKeycode[keycode] = action
            }
        }

        var imported = assignments
        var importedCustomCount = 0
        for (layer, slots) in keycodes {
            for (slotID, keycode) in slots {
                guard let slot = ControllerSlot.all.first(where: { $0.id == slotID }),
                      slot.isUserAssignable
                else { continue }

                if keycode == 0 {
                    imported.clear(slotID: slotID, layer: layer)
                    continue
                }

                let action: FigmaAction
                if let knownAction = actionsByKeycode[keycode] {
                    action = knownAction
                } else {
                    let importedAction = makeImportedCustomShortcut(keycode: keycode, layout: layout)
                    customActions.append(importedAction)
                    actionsByKeycode[keycode] = importedAction
                    importedCustomCount += 1
                    action = importedAction
                }

                imported.assign(actionID: action.id, to: slotID, layer: layer)
            }
        }
        imported.enforceSpecialAssignments()
        assignments = imported
        persistAssignments()
        setUnappliedChanges(false)
        if importedCustomCount > 0 { persistCustomActions() }

        if importedCustomCount == 0 {
            presentToast("Layout loaded from device")
        } else {
            presentToast("Layout loaded · \(importedCustomCount) shortcuts added to Custom")
        }
    }

    private func makeImportedCustomShortcut(
        keycode: UInt16,
        layout: ResolvedKeyboardLayout
    ) -> FigmaAction {
        let chord = QMKKeycodeEncoder.decode(keycode, layout: layout)
        let codeLabel = String(format: "0x%04X", keycode)
        let readableLabel = chord?.displayName ?? codeLabel
        return FigmaAction(
            id: "custom-imported-\(String(format: "%04x", keycode))-\(UUID().uuidString.lowercased())",
            title: "Imported · \(readableLabel)",
            category: .custom,
            symbol: "keyboard",
            chord: chord,
            assignability: .direct,
            note: "Imported from the connected device (\(codeLabel))",
            qmkKeycode: keycode,
            shortcutLabel: readableLabel
        )
    }

    var isDeviceConnected: Bool {
        if case .connected = device.state { return true }
        return false
    }

    /// Reapplies the configured lighting presets to the hardware right away.
    /// The presets themselves persist as they are edited; this is the explicit
    /// "Apply changes" action of the Lights mode.
    func applyLightingToController() {
        lightingPreviewTask?.cancel()
        updateLighting()
        presentToast("Lighting changes applied")
    }

    /// A layout change alters the HID code of every printable shortcut even
    /// though the visible assignments stay the same. Keep the draft dirty so
    /// the user is prompted to rewrite those codes to the controller.
    func keyboardLayoutDidChange() {
        setUnappliedChanges(true)
        presentToast("Keyboard layout changed · press Apply to update the controller")
    }

    private func keyboardInputSourceChanged() {
        guard KeyboardLayoutPreference.current == .automatic else { return }
        setUnappliedChanges(true)
        presentToast("macOS keyboard changed to \(KeyboardLayoutResolver.currentInputSourceName) · press Apply")
    }

    /// Writes the full draft to the controller: every user-assignable slot on
    /// every layer receives either its assigned keycode or KC_NO, so deletes
    /// and cleared slots reach the hardware too and the device mirrors the
    /// draft exactly.
    func applyAllLayersToController() {
        guard !isApplying else { return }
        guard keymapWriter.canWriteKeymap else {
            presentToast("Connect the device to apply changes")
            return
        }
        isApplying = true

        Task {
            var applied = 0
            var failed = 0
            assignments.enforceSpecialAssignments()
            for layer in ControllerSpecialSlot.layerRange {
                let layerAssignments = assignments.layers[layer] ?? [:]
                for slot in ControllerSlot.all where !slot.isLayerSwitch {
                    if let actionID = layerAssignments[slot.id],
                       let action = actionsByID[actionID] {
                        if keymapWriter.write(action: action, to: slot, layer: layer) {
                            applied += 1
                        } else {
                            failed += 1
                        }
                    } else if slot.isUserAssignable {
                        if !keymapWriter.clear(slot: slot, layer: layer) { failed += 1 }
                    } else {
                        continue
                    }
                    try? await Task.sleep(for: interWriteDelay)
                }
            }

            if failed == 0 {
                setUnappliedChanges(false)
                presentToast("Applied \(applied) assignments across 4 layouts")
            } else {
                presentToast("Applied \(applied) assignments · \(failed) writes failed")
            }
            isApplying = false
        }
    }

    func presentToast(_ message: String, duration: Duration = .seconds(3)) {
        toastDismissTask?.cancel()

        let nextToast = AppToast(message: message)
        toast = nextToast
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled,
                  self?.toast?.id == nextToast.id
            else { return }
            self?.toast = nil
        }
    }

    func count(in category: ShortcutCategory) -> Int {
        actions.lazy.filter { $0.category == category }.count
    }

    private func persistAssignments() {
        guard let data = encodeForPersistence(assignments, label: "assignments") else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
        lastSavedAt = Date()
    }

    private func persistCustomActions() {
        guard let data = encodeForPersistence(customActions, label: "custom shortcuts") else { return }
        UserDefaults.standard.set(data, forKey: customActionsPersistenceKey)
    }

    private func restoreCustomActions() {
        guard let decoded: [FigmaAction] = decodeFromPersistence(
            customActionsPersistenceKey, label: "custom shortcuts"
        ) else { return }
        customActions = decoded.filter { $0.category == .custom }
    }

    private func encodeForPersistence<Value: Encodable>(_ value: Value, label: String) -> Data? {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            persistenceLogger.error("Failed to encode \(label, privacy: .public): \(error, privacy: .public)")
            return nil
        }
    }

    private func decodeFromPersistence<Value: Decodable>(_ key: String, label: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            persistenceLogger.error("Dropping corrupted \(label, privacy: .public); falling back to defaults: \(error, privacy: .public)")
            return nil
        }
    }

    /// Microkit: swaps in the connected keyboard's keycode actions (its macro count and custom
    /// keycodes), keeping Figma, system and custom actions.
    private func replaceKeyboardActions(_ keyboardActions: [FigmaAction]) {
        let viaCategories: Set<ShortcutCategory> = [.keys, .media, .layers, .macros, .lighting]
        builtInActions = builtInActions.filter { !viaCategories.contains($0.category) } + keyboardActions
        rebuildActionCatalog()
    }

    private func rebuildActionCatalog() {
        actions = builtInActions + customActions
        actionsByID = Dictionary(actions.map { ($0.id, $0) }) { first, _ in first }
    }

    /// Replaces the catalog chord of the reserved Open Figma action so the
    /// keycap preview, encoder, and hardware writes all follow the
    /// user-configured global shortcut.
    private static func overridingGlobalShortcut(
        in actions: [FigmaAction],
        with shortcut: GlobalShortcut
    ) -> [FigmaAction] {
        actions.map { action in
            guard action.id == ControllerSpecialSlot.openFigmaAction else { return action }
            return FigmaAction(
                id: action.id,
                title: action.title,
                category: action.category,
                symbol: action.symbol,
                chord: shortcut.chord,
                hardwareChord: action.hardwareChord,
                keyResolution: action.keyResolution,
                assignability: action.assignability,
                note: action.note,
                qmkKeycode: action.qmkKeycode,
                shortcutLabel: action.shortcutLabel
            )
        }
    }

    /// Called after the persisted global shortcut changed: refreshes the
    /// catalog and rewrites the Figma button on every layer so the physical
    /// key fires the new chord. Falls back to the unapplied-changes flag when
    /// the controller is unreachable.
    func globalShortcutDidChange() {
        builtInActions = Self.overridingGlobalShortcut(
            in: builtInActions,
            with: GlobalShortcut.stored
        )
        rebuildActionCatalog()

        guard keymapWriter.canWriteKeymap,
              let action = actionsByID[ControllerSpecialSlot.openFigmaAction],
              let figmaSlot = ControllerSlot.all.first(where: { $0.isFigmaButton })
        else {
            setUnappliedChanges(true)
            presentToast("Shortcut saved · connect the device to update the Figma key")
            return
        }

        Task {
            var failed = 0
            for layer in ControllerSpecialSlot.layerRange {
                if !keymapWriter.write(action: action, to: figmaSlot, layer: layer) { failed += 1 }
                try? await Task.sleep(for: interWriteDelay)
            }
            if failed == 0 {
                presentToast("Figma key now fires \(action.chord?.displayName ?? "the new shortcut")")
            } else {
                setUnappliedChanges(true)
                presentToast("Shortcut saved · \(failed) hardware writes failed, press Apply to retry")
            }
        }
    }

    private func setUnappliedChanges(_ value: Bool) {
        hasUnappliedChanges = value
        UserDefaults.standard.set(value, forKey: unappliedChangesPersistenceKey)
    }

    private func updateLighting(
        layer: Int? = nil,
        isFigmaActive: Bool? = nil
    ) {
        let state = lightingStateMachine.update(
            layer: layer,
            isFigmaActive: isFigmaActive
        )
        let keyState = currentKeyLightingScene
        let brightness = effectiveLightingBrightness
        lastAppliedBrightness = brightness
        lightingService.apply(state, keyState: keyState, brightnessScale: brightness)
    }

    private var currentKeyLightingScene: CreatorMicroKeyLightingScene {
        Self.keyLightingScene(
            isFigmaActive: figmaActivityMonitor.isFigmaActive,
            onlyUseInFigma: lightingConfiguration.onlyUseKeyLightingInFigma
        )
    }

    nonisolated static func keyLightingScene(
        isFigmaActive: Bool,
        onlyUseInFigma: Bool
    ) -> CreatorMicroKeyLightingScene {
        if isFigmaActive || !onlyUseInFigma {
            .inFigma
        } else {
            .off
        }
    }

    private func persistLightingConfiguration() {
        guard let data = encodeForPersistence(lightingConfiguration, label: "lighting configuration") else { return }
        UserDefaults.standard.set(data, forKey: lightingConfigurationPersistenceKey)
    }

    private func restoreLightingConfiguration() {
        guard let decoded: LightingConfiguration = decodeFromPersistence(
            lightingConfigurationPersistenceKey, label: "lighting configuration"
        ) else { return }
        lightingConfiguration = decoded
    }

    private func restoreAssignments() {
        guard let decoded: LayerAssignments = decodeFromPersistence(
            persistenceKey, label: "assignments"
        ) else { return }
        assignments = decoded
        pruneOrphanedAssignments()
    }

    /// Drops persisted assignments whose action no longer exists in the
    /// catalog (e.g. a removed built-in shortcut). Without this the slot
    /// renders as Unassigned while the physical key keeps firing the stale
    /// keycode with no visible explanation. The next Apply clears such
    /// slots on the hardware as well.
    private func pruneOrphanedAssignments() {
        var pruned = 0
        for (layer, slots) in assignments.layers {
            for (slotID, actionID) in slots where actionsByID[actionID] == nil {
                guard actionID != ControllerSpecialSlot.openFigmaAction else { continue }
                assignments.clear(slotID: slotID, layer: layer)
                pruned += 1
            }
        }
        guard pruned > 0 else { return }
        persistAssignments()
        setUnappliedChanges(true)
        presentToast("Removed \(pruned) outdated assignment\(pruned == 1 ? "" : "s") · press Apply to update the device")
    }

    private func migrateSpecialButtons() {
        assignments.enforceSpecialAssignments()
        keycapGlyphActionIDs[ControllerSpecialSlot.figma] = nil
        keycapGlyphActionIDs[ControllerSpecialSlot.layerSwitch] = nil
        keycapColors[ControllerSpecialSlot.figma] = nil
        keycapColors[ControllerSpecialSlot.layerSwitch] = nil
        persistAssignments()
        persistKeycaps()
    }

    private func restoreKeycapGlyphs() {
        guard let decoded: [String: String] = decodeFromPersistence(
            keycapPersistenceKey, label: "keycap glyphs"
        ) else { return }
        keycapGlyphActionIDs = decoded
    }

    private func restoreKeycapColors() {
        guard let decoded: [String: KeycapColor] = decodeFromPersistence(
            keycapColorPersistenceKey, label: "keycap colors"
        ) else { return }
        keycapColors = decoded
    }

    private func seedKeycapGlyphsIfNeeded() {
        guard keycapGlyphActionIDs.isEmpty else { return }
        let baseLayer = assignments.layers[0] ?? [:]
        for slot in ControllerSlot.keys where FigmaKeyAppearance.appearance(for: slot.id).supportsPrintedIcon {
            keycapGlyphActionIDs[slot.id] = baseLayer[slot.id]
        }
        keycapGlyphActionIDs = keycapGlyphActionIDs.filter { _, actionID in
            actionsByID[actionID]?.figmaAssetName != nil
        }
        persistKeycaps()
    }

    private func seedKeycapColorsIfNeeded() {
        guard keycapColors.isEmpty else { return }
        keycapColors = ["key-2": .red, "key-12": .blue, "key-13": .green]
        persistKeycaps()
    }

    private func updateKeycap(for action: FigmaAction, slotID: String) {
        guard slotID != ControllerSpecialSlot.figma,
              slotID != ControllerSpecialSlot.layerSwitch else { return }
        guard ControllerSlot.keys.contains(where: { $0.id == slotID }) else { return }

        if let assetName = action.figmaAssetName,
           !keycapGlyphActionIDs.contains(where: { entry in
               guard entry.key != slotID,
                     let usedAction = actionsByID[entry.value]
               else { return false }
               return usedAction.figmaAssetName == assetName
           }) {
            keycapGlyphActionIDs[slotID] = action.id
            keycapColors[slotID] = nil
        } else {
            keycapGlyphActionIDs[slotID] = nil
            if keycapColors[slotID] == nil,
               let available = KeycapColor.allCases.first(where: { keycapColorCount($0) < $0.inventoryLimit }) {
                keycapColors[slotID] = available
            }
        }
        persistKeycaps()
    }

    private func persistKeycaps() {
        if let glyphData = encodeForPersistence(keycapGlyphActionIDs, label: "keycap glyphs") {
            UserDefaults.standard.set(glyphData, forKey: keycapPersistenceKey)
        }
        if let colorData = encodeForPersistence(keycapColors, label: "keycap colors") {
            UserDefaults.standard.set(colorData, forKey: keycapColorPersistenceKey)
        }
    }
}
