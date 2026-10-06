import MicrokitCore
import SwiftUI

/// One composed keycode with a preview and an Assign button.
struct BuilderRow: View {
    let session: KeyboardSession
    let title: String
    let code: UInt16?

    var body: some View {
        HStack(spacing: 10) {
            if let code {
                MiniKeycap(legend: session.legend(for: code), size: 34)
            } else {
                RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary).frame(width: 34, height: 34)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(code.map { session.legend(for: $0).qmkName } ?? "Pick at least one modifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Assign", action: assign)
                .disabled(code == nil)
        }
    }

    private func assign() {
        guard let code else { return }
        Task { await session.assign(code) }
    }
}
