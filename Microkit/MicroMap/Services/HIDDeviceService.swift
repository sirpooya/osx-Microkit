import Foundation
import MicrokitCore
import Observation
import OSLog

// Microkit: MicroMap's original HIDDeviceService opened the controller with its own IOHIDManager.
// Microkit already owns the device (DeviceStore, one serial transport per board), and two
// stacks on one Raw HID interface would share the controller's single response buffer. This
// adapter keeps MicroMap's interface and lighting command logic and routes all I/O through the
// selected Creator Micro `KeyboardSession` (real or demo): writes get Microkit's automatic
// backup and read-back, and nothing here ever sends custom_save, eeprom reset or macro reset.

private let hidLogger = Logger(subsystem: "in.pooya.microkit", category: "micromap")

enum ControllerConnectionState: Equatable {
    case disconnected
    case connected(name: String)
    case unavailable(message: String)
}

@MainActor
@Observable
final class HIDDeviceService {
    static let vendorID: UInt16 = 0x574C
    static let productID: UInt16 = 0xE6E3

    private(set) var state: ControllerConnectionState = .disconnected
    let reportSize = 32
    private(set) var protocolVersion: UInt16?
    private(set) var layerCount: Int?
    private(set) var lightingChannel: UInt8?
    private(set) var keyLightingChannel: UInt8?
    private(set) var lastError: String?
    var onProtocolReady: (() -> Void)?
    var onLayoutReadStarted: (() -> Void)?
    /// Microkit: the connected keyboard's keycodes as actions, before its layout is reported.
    var onKeyboardActions: (([FigmaAction]) -> Void)?
    var onLayoutRead: (([Int: [String: UInt16]]) -> Void)?

    @ObservationIgnored private let devices: DeviceStore
    @ObservationIgnored private var connectedSessionID: UInt64?
    @ObservationIgnored private var writeChain: Task<Void, Never>?
    @ObservationIgnored private var lightingWriteTask: Task<Void, Never>?
    @ObservationIgnored private var inFlightLightingScene: LightingSceneRequest?
    @ObservationIgnored private var lastAppliedLightingScene: LightingSceneRequest?

    private struct LightingSceneRequest {
        let config: PerimeterLightingConfig
        let label: String
        let keyConfig: KeyLightingConfig
        let brightnessScale: Double
        let perimeterChannel: UInt8?
        let keyChannel: UInt8?

        /// Same visual outcome on the same channels; the label is ignored.
        func matches(_ other: LightingSceneRequest?) -> Bool {
            guard let other else { return false }
            return config == other.config
                && keyConfig == other.keyConfig
                && brightnessScale == other.brightnessScale
                && perimeterChannel == other.perimeterChannel
                && keyChannel == other.keyChannel
        }
    }

    // Spacing between serialized VIA lighting writes (MicroMap: 30 ms proved reliable on hardware).
    private let interCommandDelayMilliseconds = 30

    init(devices: DeviceStore) {
        self.devices = devices
        observeDevices()
    }

    /// The Creator Micro session MicroMap drives: the selected keyboard when it is a Creator Micro
    /// (the demo Micro Pad included), otherwise the first ready Creator Micro.
    var session: KeyboardSession? {
        let candidates = devices.sessions.filter { $0.info.vendorID == Self.vendorID && $0.info.productID == Self.productID }
        if let selected = devices.selectedSession, candidates.contains(where: { $0 === selected }) { return selected }
        return candidates.first
    }

    func refresh() {
        guard let session else { return }
        connectedSessionID = nil
        Task {
            await session.load()
            sync()
        }
    }

    // MARK: Following the device store

