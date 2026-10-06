import MicrokitCore
import SwiftUI
import UniformTypeIdentifiers

/// A keyboard backup as a JSON file, for `fileExporter`.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let backup: KeyboardBackup

    init(backup: KeyboardBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        backup = try KeyboardBackup.decode(data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try backup.encoded())
    }
}
