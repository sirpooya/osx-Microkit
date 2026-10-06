import MicrokitCore
import SwiftUI

/// One layout option (split backspace, ISO enter, bottom row...).
struct LayoutOptionRow: View {
    let session: KeyboardSession
    let group: LayoutOptionGroup
    let index: Int
    @State private var choice = 0
    @State private var isOn = false

    var body: some View {
        Group {
            if group.isToggle {
                Toggle(group.title, isOn: $isOn)
                    .onChange(of: isOn) { choice = isOn ? 1 : 0 }
            } else {
                Picker(group.title, selection: $choice) {
                    ForEach(Array(group.choices.enumerated()), id: \.offset) { offset, title in
                        Text(title).tag(offset)
                    }
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: choice) { apply() }
    }

    private func load() {
        choice = index < session.layoutChoices.count ? session.layoutChoices[index] : 0
        isOn = choice == 1
    }

    private func apply() {
        guard index < session.layoutChoices.count, session.layoutChoices[index] != choice else { return }
        Task { await session.setLayoutChoice(choice, group: index) }
    }
}
