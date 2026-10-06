import Foundation
import MicrokitCore

/// An editable macro step. Every kind keeps all fields so switching kinds loses nothing.
struct MacroStepDraft: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Identifiable {
        case text, tap, down, up, delay

        var id: String { rawValue }

        var title: String {
            switch self {
            case .text: "Type text"
            case .tap: "Tap key"
            case .down: "Hold key"
            case .up: "Release key"
            case .delay: "Wait"
            }
        }
    }

    let id = UUID()
    var kind: Kind
    var text = ""
    var keycode: UInt8 = 0x04
    var delay = 100

    init(kind: Kind) {
        self.kind = kind
    }

    init(step: MacroStep) {
        switch step {
        case .text(let text):
            kind = .text
            self.text = text
        case .tap(let code):
            kind = .tap
            keycode = code
        case .down(let code):
            kind = .down
            keycode = code
        case .up(let code):
            kind = .up
            keycode = code
        case .delay(let milliseconds):
            kind = .delay
            delay = milliseconds
        }
    }

    var step: MacroStep {
        switch kind {
        case .text: .text(text)
        case .tap: .tap(keycode)
        case .down: .down(keycode)
        case .up: .up(keycode)
        case .delay: .delay(delay)
        }
    }
}
