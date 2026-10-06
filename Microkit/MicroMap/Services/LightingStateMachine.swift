import Observation

@MainActor
@Observable
final class LightingStateMachine {
    private(set) var state: ControllerLightingState = .off

    private var layer = 0
    private var isFigmaActive = false

    @discardableResult
    func update(
        layer: Int? = nil,
        isFigmaActive: Bool? = nil
    ) -> ControllerLightingState {
        if let layer { self.layer = layer }
        if let isFigmaActive { self.isFigmaActive = isFigmaActive }

        state = self.isFigmaActive ? .figmaActive : .ambientBreathe
        return state
    }
}
