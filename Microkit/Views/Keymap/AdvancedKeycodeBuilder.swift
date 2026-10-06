import MicrokitCore
import SwiftUI

/// Builds keycodes that combine parts: modifiers plus a key, tap/hold keys, and raw hex.
struct AdvancedKeycodeBuilder: View {
    let session: KeyboardSession
    @State private var baseKey: UInt16 = 0x04
    @State private var control = false
    @State private var option = false
    @State private var shift = false
    @State private var command = true
    @State private var rightHand = false
    @State private var layer = 1
    @State private var rawText = ""

    var body: some View {
        let composer = KeycodeComposer(table: session.formatter.table)
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Parts") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Key", selection: $baseKey) {
                        ForEach(baseOptions) { option in
                            Text("\(option.legend.help)").tag(option.code)
                        }
                    }
                    .frame(maxWidth: 360)
                    HStack {
                        Text("Modifiers")
                        Toggle("⌃ Control", isOn: $control)
                        Toggle("⌥ Option", isOn: $option)
                        Toggle("⇧ Shift", isOn: $shift)
                        Toggle("⌘ Command", isOn: $command)
                        Toggle("Right-hand", isOn: $rightHand)
                            .help("Send the right-side modifiers instead of the left")
                    }
                    .toggleStyle(.checkbox)
                    Picker("Layer", selection: $layer) {
                        ForEach(0..<max(session.layerCount, 1), id: \.self) { Text("Layer \($0)").tag($0) }
                    }
                    .frame(maxWidth: 200)
                }
                .padding(6)
            }

            GroupBox("Assign") {
                VStack(alignment: .leading, spacing: 8) {
                    BuilderRow(session: session, title: "Shortcut: modifiers + key", code: composer.modified(baseKey, with: mods))
                    BuilderRow(session: session, title: "Tap for the key, hold for the modifiers", code: composer.modTap(baseKey, mods: mods))
                    BuilderRow(session: session, title: "Tap for the key, hold for layer \(layer)", code: composer.layerTap(baseKey, layer: layer))
                    BuilderRow(session: session, title: "Hold for layer \(layer) with the modifiers", code: composer.layerMod(layer: layer, mods: mods))
                }
                .padding(6)
            }

            GroupBox("Raw keycode") {
                HStack {
                    TextField("Hex", text: $rawText, prompt: Text("0x0029"))
                        .frame(width: 120)
                        .onSubmit(assignRaw)
                    if let code = rawCode {
                        MiniKeycap(legend: session.legend(for: code), size: 34)
                        Text(session.legend(for: code).qmkName)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Assign", action: assignRaw)
                        .disabled(rawCode == nil)
                }
                .padding(6)
            }
        }
    }

    private var mods: ModifierMask {
        var mask: ModifierMask = []
        if control { mask.insert(.control) }
        if option { mask.insert(.option) }
        if shift { mask.insert(.shift) }
        if command { mask.insert(.command) }
        if rightHand { mask.insert(.rightHand) }
        return mask
    }

    private var baseOptions: [KeycodeOption] {
        guard let catalog = session.catalog else { return [] }
        let basic = catalog.categories.filter { ["basic", "media", "modifiers"].contains($0.id) }
        return basic.flatMap { $0.sections.flatMap(\.options) }.filter { $0.code <= 0xFF && $0.code > 1 }
    }

    private var rawCode: UInt16? {
        let text = rawText.trimmingCharacters(in: .whitespaces).lowercased()
        let digits = text.hasPrefix("0x") ? String(text.dropFirst(2)) : text
        return digits.isEmpty ? nil : UInt16(digits, radix: 16)
    }

    private func assignRaw() {
        guard let rawCode else { return }
        Task { await session.assign(rawCode) }
    }
}
