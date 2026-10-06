import SwiftUI

/// Rounded outline of one or two rectangles (stepped keys), unioned into one shape.
struct KeycapShape: Shape {
    let rects: [CGRect]
    var insets = EdgeInsets()
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let paths = rects.map { r in
            let inner = CGRect(x: r.minX + insets.leading, y: r.minY + insets.top,
                               width: max(r.width - insets.leading - insets.trailing, 1),
                               height: max(r.height - insets.top - insets.bottom, 1))
            return Path(roundedRect: inner, cornerRadius: cornerRadius, style: .continuous)
        }
        guard var result = paths.first else { return Path() }
        for path in paths.dropFirst() {
            result = result.union(path)
        }
        return result
    }
}