    private func observeDevices() {
        withObservationTracking {
            _ = devices.sessions.map(\.phase)
            _ = devices.selectedID
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.sync()
                self?.observeDevices()
            }
        }
        sync()
    }

    private func sync() {
        guard let session else {
            if state != .disconnected { hidLogger.info("Creator Micro disconnected") }
            resetLightingSceneTracking()
            connectedSessionID = nil
            state = .disconnected
            protocolVersion = nil
            layerCount = nil
            lightingChannel = nil
            keyLightingChannel = nil
            return
        }
        switch session.phase {
        case .ready:
            guard connectedSessionID != session.id else { return }
            connectedSessionID = session.id
            state = .connected(name: session.isDemo ? "Micro Pad (demo)" : session.info.productName)
            protocolVersion = session.protocolVersion
            layerCount = session.layerCount
            let channels = Set(session.lightingPages.flatMap(\.sections).flatMap(\.controls).map(\.channel))
            lightingChannel = session.protocolVersion < 0x000B ? 0 : channels.contains(2) ? 2 : channels.contains(3) ? 3 : nil
            keyLightingChannel = lightingChannel == 2 && channels.contains(3) ? 3 : nil
            resetLightingSceneTracking()
            hidLogger.info("Creator Micro ready: protocol \(session.protocolVersion), \(session.layerCount) layers")
            if let catalog = session.catalog {
                onKeyboardActions?(KeyboardActionCatalog.actions(from: catalog))
            }
            onProtocolReady?()
            onLayoutReadStarted?()
            onLayoutRead?(Self.layout(from: session))
        case .loading:
            connectedSessionID = nil
            state = .connected(name: session.info.productName)
        case .needsDefinition(let message), .failed(let message):
            connectedSessionID = nil
            state = .unavailable(message: message)
        }
    }

    /// The keymap the session already read, in MicroMap's `[layer: [slotID: keycode]]` shape.
    private static func layout(from session: KeyboardSession) -> [Int: [String: UInt16]] {
        guard let keymap = session.keymap else { return [:] }
        var values: [Int: [String: UInt16]] = [:]
        for layer in 0..<min(keymap.layers, ControllerSpecialSlot.layerRange.count) {
            for slot in ControllerSlot.all {
                switch slot.kind {
                case .key, .encoderPress:
                    guard let row = slot.row, let column = slot.column, keymap.contains(layer: layer, row: row, col: column) else { continue }
                    values[layer, default: [:]][slot.id] = keymap[layer, row, column]
                case .encoderLeft, .encoderRight:
                    guard let encoders = session.encoders, let index = slot.encoderIndex, let clockwise = slot.clockwise,
                          index < encoders.encoders, layer < encoders.layers else { continue }
                    values[layer, default: [:]][slot.id] = encoders[layer, index, clockwise]
                }
            }
        }
        return values
    }

    // MARK: Keymap writes

    func write(action: FigmaAction, to slot: ControllerSlot, layer: Int) -> Bool {
        let layout = KeyboardLayoutResolver.resolve(KeyboardLayoutPreference.current)
        guard let keycode = QMKKeycodeEncoder.encode(action, layout: layout) else {
            lastError = "Unsupported shortcut: \(action.title)"
            return false
        }
        return write(keycode: keycode, to: slot, layer: layer)
    }

    func clear(slot: ControllerSlot, layer: Int) -> Bool {
        write(keycode: 0, to: slot, layer: layer)
    }

    /// Queues one write. Writes run one after another through the session, which backs the
    /// keyboard up before the first change and reads every value back.
    func write(keycode: UInt16, to slot: ControllerSlot, layer: Int) -> Bool {
        guard let session, session.phase == .ready, session.isEditable else {
            lastError = "Controller is not connected"
            return false
        }
        let selection: KeySelection
        switch slot.kind {
        case .key, .encoderPress:
            guard let row = slot.row, let column = slot.column else { return false }
            selection = .key(row: row, col: column)
        case .encoderLeft, .encoderRight:
            guard let encoder = slot.encoderIndex, let clockwise = slot.clockwise else { return false }
            selection = .encoder(index: encoder, clockwise: clockwise)
        }
        let previous = writeChain
        writeChain = Task { [weak self] in
            await previous?.value
            do {
                _ = try await session.writeKeycode(keycode, to: selection, layer: layer)
            } catch {
                self?.lastError = "Write failed: \(error.localizedDescription)"
                hidLogger.error("Keymap write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return true
    }

    // MARK: Lighting scenes

    func applyLightingScene(
        _ config: PerimeterLightingConfig,
        label: String,
        keyConfig: KeyLightingConfig,
        brightnessScale: Double = 1.0
    ) -> Bool {
        guard let session, session.phase == .ready, let protocolVersion else {
            lastError = "Waiting for the controller"
            return false
        }
        // Music mode owns the lights while it runs; MicroMap's scene comes back afterwards.
        if session.music?.isRunning == true { return true }
        guard let perimeterChannel = lightingChannel else {
            lastError = "This controller has no lighting channel"
            return false
        }

        let request = LightingSceneRequest(config: config, label: label, keyConfig: keyConfig, brightnessScale: brightnessScale,
                                           perimeterChannel: lightingChannel, keyChannel: keyLightingChannel)
        // Re-sending the scene the hardware already shows would restart its effect (a blink).
        if lightingWriteTask != nil {
            if request.matches(inFlightLightingScene) { return true }
        } else if request.matches(lastAppliedLightingScene) {
            return true
        }

        var zonedCommands = zoneCommands(for: config).map { (perimeterChannel, $0.scalingBrightness(by: brightnessScale)) }
        if let keyLightingChannel {
            zonedCommands += zoneCommands(for: keyConfig).map { (keyLightingChannel, $0.scalingBrightness(by: brightnessScale)) }
        }

        lightingWriteTask?.cancel()
        inFlightLightingScene = request
        lightingWriteTask = Task { [weak self] in
            for (channel, command) in zonedCommands {
                guard !Task.isCancelled else { return }
                if command.delayBeforeMilliseconds > 0 {
                    try? await Task.sleep(for: .milliseconds(command.delayBeforeMilliseconds))
                }
                do {
                    try await session.setLiveLighting(path: protocolVersion >= 0x000B ? [channel, command.value] : [command.value],
                                                      bytes: command.data)
                } catch {
                    guard let self, !Task.isCancelled else { return }
                    // A failed write leaves the scene partly applied; the next request re-sends in full.
                    lastError = "Lighting write failed: \(error.localizedDescription)"
                    lightingWriteTask = nil
                    inFlightLightingScene = nil
                    return
                }
            }
            guard let self, !Task.isCancelled else { return }
            lastAppliedLightingScene = request
            lightingWriteTask = nil
            inFlightLightingScene = nil
        }
        hidLogger.info("Sent lighting scene \(label, privacy: .public)")
        return true
    }

    /// Forget what the hardware shows, so the next scene is sent in full (after music mode, a
    /// reconnect, or a manual lighting change).
    func resetLightingSceneTracking() {
        lightingWriteTask?.cancel()
        lightingWriteTask = nil
        inFlightLightingScene = nil
        lastAppliedLightingScene = nil
    }

    // MicroMap's command order: color, brightness and speed while the old effect runs, then the
    // effect switch as the single visible change. RGB Light ignores color and brightness while
    // disabled, so both repeat after the switch. Rainbow effects need saturation written first.
    private func zoneCommands<Preset>(for config: LightingZoneConfig<Preset>) -> [LightingCommand] {
        guard !config.preset.isOff else {
            return [
                .init(value: 2, data: [0], delayBeforeMilliseconds: interCommandDelayMilliseconds),
                .init(value: 1, data: [0], delayBeforeMilliseconds: interCommandDelayMilliseconds),
            ]
        }
        return [
            .init(value: 4, data: [config.hueByte, config.saturationByte], delayBeforeMilliseconds: interCommandDelayMilliseconds),
            .init(value: 1, data: [config.brightnessByte], delayBeforeMilliseconds: interCommandDelayMilliseconds),
            .init(value: 3, data: [config.speedByte], delayBeforeMilliseconds: interCommandDelayMilliseconds),
            .init(value: 2, data: [config.modeByte], delayBeforeMilliseconds: interCommandDelayMilliseconds),
            .init(value: 4, data: [config.hueByte, config.saturationByte], delayBeforeMilliseconds: interCommandDelayMilliseconds),
            .init(value: 1, data: [config.brightnessByte], delayBeforeMilliseconds: interCommandDelayMilliseconds),
        ]
    }
}

private struct LightingCommand {
    let value: UInt8
    let data: [UInt8]
    let delayBeforeMilliseconds: Int

    init(value: UInt8, data: [UInt8], delayBeforeMilliseconds: Int = 0) {
        self.value = value
        self.data = data
        self.delayBeforeMilliseconds = delayBeforeMilliseconds
    }

    // Value 1 is the VIA brightness command; other values pass through unchanged.
    func scalingBrightness(by scale: Double) -> LightingCommand {
        guard value == 1, let base = data.first else { return self }
        let scaled = UInt8(min(255, max(0, (Double(base) * scale).rounded())))
        return LightingCommand(value: value, data: [scaled], delayBeforeMilliseconds: delayBeforeMilliseconds)
    }
}
