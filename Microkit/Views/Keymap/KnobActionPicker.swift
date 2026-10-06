import MicrokitCore
import SwiftUI

/// Switches the selection between a knob's press and its two turn directions.
struct KnobActionPicker: View {
    @Bindable var session: KeyboardSession
    let knob: Int
    @State private var action = KnobAction.press

    enum KnobAction: Hashable {
        case press, left, right
    }

    var body: some View {
        Picker("Knob action", selection: $action) {
            Label(label(.left), systemImage: "arrow.counterclockwise").tag(KnobAction.left)
            Label(label(.press), systemImage: "smallcircle.filled.circle").tag(KnobAction.press)
            Label(label(.right), systemImage: "arrow.clockwise").tag(KnobAction.right)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .onAppear(perform: syncFromSelection)
        .onChange(of: session.selection) { syncFromSelection() }
        .onChange(of: action) { applyAction() }
    }

    private func label(_ action: KnobAction) -> String {
        switch action {
        case .press:
            let key = session.visibleKeys.first { $0.ei == knob }
            return "Press: " + (key.map { session.legend(for: session.keycode(for: $0)).primary } ?? "")
        case .left:
            return "Left: " + (session.encoderCode(knob, clockwise: false).map { shortText($0) } ?? "")
        case .right:
            return "Right: " + (session.encoderCode(knob, clockwise: true).map { shortText($0) } ?? "")
        }
    }

    private func shortText(_ code: UInt16) -> String {
        let legend = session.legend(for: code)
        return legend.symbol == nil ? legend.primary : (legend.secondary ?? legend.primary)
    }

    private func syncFromSelection() {
        switch session.selection {
        case .encoder(_, let clockwise): action = clockwise ? .right : .left
        default: action = .press
        }
    }

    private func applyAction() {
        let target: KeySelection?
        switch action {
        case .press:
            target = session.visibleKeys.first { $0.ei == knob }.map { .key(row: $0.row, col: $0.col) }
        case .left:
            target = .encoder(index: knob, clockwise: false)
        case .right:
            target = .encoder(index: knob, clockwise: true)
        }
        if let target, target != session.selection {
            session.selection = target
        }
    }
}
