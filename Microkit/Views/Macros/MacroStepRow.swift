import MicrokitCore
import SwiftUI

struct MacroStepRow: View {
    let session: KeyboardSession
    @Binding var step: MacroStepDraft

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
            Picker("Action", selection: $step.kind) {
                ForEach(MacroStepDraft.Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 130)
            switch step.kind {
            case .text:
                TextField("Text", text: $step.text, prompt: Text("Text to type"))
            case .tap, .down, .up:
                Picker("Key", selection: $step.keycode) {
                    ForEach(keyOptions) { option in
                        Text(option.legend.help).tag(UInt8(option.code))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 260)
                Spacer()
            case .delay:
                TextField("Milliseconds", value: $step.delay, format: .number)
                    .frame(width: 80)
                Text("ms")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }

    /// Macros can only send one-byte (basic) keycodes.
    private var keyOptions: [KeycodeOption] {
        guard let catalog = session.catalog else { return [] }
        var seen = Set<UInt16>()
        return catalog.categories.filter { ["basic", "modifiers", "media"].contains($0.id) }
            .flatMap { $0.sections.flatMap(\.options) }
            .filter { $0.code > 1 && $0.code <= 0xFF && seen.insert($0.code).inserted }
    }
}
