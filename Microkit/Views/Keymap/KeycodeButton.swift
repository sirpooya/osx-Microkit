import MicrokitCore
import SwiftUI

/// A pickable keycode drawn as a small keycap. Clicking writes it to the selected key.
struct KeycodeButton: View {
    let session: KeyboardSession
    let option: KeycodeOption

    var body: some View {
        Button(action: assign) {
            MiniKeycap(legend: option.legend, size: Theme.Picker.cellSize, style: style, isHighlighted: isCurrent)
        }
        .buttonStyle(.plain)
        .help("\(option.legend.help)\n\(option.legend.qmkName)")
        .accessibilityLabel(option.legend.help)
    }

    private var isCurrent: Bool {
        session.selection.flatMap { session.keycode(for: $0) } == option.code
    }

    private var style: KeycapStyle {
        switch option.legend.kind {
        case .modifier, .layer, .special, .lighting, .media, .mouse: .mod
        default: .alpha
        }
    }

    private func assign() {
        Task { await session.assign(option.code) }
    }
}
