import MicrokitCore
import SwiftUI

/// One keycap: a darker skirt, a lighter dished top, the legend, and selection or test state.
struct KeycapView: View {
    let rects: [CGRect]
    let unit: CGFloat
    let legend: KeyLegend
    let style: KeycapStyle
    var isSelected = false
    /// Key tester state: pressed now, or pressed at some point.
    var highlight: Color?

    var body: some View {
        let gap = unit * Theme.Keyboard.gapFraction / 2
        let corner = unit * Theme.Keyboard.cornerFraction
        let side = gap + unit * Theme.Keyboard.dishInsetFraction
        let dish = EdgeInsets(top: gap + unit * Theme.Keyboard.dishTopFraction, leading: side,
                              bottom: gap + unit * Theme.Keyboard.dishBottomFraction, trailing: side)
        ZStack(alignment: .topLeading) {
            KeycapShape(rects: rects, insets: EdgeInsets(top: gap, leading: gap, bottom: gap, trailing: gap), cornerRadius: corner)
                .fill(style.skirt)
                .shadow(color: .black.opacity(0.22), radius: unit * 0.03, y: unit * 0.02)
            KeycapShape(rects: rects, insets: dish, cornerRadius: corner * 0.8)
                .fill(style.top)
            if let highlight {
                KeycapShape(rects: rects, insets: dish, cornerRadius: corner * 0.8)
                    .fill(highlight.opacity(0.55))
            }
            KeyLegendView(legend: legend, unit: unit, color: style.legend)
                .frame(width: legendRect(dish).width, height: legendRect(dish).height)
                .offset(x: legendRect(dish).minX, y: legendRect(dish).minY)
            if isSelected {
                KeycapShape(rects: rects, insets: EdgeInsets(top: gap, leading: gap, bottom: gap, trailing: gap), cornerRadius: corner)
                    .stroke(Color.accentColor, lineWidth: Theme.Keyboard.selectionLineWidth)
            }
        }
    }

    private func legendRect(_ dish: EdgeInsets) -> CGRect {
        let main = rects.first ?? .zero
        return CGRect(x: main.minX + dish.leading, y: main.minY + dish.top,
                      width: max(main.width - dish.leading - dish.trailing, 1),
                      height: max(main.height - dish.top - dish.bottom, 1))
    }
}
