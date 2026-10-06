import Carbon
import Foundation
import OSLog

/// The user-configurable global "Open Figma" shortcut. The same chord is
/// registered as a system-wide Carbon hotkey and written to the Figma button
/// (K11) on every controller layer, so pressing the physical key and the
/// keyboard chord always agree.
struct GlobalShortcut: Codable, Equatable {
    let chord: KeyChord
    /// macOS virtual key code captured while recording. Carbon registration
    /// needs the layout-independent key position, which cannot be recovered
    /// reliably from the chord's display string.
    let macKeyCode: UInt32

    static let `default` = GlobalShortcut(
        chord: KeyChord(modifiers: [.control, .option, .command], key: "F"),
        macKeyCode: UInt32(kVK_ANSI_F)
    )

    private static let persistenceKey = "microMap.globalShortcut.v1"

    /// A usable global hotkey needs at least one modifier — a bare key would
    /// swallow normal typing system-wide — and must encode to a QMK keycode
    /// so the hardware Figma button can mirror it.
    var isValid: Bool {
        !chord.modifiers.isEmpty && QMKKeycodeEncoder.encode(chord) != nil
    }

    var carbonModifiers: UInt32 {
        chord.modifiers.reduce(0) { partial, modifier in
            let flag = switch modifier {
            case .control: controlKey
            case .option: optionKey
            case .shift: shiftKey
            case .command: cmdKey
            }
            return partial | UInt32(flag)
        }
    }

    static var stored: GlobalShortcut {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return .default }
        do {
            let decoded = try JSONDecoder().decode(GlobalShortcut.self, from: data)
            guard decoded.isValid else {
                persistenceLogger.error("Stored global shortcut is no longer valid; using the default")
                return .default
            }
            return decoded
        } catch {
            persistenceLogger.error("Dropping corrupted global shortcut; using the default: \(error, privacy: .public)")
            return .default
        }
    }

    func store() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    }
}
