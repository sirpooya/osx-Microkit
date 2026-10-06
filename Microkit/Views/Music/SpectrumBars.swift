import SwiftUI

struct SpectrumBars: View {
    let bands: [Float]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let count = max(bands.count, 24)
            let gap: CGFloat = 4
            let width = (size.width - gap * CGFloat(count - 1)) / CGFloat(count)
            for index in 0..<count {
                let value = index < bands.count ? CGFloat(bands[index]) : 0
                let height = max(4, value * size.height)
                let rect = CGRect(x: CGFloat(index) * (width + gap), y: size.height - height, width: width, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: min(width / 2, 4)),
                             with: .linearGradient(Gradient(colors: [color, .white]),
                                                   startPoint: CGPoint(x: rect.midX, y: size.height),
                                                   endPoint: CGPoint(x: rect.midX, y: size.height - size.height)))
            }
        }
    }
}
