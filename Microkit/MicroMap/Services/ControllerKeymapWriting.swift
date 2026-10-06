import Foundation

/// Keymap write operations `AppStore` performs against the controller.
/// `HIDDeviceService` is the production implementation; tests substitute a
/// recorder to verify the apply flow without hardware.
@MainActor
protocol ControllerKeymapWriting: AnyObject {
    var canWriteKeymap: Bool { get }
    func write(action: FigmaAction, to slot: ControllerSlot, layer: Int) -> Bool
    func clear(slot: ControllerSlot, layer: Int) -> Bool
}

extension HIDDeviceService: ControllerKeymapWriting {
    var canWriteKeymap: Bool {
        if case .connected = state { return true }
        return false
    }
}
