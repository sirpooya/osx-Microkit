import MicrokitCore
import SwiftUI

/// What is selected and what it does now. For a knob, also picks press, turn left or turn right.
struct SelectionBar: View {
    @Bindable var session: KeyboardSession

    var body: some View {
        HStack(spacing: 14) {
            if let selection = session.selection, let code = session.keycode(for: selection) {
                let legend = session.legend(for: code)
                MiniKeycap(legend: legend, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: selection))
                        .font(.headline)
                    Text("\(legend.help)  ·  \(legend.qmkName)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let knob = knobIndex(for: selection) {
                    KnobActionPicker(session: session, knob: knob)
                }
                Spacer()
                Button("Transparent", action: assignTransparent)
                    .help("Use whatever the layer below has (KC_TRNS)")
                Button("None", action: assignNone)
                    .help("Make the key do nothing (KC_NO)")
            } else {
                Image(systemName: "hand.point.up.left")
                    .foregroundStyle(.secondary)
                Text("Click a key or knob, then pick what it should do.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .disabled(session.isEditable == false && session.selection != nil)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
    }

    private func title(for selection: KeySelection) -> String {
        switch selection {
        case .key(let row, let col):
            let isKnob = session.layoutKey(for: selection)?.isEncoder == true
            return "Layer \(session.selectedLayer) · \(isKnob ? "Knob press" : "Key") (row \(row), column \(col))"
        case .encoder(let index, let clockwise):
            return "Layer \(session.selectedLayer) · Knob \(index + 1), turn \(clockwise ? "right" : "left")"
        }
    }

    private func knobIndex(for selection: KeySelection) -> Int? {
        switch selection {
        case .key: session.layoutKey(for: selection)?.ei
        case .encoder(let index, _): index
        }
    }

    private func assignTransparent() {
        Task { await session.assign(0x0001) }
    }

    private func assignNone() {
        Task { await session.assign(0x0000) }
    }
}
