import SwiftUI

/// Sidebar text under Microkit's modes, in MicroMap's sidebar style.
struct MicrokitModeNote: View {
    let mode: AppMode

    var body: some View {
        Text(text)
            .font(FMTheme.body)
            .foregroundStyle(FMTheme.textSecondary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var text: String {
        switch mode {
        case .music: "Your keyboard's lights follow whatever is playing on this Mac."
        case .macros: "Text and key sequences the keyboard types for you. Assign one from Actions > Macros."
        case .tester: "Press keys on the keyboard to check every switch."
        case .device: "Keyboard facts, backups, restore and the demo keyboard."
        default: ""
        }
    }
}
