import SwiftUI

struct KeycapStrip: View {
    let chord: KeyChord
    var compact = false

    // Outlined keycaps per the design: border only, no fill.
    var body: some View {
        HStack(spacing: compact ? 2 : 5) {
            ForEach(Array(chord.tokens.enumerated()), id: \.offset) { _, token in
                Text(token)
                    .font(compact ? .caption2.monospaced().weight(.medium) : .callout.monospaced().weight(.semibold))
                    .foregroundStyle(FMTheme.textPrimary)
                    .frame(minWidth: compact ? 18 : 25, minHeight: compact ? 18 : 25)
                    .padding(.horizontal, compact ? 2 : 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: compact ? 4 : 6)
                            .stroke(FMTheme.keycapBorder, lineWidth: 1)
                    }
            }
        }
    }
}
