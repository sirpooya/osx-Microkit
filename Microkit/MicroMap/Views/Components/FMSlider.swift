import SwiftUI

/// iOS-style slider from the Figma Micro design: a tall capsule track with a
/// white round knob riding inside it, a midpoint detent dot, and a value chip
/// showing the current percentage. Replaces the native macOS `Slider`, whose
/// thin track and small knob don't match the mockups.
struct FMSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var showsPercentChip = true
    @State private var percentText = ""
    @FocusState private var isPercentFieldFocused: Bool

    private static let trackHeight: CGFloat = 20
    private static let thumbInset: CGFloat = 2

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return ((value - range.lowerBound) / span).clamped(to: 0...1)
    }

    var body: some View {
        HStack(spacing: 8) {
            track
            if showsPercentChip {
                percentChip
            }
        }
    }

    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let thumbRadius = (Self.trackHeight - Self.thumbInset * 2) / 2
            let travel = width - Self.thumbInset * 2 - thumbRadius * 2
            let thumbCenterX = Self.thumbInset + thumbRadius + travel * fraction

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(FMTheme.fieldFill)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(FMTheme.chipBorder, lineWidth: 1)
                    )

                // Filled portion up to the knob; hidden at the minimum so the
                // track reads fully neutral, as in the design.
                if fraction > 0.001 {
                    Capsule(style: .continuous)
                        .fill(FMTheme.accent)
                        .frame(width: thumbCenterX + thumbRadius + Self.thumbInset)
                        .clipShape(Capsule(style: .continuous))
                }

                // Midpoint detent dot, hidden while the knob passes over it.
                if abs(thumbCenterX - width / 2) > thumbRadius + 3 {
                    Circle()
                        .fill(fraction > 0.5 ? Color.white.opacity(0.85) : FMTheme.sliderDot)
                        .frame(width: 4, height: 4)
                        .position(x: width / 2, y: Self.trackHeight / 2)
                }

                Circle()
                    .fill(.white)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .shadow(color: .black.opacity(0.22), radius: 1.5, y: 0.5)
                    .position(x: thumbCenterX, y: Self.trackHeight / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let usable = max(travel, 1)
                        let position = gesture.location.x - Self.thumbInset - thumbRadius
                        let newFraction = (position / usable).clamped(to: 0...1)
                        value = range.lowerBound
                            + (range.upperBound - range.lowerBound) * newFraction
                    }
            )
        }
        .frame(height: Self.trackHeight)
        .accessibilityElement()
        .accessibilityValue(Text(percentLabel))
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }

    /// Formatted by hand: the design chip reads "30%", while locale-aware
    /// percent formatting would insert a space in some locales ("30 %").
    private var percentLabel: String {
        "\(Int((value * 100).rounded()))%"
    }

    /// Editable numeric chip: type a value 0–100 and commit with Return or by
    /// leaving the field. Values outside the slider's range are clamped.
    private var percentChip: some View {
        HStack(spacing: 1) {
            TextField("", text: $percentText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .frame(width: 22)
                .focused($isPercentFieldFocused)
                .onSubmit { commitPercentText() }
            Text("%")
                .foregroundStyle(FMTheme.textSecondary)
        }
        .font(FMTheme.caption)
        .monospacedDigit()
        .foregroundStyle(FMTheme.textPrimary)
        .padding(.horizontal, 6)
        .frame(height: Self.trackHeight + 2)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(FMTheme.controlSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(FMTheme.chipBorder, lineWidth: 1)
        )
        .onAppear { percentText = String(Int((value * 100).rounded())) }
        .onChange(of: value) { _, newValue in
            guard !isPercentFieldFocused else { return }
            percentText = String(Int((newValue * 100).rounded()))
        }
        .onChange(of: percentText) { _, newText in
            // Digits only, capped at three characters and a value of 100.
            var filtered = String(newText.filter(\.isNumber).prefix(3))
            if let number = Int(filtered), number > 100 { filtered = "100" }
            if filtered != newText { percentText = filtered }
        }
        .onChange(of: isPercentFieldFocused) { _, focused in
            guard !focused else { return }
            commitPercentText()
        }
    }

    private func commitPercentText() {
        guard let number = Int(percentText) else {
            percentText = String(Int((value * 100).rounded()))
            return
        }
        value = (Double(number) / 100).clamped(to: range)
        percentText = String(Int((value * 100).rounded()))
    }
}

private extension Double {
    func clamped(to limits: ClosedRange<Double>) -> Double {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
