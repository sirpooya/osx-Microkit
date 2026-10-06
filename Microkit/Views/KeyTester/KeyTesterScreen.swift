import MicrokitCore
import SwiftUI

/// Press keys on the keyboard and watch them light up. Reads the switch matrix over raw HID,
/// so it works no matter what the keys are mapped to.
struct KeyTesterScreen: View {
    let session: KeyboardSession
    @State private var pressed: Set<[Int]> = []
    @State private var tested: Set<[Int]> = []
    @State private var error: String?
    @State private var sawAnyPress = false

    var body: some View {
        GeometryReader { proxy in
            let keys = session.visibleKeys
            let canvas = KeyGeometry.canvasSize(keys: keys, layoutWidth: session.definition?.layouts.width ?? 1,
                                                layoutHeight: session.definition?.layouts.height ?? 1)
            let unit = min(Theme.Keyboard.maxUnit * 1.2, (proxy.size.width - 80) / max(canvas.width, 1), (proxy.size.height - 220) / max(canvas.height, 1))
            VStack(spacing: 20) {
                Text(session.isDemo ? "Demo keyboard: click a key here to press it." : "Press keys on your keyboard.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                KeyboardCanvas(keys: keys, canvasSize: canvas, unit: max(unit, Theme.Keyboard.minUnit)) { key, geometry in
                    tile(key: key, geometry: geometry, unit: max(unit, Theme.Keyboard.minUnit))
                }
                HStack(spacing: 16) {
                    Text("\(tested.count) of \(keys.count) keys tested")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button("Reset", action: reset)
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else if !sawAnyPress && !session.isDemo {
                    Text("Nothing lighting up? Recent QMK firmware hides key presses from VIA tools unless it is built with VIA_INSECURE.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(poll)
    }

    @ViewBuilder
    private func tile(key: LayoutKey, geometry: KeyGeometry, unit: CGFloat) -> some View {
        let id = [key.row, key.col]
        let highlight: Color? = pressed.contains(id) ? .accentColor : tested.contains(id) ? Theme.Keycap.tested : nil
        let legend = session.legend(for: session.keymap.map { $0.contains(layer: 0, row: key.row, col: key.col) ? $0[0, key.row, key.col] : 0 } ?? 0)
        Group {
            if key.isEncoder {
                KnobView(size: geometry.frame.size, unit: unit, pressLegend: legend, highlight: highlight)
            } else {
                KeycapView(rects: geometry.rects, unit: unit, legend: legend, style: KeycapStyle(colorName: key.color), highlight: highlight)
            }
        }
        .onTapGesture { pressDemoKey(row: key.row, col: key.col) }
    }

    /// The demo board has no switches: a click presses the key for a moment.
    private func pressDemoKey(row: Int, col: Int) {
        guard let demo = session.demoKeyboard else { return }
        Task {
            await demo.press(row: row, col: col)
            try? await Task.sleep(for: .milliseconds(180))
            await demo.release(row: row, col: col)
        }
    }

    private func reset() {
        tested.removeAll()
    }

    @Sendable
    private func poll() async {
        while !Task.isCancelled {
            do {
                let state = try await session.matrixState()
                var now = Set<[Int]>()
                for (row, columns) in state.enumerated() {
                    for (col, isDown) in columns.enumerated() where isDown {
                        now.insert([row, col])
                    }
                }
                if now != pressed { pressed = now }
                if !now.isEmpty {
                    sawAnyPress = true
                    tested.formUnion(now)
                }
                error = nil
            } catch is CancellationError {
                return
            } catch {
                self.error = error.localizedDescription
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }
}
