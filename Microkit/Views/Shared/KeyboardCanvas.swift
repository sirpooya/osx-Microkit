import MicrokitCore
import SwiftUI

/// Lays out keys from a definition at `unit` points per key, rotation included.
/// `keyView` draws one key into its bounding box; geometry comes from `KeyGeometry`.
struct KeyboardCanvas<KeyContent: View>: View {
    let keys: [LayoutKey]
    let canvasSize: CGSize
    let unit: CGFloat
    @ViewBuilder let keyView: (LayoutKey, KeyGeometry) -> KeyContent

    var body: some View {
        let size = CGSize(width: canvasSize.width * unit, height: canvasSize.height * unit)
        ZStack(alignment: .topLeading) {
            ForEach(keys, id: \.self) { key in
                let geometry = KeyGeometry(key: key, unit: unit)
                keyView(key, geometry)
                    .frame(width: geometry.frame.width, height: geometry.frame.height)
                    .position(x: geometry.frame.midX, y: geometry.frame.midY)
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(geometry.rotation, anchor: UnitPoint(x: geometry.origin.x / max(size.width, 1),
                                                                         y: geometry.origin.y / max(size.height, 1)))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
