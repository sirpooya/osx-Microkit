import MicrokitCore
import SwiftUI

/// VIA's Configure view: the keyboard on top, the keycode picker below.
struct KeymapScreen: View {
    @Bindable var session: KeyboardSession

    var body: some View {
        GeometryReader { proxy in
            let canvas = KeyGeometry.canvasSize(keys: session.visibleKeys,
                                                layoutWidth: session.definition?.layouts.width ?? 1,
                                                layoutHeight: session.definition?.layouts.height ?? 1)
            let unit = unitSize(canvas: canvas, available: proxy.size)
            VStack(spacing: 0) {
                KeymapHeader(session: session)
                KeymapKeyboard(session: session, canvasSize: canvas, unit: unit)
                    .frame(height: canvas.height * unit + Theme.Keyboard.canvasPadding * 2)
                    .frame(maxWidth: .infinity)
                    .background(.background.secondary)
                Divider()
                SelectionBar(session: session)
                Divider()
                if let catalog = session.catalog {
                    KeycodePickerView(session: session, catalog: catalog)
                }
            }
        }
    }

    private func unitSize(canvas: CGSize, available: CGSize) -> CGFloat {
        let padding = Theme.Keyboard.canvasPadding * 2
        let byWidth = (available.width - padding) / max(canvas.width, 1)
        let byHeight = (available.height * Theme.Keyboard.maxHeightShare - padding) / max(canvas.height, 1)
        return min(Theme.Keyboard.maxUnit, max(Theme.Keyboard.minUnit, min(byWidth, byHeight)))
    }
}
