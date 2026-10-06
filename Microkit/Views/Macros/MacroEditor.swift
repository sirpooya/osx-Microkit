import MicrokitCore
import SwiftUI

/// The steps of one macro, in order.
struct MacroEditor: View {
    let session: KeyboardSession
    let macroIndex: Int
    @Binding var steps: [MacroStepDraft]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Macro \(macroIndex)")
                    .font(.title3.weight(.semibold))
                Spacer()
                Menu("Add Step", systemImage: "plus") {
                    ForEach(MacroStepDraft.Kind.allCases) { kind in
                        Button(kind.title) { steps.append(MacroStepDraft(kind: kind)) }
                    }
                }
                .fixedSize()
                Button("Clear", systemImage: "trash", role: .destructive, action: clear)
                    .disabled(steps.isEmpty)
            }
            .padding(12)

            if steps.isEmpty {
                ContentUnavailableView("Empty macro", systemImage: "text.append",
                                       description: Text("Add text to type, keys to press, or pauses."))
            } else {
                List {
                    ForEach($steps) { $step in
                        MacroStepRow(session: session, step: $step)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
            }
        }
    }

    private func clear() {
        steps.removeAll()
    }

    private func move(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
    }

    private func delete(at offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
    }
}
