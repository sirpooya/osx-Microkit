import MicrokitCore
import SwiftUI

/// The keyboard drawn with the selected layer's legends; clicking a key selects it.
struct KeymapKeyboard: View {
    let session: KeyboardSession
    let canvasSize: CGSize
    let unit: CGFloat

    var body: some View {
        KeyboardCanvas(keys: session.visibleKeys, canvasSize: canvasSize, unit: unit) { key, geometry in
            KeymapKeyView(session: session, key: key, geometry: geometry, unit: unit)
        }
        .padding(Theme.Keyboard.canvasPadding)
    }
}
