import MicrokitCore
import SwiftUI

/// One key or knob on the keymap canvas.
struct KeymapKeyView: View {
    let session: KeyboardSession
    let key: LayoutKey
    let geometry: KeyGeometry
    let unit: CGFloat

    var body: some View {
        let legend = session.legend(for: session.keycode(for: key))
        Group {
            if let encoder = key.ei {
                KnobView(size: geometry.frame.size, unit: unit, pressLegend: legend, isSelected: isSelected(encoder: encoder))
            } else {
                KeycapView(rects: geometry.rects, unit: unit, legend: legend, style: KeycapStyle(colorName: key.color), isSelected: isSelected(encoder: nil))
            }
        }
        .contentShape(KeycapShape(rects: geometry.rects, cornerRadius: unit * Theme.Keyboard.cornerFraction))
        .onTapGesture(perform: select)
        .help(help(legend))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(key.ei == nil ? "Key \(legend.help)" : "Knob, press: \(legend.help)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, select)
    }

    private func isSelected(encoder: Int?) -> Bool {
        switch session.selection {
        case .key(let row, let col): row == key.row && col == key.col
        case .encoder(let index, _): index == encoder
        case nil: false
        }
    }

    private func select() {
        session.select(key)
    }

    private func help(_ legend: KeyLegend) -> String {
        var text = "\(legend.help)\n\(legend.qmkName)"
        if let encoder = key.ei,
           let left = session.encoderCode(encoder, clockwise: false),
           let right = session.encoderCode(encoder, clockwise: true) {
            text += "\nTurn left: \(session.legend(for: left).help)\nTurn right: \(session.legend(for: right).help)"
        }
        return text
    }
}
