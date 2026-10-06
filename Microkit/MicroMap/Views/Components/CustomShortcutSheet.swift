import AppKit
import SwiftUI

struct CustomShortcutSheet: View {
    @Bindable var store: AppStore
    let action: FigmaAction?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var title: String
    @State private var chord: KeyChord?

    init(store: AppStore, action: FigmaAction? = nil) {
        self.store = store
        self.action = action
        _title = State(initialValue: action?.title ?? "")
        _chord = State(initialValue: action?.chord)
    }

    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let chord else { return action?.qmkKeycode != nil }
        let layout = KeyboardLayoutResolver.resolve(KeyboardLayoutPreference.current)
        return QMKKeycodeEncoder.encode(chord, layout: layout) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action == nil ? "Custom shortcut" : "Edit custom shortcut")
                    .font(.title3.weight(.semibold))
                Text(action == nil
                     ? "Name it, then click the field and press a key combination."
                     : "Change its name or record a new key combination.")
                    .font(FMTheme.caption)
                    .foregroundStyle(FMTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(FMTheme.captionEmphasized)
                    .foregroundStyle(FMTheme.textSecondary)
                TextField("Shortcut name", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Shortcut")
                    .font(FMTheme.captionEmphasized)
                    .foregroundStyle(FMTheme.textSecondary)
                ShortcutRecorderField(
                    chord: $chord,
                    fallbackLabel: action?.chord == nil ? action?.shortcutLabel : nil
                )
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let action {
                        if store.updateCustomShortcut(id: action.id, title: title, chord: chord) {
                            dismiss()
                        }
                    } else if let chord,
                              store.createCustomShortcut(title: title, chord: chord) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(22)
        .frame(width: 410)
        .onAppear { isNameFocused = true }
    }
}
