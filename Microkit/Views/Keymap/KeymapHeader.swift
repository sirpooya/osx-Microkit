import SwiftUI

/// Layer tabs and undo, above the keyboard.
struct KeymapHeader: View {
    @Bindable var session: KeyboardSession

    var body: some View {
        HStack(spacing: 12) {
            Picker("Layer", selection: $session.selectedLayer) {
                ForEach(0..<max(session.layerCount, 1), id: \.self) { layer in
                    Text("Layer \(layer)").tag(layer)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Spacer()
            if !session.isEditable {
                Label("Read-only: VIA protocol \(session.protocolVersion) firmware", systemImage: "lock")
                    .foregroundStyle(.secondary)
                    .help("Microkit edits keyboards with VIA protocol 12 or newer. Older firmware numbers keycodes differently.")
            }
            Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(session.undoStack.isEmpty)
                .help("Undo the last key change")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func undo() {
        Task { await session.undo() }
    }
}
