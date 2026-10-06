import AppKit
import MicrokitCore
import SwiftUI

/// One custom-menu control. Local state drives the control; changes stream to the keyboard.
struct MenuControlRow: View {
    let session: KeyboardSession
    let control: MenuControl
    @State private var number: Double = 0
    @State private var isOn = false
    /// Sliders only write while the user drags them, never because SwiftUI adjusted a value.
    @State private var isDragging = false
    @State private var color = Color.white
    /// The color as read from the keyboard. Converting it back can round the hue by one step,
    /// so an unchanged color must never be sent: opening this screen alone writes nothing.
    @State private var loadedColor: Color?

    var body: some View {
        Group {
            switch control.kind {
            case .range(let min, let max):
                LabeledContent(control.label) {
                    HStack {
                        Slider(value: $number, in: Double(min)...Double(Swift.max(max, min + 1))) { editing in
                            isDragging = editing
                            if !editing { sendNumber() }
                        }
                        Text("\(Int(number.rounded()))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    .frame(maxWidth: 320)
                }
            case .dropdown(let choices):
                Picker(control.label, selection: $number) {
                    ForEach(choices) { choice in
                        Text(choice.label).tag(Double(choice.value))
                    }
                }
            case .toggle(let off, let on):
                Toggle(control.label, isOn: $isOn)
                    .onChange(of: isOn) {
                        if (Int(number) == on) != isOn { number = Double(isOn ? on : off) }
                    }
            case .color:
                ColorPicker(control.label, selection: $color, supportsOpacity: false)
            case .unsupported(let type):
                LabeledContent(control.label, value: "Not supported yet (\(type))")
            }
        }
        .onAppear(perform: load)
        .onChange(of: number) { sendNumberIfAllowed() }
        .onChange(of: color) { sendColor() }
    }

    private func load() {
        let bytes = session.lightingValue(control)
        switch control.kind {
        case .color:
            color = Color(hue: Double(bytes.first ?? 0) / 255, saturation: Double(bytes.count > 1 ? bytes[1] : 0) / 255, brightness: 1)
            loadedColor = color
        default:
            number = Double(control.byteCount == 2 && bytes.count > 1 ? Int(bytes[0]) << 8 | Int(bytes[1]) : Int(bytes.first ?? 0))
            if case .toggle(_, let on) = control.kind { isOn = Int(number) == on }
        }
    }

    private func sendNumberIfAllowed() {
        if case .range = control.kind, !isDragging { return }
        sendNumber()
    }

    private func sendNumber() {
        let value = Int(number.rounded())
        let bytes: [UInt8] = control.byteCount == 2 ? [UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)] : [UInt8(clamping: value)]
        guard bytes != session.lightingValue(control) else { return }
        session.setLighting(control, bytes: bytes)
    }

    private func sendColor() {
        guard color != loadedColor else { return }
        loadedColor = nil
        guard let hsb = NSColor(color).usingColorSpace(.deviceRGB) else { return }
        let bytes = [UInt8((hsb.hueComponent * 255).rounded()), UInt8((hsb.saturationComponent * 255).rounded())]
        guard bytes != session.lightingValue(control) else { return }
        session.setLighting(control, bytes: bytes)
    }
}
