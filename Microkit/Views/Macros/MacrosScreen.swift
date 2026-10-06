import MicrokitCore
import SwiftUI

/// Edit the keyboard's dynamic macros. Changes are drafted, then saved together.
struct MacrosScreen: View {
    let session: KeyboardSession
    @State private var drafts: [[MacroStepDraft]] = []
    @State private var selectedMacro: Int? = 0
    @State private var isSaving = false

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $selectedMacro) {
                ForEach(drafts.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("M\(index)").font(.headline)
                        Text(summary(drafts[index]))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(index)
                }
            }
            .frame(width: 220)

            Divider()

            VStack(spacing: 0) {
                if let selectedMacro, selectedMacro < drafts.count {
                    MacroEditor(session: session, macroIndex: selectedMacro, steps: $drafts[selectedMacro])
                } else {
                    ContentUnavailableView("Select a macro", systemImage: "text.append")
                }
                Divider()
                footer
            }
        }
        .onAppear(perform: revert)
        .onChange(of: session.macros) { revert() }
    }

    private var footer: some View {
        let used = session.macroByteCount(currentMacros)
        return HStack(spacing: 12) {
            ProgressView(value: Double(min(used, session.macroBufferSize)), total: Double(max(session.macroBufferSize, 1)))
                .frame(width: 160)
                .tint(used > session.macroBufferSize ? .red : .accentColor)
            Text("\(used) of \(session.macroBufferSize) bytes")
                .monospacedDigit()
                .foregroundStyle(used > session.macroBufferSize ? .red : .secondary)
            Spacer()
            Text("Assign a macro to a key from Keymap > Macros.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Revert", action: revert)
                .disabled(isDirty == false || isSaving)
            Button("Save to Keyboard", action: save)
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(isDirty == false || isSaving || used > session.macroBufferSize || session.isEditable == false)
        }
        .padding(12)
    }

    private var currentMacros: [[MacroStep]] {
        drafts.map { $0.map(\.step) }
    }

    private var isDirty: Bool {
        currentMacros != session.macros
    }

    private func summary(_ steps: [MacroStepDraft]) -> String {
        guard !steps.isEmpty else { return "Empty" }
        return steps.map { draft in
            switch draft.kind {
            case .text: "\u{201C}\(draft.text)\u{201D}"
            case .delay: "\(draft.delay) ms"
            default: session.legend(for: UInt16(draft.keycode)).primary
            }
        }.joined(separator: " ")
    }

    private func revert() {
        drafts = session.macros.map { $0.map(MacroStepDraft.init(step:)) }
        if let selectedMacro, selectedMacro >= drafts.count { self.selectedMacro = drafts.isEmpty ? nil : 0 }
    }

    private func save() {
        isSaving = true
        Task {
            _ = await session.saveMacros(currentMacros)
            isSaving = false
        }
    }
}
