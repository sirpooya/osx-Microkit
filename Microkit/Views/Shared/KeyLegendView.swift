import MicrokitCore
import SwiftUI

/// The text or symbol printed on a keycap, sized from the key unit.
struct KeyLegendView: View {
    let legend: KeyLegend
    let unit: CGFloat
    var color: Color = Theme.Keycap.legend

    var body: some View {
        VStack(spacing: unit * 0.02) {
            if let symbol = legend.symbol {
                Image(systemName: symbol)
                    .font(.system(size: unit * 0.28, weight: .medium))
            } else if !legend.primary.isEmpty {
                Text(legend.primary)
                    .font(.system(size: primarySize, weight: .medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.45)
                    .multilineTextAlignment(.center)
            }
            if let secondary {
                Text(secondary)
                    .font(.system(size: unit * 0.13))
                    .foregroundStyle(color.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .foregroundStyle(legend.kind == .transparent ? color.opacity(0.35) : color)
        .padding(.horizontal, unit * 0.06)
    }

    private var secondary: String? {
        if let secondary = legend.secondary { return secondary }
        return legend.symbol == nil ? nil : legend.primary
    }

    private var primarySize: CGFloat {
        switch legend.primary.count {
        case 0...2: unit * 0.30
        case 3...5: unit * 0.21
        default: unit * 0.17
        }
    }
}
