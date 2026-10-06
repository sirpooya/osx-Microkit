import Observation

@MainActor
@Observable
final class ControllerLightingService {
    private(set) var appliedState: ControllerLightingState = .off
    private(set) var lastError: String?

    var configuration: LightingConfiguration = .default

    private let device: HIDDeviceService

    init(device: HIDDeviceService) {
        self.device = device
    }

    func apply(
        _ state: ControllerLightingState,
        keyState: CreatorMicroKeyLightingScene = .off,
        brightnessScale: Double = 1.0
    ) {
        let keys = keyConfig(for: keyState)
        switch state {
        case .off:
            send(.off, label: "off", state: state, keys: keys, brightnessScale: brightnessScale)
        case .ambientBreathe:
            send(configuration.outsideFigma, label: "ambient", state: state, keys: keys, brightnessScale: brightnessScale)
        case .figmaActive:
            send(configuration.inFigma, label: "figmaActive", state: state, keys: keys, brightnessScale: brightnessScale)
        }
    }

    /// Pushes arbitrary zone configurations to the hardware without changing
    /// the tracked state, so the configurator can show live adjustments.
    func preview(
        perimeter: PerimeterLightingConfig,
        keys: KeyLightingConfig,
        brightnessScale: Double = 1.0
    ) {
        if !device.applyLightingScene(perimeter, label: "preview", keyConfig: keys, brightnessScale: brightnessScale) {
            lastError = device.lastError
        }
    }

    func perimeterConfig(for state: ControllerLightingState) -> PerimeterLightingConfig {
        switch state {
        case .off: .off
        case .ambientBreathe: configuration.outsideFigma
        case .figmaActive: configuration.inFigma
        }
    }

    func keyConfig(for scene: CreatorMicroKeyLightingScene) -> KeyLightingConfig {
        switch scene {
        case .off: .off
        case .inFigma: configuration.keysInFigma
        }
    }

    private func send(
        _ config: PerimeterLightingConfig,
        label: String,
        state: ControllerLightingState,
        keys: KeyLightingConfig,
        brightnessScale: Double
    ) {
        if device.applyLightingScene(config, label: label, keyConfig: keys, brightnessScale: brightnessScale) {
            appliedState = state
            lastError = nil
        } else {
            lastError = device.lastError
        }
    }
}

enum CreatorMicroKeyLightingScene: Equatable, Sendable {
    case off
    case inFigma
}
