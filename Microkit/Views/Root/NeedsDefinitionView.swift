import SwiftUI
import UniformTypeIdentifiers

/// The keyboard answered, but there is no layout to draw it with.
struct NeedsDefinitionView: View {
    let session: KeyboardSession
    let message: String
    @State private var isImporting = false

    var body: some View {
        ContentUnavailableView {
            Label("No layout for \(session.info.productName)", systemImage: "questionmark.square.dashed")
        } description: {
            Text("\(message)\n\nKeyboard ID \(session.info.idText), VIA protocol \(session.protocolVersion).")
        } actions: {
            Button("Import Definition…", action: { isImporting = true })
                .buttonStyle(.borderedProminent)
            Button("Try usevia.app Again", action: retry)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json], onCompletion: importDefinition)
    }

    private func retry() {
        Task { await session.load(refreshDefinition: true) }
    }

    private func importDefinition(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        Task { await session.importDefinition(from: url) }
    }
}
