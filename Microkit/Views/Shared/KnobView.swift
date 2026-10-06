import MicrokitCore
import SwiftUI

/// A rotary encoder: a round knob showing its press action, with turn arrows.
struct KnobView: View {
    let size: CGSize
    let unit: CGFloat
    let pressLegend: KeyLegend
    var isSelected = false
    var highlight: Color?

    var body: some View {
        let diameter = min(size.width, size.height) - unit * Theme.Keyboard.gapFraction
        ZStack {
            Circle()
                .fill(Theme.Keycap.modSkirt)
                .shadow(color: .black.opacity(0.25), radius: unit * 0.04, y: unit * 0.02)
            Circle()
                .strokeBorder(Theme.Keycap.legend.opacity(0.18), style: StrokeStyle(lineWidth: unit * 0.035, dash: [unit * 0.02, unit * 0.045]))
                .padding(unit * 0.03)
            Circle()
                .fill(highlight.map { AnyShapeStyle($0.opacity(0.6)) } ?? AnyShapeStyle(Theme.Keycap.mod))
                .padding(unit * 0.12)
            KeyLegendView(legend: pressLegend, unit: unit * 0.85)
                .frame(width: diameter * 0.62, height: diameter * 0.5)
            if isSelected {
                Circle().stroke(Color.accentColor, lineWidth: Theme.Keyboard.selectionLineWidth)
            }
        }
        .frame(width: diameter, height: diameter)
        .frame(width: size.width, height: size.height)
    }
}
