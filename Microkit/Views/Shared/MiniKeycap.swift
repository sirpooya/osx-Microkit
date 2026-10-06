import MicrokitCore
import SwiftUI

/// A small square keycap for pickers and the selection bar.
struct MiniKeycap: View {
    let legend: KeyLegend
    let size: CGFloat
    var style = KeycapStyle.alpha
    var isHighlighted = false

    var body: some View {
        KeycapView(rects: [CGRect(x: 0, y: 0, width: size, height: size)], unit: size, legend: legend, style: style, isSelected: isHighlighted)
            .frame(width: size, height: size)
    }
}
