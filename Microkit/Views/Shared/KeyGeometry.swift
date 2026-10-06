import CoreGraphics
import MicrokitCore
import SwiftUI

/// Where a layout key sits on the canvas, in points.
struct KeyGeometry {
    /// Bounding box of the key's rectangles, unrotated, in canvas points.
    let frame: CGRect
    /// The key's rectangles (two for stepped keys like ISO Enter), relative to `frame`.
    let rects: [CGRect]
    let rotation: Angle
    /// Rotation origin in canvas points.
    let origin: CGPoint

    init(key: LayoutKey, unit: CGFloat) {
        var unitRects = [CGRect(x: key.x, y: key.y, width: key.w, height: key.h)]
        if let w2 = key.w2, let h2 = key.h2, w2 > 0, h2 > 0 {
            unitRects.append(CGRect(x: key.x + (key.x2 ?? 0), y: key.y + (key.y2 ?? 0), width: w2, height: h2))
        }
        let bounds = unitRects.dropFirst().reduce(unitRects[0]) { $0.union($1) }
        frame = CGRect(x: bounds.minX * unit, y: bounds.minY * unit, width: bounds.width * unit, height: bounds.height * unit)
        rects = unitRects.map {
            CGRect(x: ($0.minX - bounds.minX) * unit, y: ($0.minY - bounds.minY) * unit, width: $0.width * unit, height: $0.height * unit)
        }
        rotation = .degrees(key.r)
        origin = CGPoint(x: key.rx * unit, y: key.ry * unit)
    }

    /// The canvas size needed to show every key, rotation included.
    static func canvasSize(keys: [LayoutKey], layoutWidth: Double, layoutHeight: Double) -> CGSize {
        var maxX = layoutWidth
        var maxY = layoutHeight
        for key in keys {
            let geometry = KeyGeometry(key: key, unit: 1)
            let corners = [
                CGPoint(x: geometry.frame.minX, y: geometry.frame.minY),
                CGPoint(x: geometry.frame.maxX, y: geometry.frame.minY),
                CGPoint(x: geometry.frame.minX, y: geometry.frame.maxY),
                CGPoint(x: geometry.frame.maxX, y: geometry.frame.maxY),
            ].map { geometry.rotated($0) }
            maxX = max(maxX, corners.map(\.x).max() ?? 0)
            maxY = max(maxY, corners.map(\.y).max() ?? 0)
        }
        return CGSize(width: maxX, height: maxY)
    }

    func rotated(_ point: CGPoint) -> CGPoint {
        guard rotation.radians != 0 else { return point }
        let cosR = cos(rotation.radians), sinR = sin(rotation.radians)
        let dx = point.x - origin.x, dy = point.y - origin.y
        return CGPoint(x: origin.x + dx * cosR - dy * sinR, y: origin.y + dx * sinR + dy * cosR)
    }
}
