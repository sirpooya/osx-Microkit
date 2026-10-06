import Foundation
import MicrokitCore
import Observation

/// Music mode for one keyboard: listens to system audio and streams colors to its lights.
///
/// Only live `custom_set_value` commands are sent, never `custom_save`, so nothing is written
/// to the keyboard's memory. Start remembers the lighting it found; stop puts it back.
@MainActor
@Observable
final class MusicController {
    enum State: Equatable {
        case off
        case running
        case failed(String)
    }

    let targets: [MusicTarget]
    private(set) var state = State.off
    private(set) var features = AudioFeatures.silence
    private(set) var frame = MusicLightFrame(hue: 0, saturation: 255, brightness: 0)
    /// Seconds of continuous silence while running, for the permission hint.
    private(set) var silentFor: TimeInterval = 0

    var style: MusicStyle {
        didSet { mapper.style = style; defaults.set(style.rawValue, forKey: Keys.musicStyle) }
    }
    var sensitivity: Double {
        didSet { mapper.sensitivity = Float(sensitivity); defaults.set(sensitivity, forKey: Keys.musicSensitivity) }
    }
    var maxBrightness: Double {
        didSet { defaults.set(maxBrightness, forKey: Keys.musicMaxBrightness) }
    }
    /// Pulse color hue, 0...1.
    var hue: Double {
        didSet { mapper.baseHue = Float(hue); defaults.set(hue, forKey: Keys.musicHue) }
    }
    var disabledTargets: Set<String> {
        didSet { defaults.set(Array(disabledTargets), forKey: Keys.musicDisabledTargets) }
    }

    var isRunning: Bool { state == .running }
    var activeTargets: [MusicTarget] { targets.filter { !disabledTargets.contains($0.title) } }

    @ObservationIgnored private let client: VIAClient
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var mapper: MusicColorMapper
    @ObservationIgnored private var capture: AnyObject?
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    @ObservationIgnored private var originals: [[UInt8]: [UInt8]] = [:]
    @ObservationIgnored private var pendingFrame: MusicLightFrame?
    @ObservationIgnored private var lastSent: MusicLightFrame?
    @ObservationIgnored private var sendTask: Task<Void, Never>?
    @ObservationIgnored private var lastSoundTime = Date.now
    @ObservationIgnored private var sentTargets: [MusicTarget] = []

    init(client: VIAClient, targets: [MusicTarget]) {
        self.client = client
        self.targets = targets
        let style = MusicStyle(rawValue: defaults.string(forKey: Keys.musicStyle) ?? "") ?? .spectrum
        let sensitivity = defaults.object(forKey: Keys.musicSensitivity) as? Double ?? 1
        let hue = defaults.object(forKey: Keys.musicHue) as? Double ?? 0.75
        self.style = style
        self.sensitivity = sensitivity
        self.hue = hue
        maxBrightness = defaults.object(forKey: Keys.musicMaxBrightness) as? Double ?? 1
        disabledTargets = Set(defaults.stringArray(forKey: Keys.musicDisabledTargets) ?? [])
        mapper = MusicColorMapper(style: style, baseHue: Float(hue), sensitivity: Float(sensitivity))
    }

    // MARK: Start and stop

    func start() async {
        guard !isRunning else { return }
        guard #available(macOS 14.2, *) else {
            state = .failed("Music mode needs macOS 14.2 or later.")
            return
        }
        sentTargets = activeTargets
        guard !sentTargets.isEmpty else {
            state = .failed("Turn on at least one light below.")
            return
        }
        do {
            // Remember what the lights look like now, then switch them to one solid color.
            originals = [:]
            for target in sentTargets {
                for path in [target.effectPath, target.brightnessPath, target.colorPath].compactMap({ $0 }) {
                    let count = path == target.colorPath ? 2 : 1
                    originals[path] = try await client.customValue(path: path, count: count)
                }
                if let effect = target.effectPath {
                    try await client.setCustomValue(path: effect, [target.solidEffect])
                }
            }
            let capture = SystemAudioCapture()
            try capture.start()
            self.capture = capture
            state = .running
            lastSent = nil
            lastSoundTime = .now
            listenTask = Task { [weak self] in
                for await features in capture.features {
                    self?.receive(features)
                }
            }
        } catch {
            await restoreLighting()
            state = .failed(error.localizedDescription)
        }
    }

    func stop() async {
        guard isRunning else { return }
        state = .off
        listenTask?.cancel()
        listenTask = nil
        if #available(macOS 14.2, *) {
            (capture as? SystemAudioCapture)?.stop()
        }
        capture = nil
        pendingFrame = nil
        await sendTask?.value
        await restoreLighting()
        features = .silence
        silentFor = 0
    }

    /// The keyboard went away: drop everything without talking to it.
    func disconnect() {
        state = .off
        listenTask?.cancel()
        if #available(macOS 14.2, *) {
            (capture as? SystemAudioCapture)?.stop()
        }
        capture = nil
        pendingFrame = nil
    }

    private func restoreLighting() async {
        // Effect last, so the board does not flash the old color in the solid effect.
        for target in sentTargets {
            for path in [target.colorPath, target.brightnessPath, target.effectPath].compactMap({ $0 }) {
                if let bytes = originals[path] {
                    try? await client.setCustomValue(path: path, bytes)
                }
            }
        }
        originals = [:]
    }

    // MARK: Streaming

    private func receive(_ features: AudioFeatures) {
        guard isRunning else { return }
        self.features = features
        if features.level > 0 { lastSoundTime = .now }
        silentFor = Date.now.timeIntervalSince(lastSoundTime)

        var next = mapper.frame(for: features)
        next.brightness = UInt8((Double(next.brightness) * maxBrightness).rounded())
        frame = next
        guard next != lastSent else { return }
        pendingFrame = next
        if sendTask == nil {
            sendTask = Task { await sendLatest() }
        }
    }

    /// Sends only the newest frame; frames that arrive while a send is in flight replace each other.
    private func sendLatest() async {
        while let next = pendingFrame, isRunning {
            pendingFrame = nil
            do {
                for target in sentTargets {
                    try await client.setCustomValue(path: target.colorPath, [next.hue, next.saturation])
                    if let brightness = target.brightnessPath {
                        let scaled = UInt8(clamping: Int((Double(next.brightness) / 255 * Double(target.brightnessMax)).rounded()))
                        try await client.setCustomValue(path: brightness, [scaled])
                    }
                }
                lastSent = next
            } catch {
                sendTask = nil
                await stop()
                state = .failed("The keyboard stopped answering: \(error.localizedDescription)")
                return
            }
        }
        sendTask = nil
    }
}
