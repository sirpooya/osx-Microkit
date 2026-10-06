import AppKit
import MicrokitCore
import SwiftUI
import UniformTypeIdentifiers

/// Facts about the keyboard, its layout source, backups and resets.
struct DeviceScreen: View {
    let session: KeyboardSession
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImportingBackup = false
    @State private var isImportingDefinition = false
    @State private var isConfirmingReset = false
    @State private var isBusy = false

    var body: some View {
        Form {
            Section("Keyboard") {
                LabeledContent("Name", value: session.name)
                LabeledContent("Reported name", value: [session.info.manufacturer, session.info.productName].filter { !$0.isEmpty }.joined(separator: " "))
                LabeledContent("Vendor and product ID", value: session.info.idText)
                LabeledContent("Connection", value: session.info.transport)
                if let serial = session.info.serialNumber, !serial.isEmpty {
                    LabeledContent("Serial number", value: serial)
                }
                Button("Identify (flash the keyboard's lights)", systemImage: "sparkles", action: identify)
                    .disabled(session.isDemo)
            }

            Section("Firmware") {
                LabeledContent("VIA protocol", value: "\(session.protocolVersion)")
                LabeledContent("Keycode table", value: "QMK \(session.formatter.table.spec.version)")
                if session.firmwareVersion != 0 {
                    LabeledContent("Firmware version", value: String(session.firmwareVersion))
                }
                LabeledContent("Layers", value: "\(session.layerCount)")
                LabeledContent("Knobs", value: "\(session.definition?.encoderCount ?? 0)")
                LabeledContent("Macros", value: "\(session.macroCount), \(session.macroBufferSize) bytes")
            }

            if let definition = session.definition, !definition.layouts.optionGroups.isEmpty {
                Section("Layout options") {
                    ForEach(Array(definition.layouts.optionGroups.enumerated()), id: \.offset) { index, group in
                        LayoutOptionRow(session: session, group: group, index: index)
                    }
                }
            }

            Section("Layout definition") {
                LabeledContent("Source", value: session.definitionSource?.rawValue ?? "None")
                HStack {
                    Button("Import Definition…", action: { isImportingDefinition = true })
                    Button("Reload from usevia.app", action: reloadDefinition)
                    if session.definitionSource == .imported {
                        Button("Use usevia.app Instead", action: forgetImport)
                    }
                }
            }

            Section {
                HStack {
                    Button("Back Up to File…", systemImage: "square.and.arrow.down", action: backUp)
                    Button("Restore from File…", systemImage: "square.and.arrow.up", action: { isImportingBackup = true })
                        .disabled(session.isEditable == false)
                    Spacer()
                    if isBusy { ProgressView().controlSize(.small) }
                }
                if let url = session.lastBackupURL {
                    LabeledContent("Automatic backup") {
                        Button(url.lastPathComponent) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                            .buttonStyle(.link)
                    }
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Microkit saves a full backup automatically before its first change to a keyboard each launch.")
            }

            Section("Reset") {
                Button("Reset Keymap to Firmware Defaults…", role: .destructive, action: { isConfirmingReset = true })
                    .disabled(session.isEditable == false)
            }
        }
        .formStyle(.grouped)
        .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .json,
                      defaultFilename: "\(session.name) backup.json") { _ in exportDocument = nil }
        .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json], onCompletion: restore)
        .fileImporter(isPresented: $isImportingDefinition, allowedContentTypes: [.json], onCompletion: importDefinition)
        .confirmationDialog("Reset the keymap?", isPresented: $isConfirmingReset) {
            Button("Reset Keymap", role: .destructive, action: resetKeymap)
        } message: {
            Text("Every key and knob on every layer goes back to the firmware's defaults. A backup is saved first.")
        }
    }

    private func identify() {
        Task { await session.identify() }
    }

    private func backUp() {
        isBusy = true
        Task {
            do {
                exportDocument = BackupDocument(backup: try await session.makeBackup())
                isExporting = true
            } catch {
                session.lastError = "Backup failed: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        isBusy = true
        Task {
            do {
                let backup = try KeyboardBackup.decode(Data(contentsOf: url))
                await session.restore(backup)
            } catch {
                session.lastError = "That file is not a Microkit backup: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    private func importDefinition(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        Task { await session.importDefinition(from: url) }
    }

    private func reloadDefinition() {
        Task { await session.load(refreshDefinition: true) }
    }

    private func forgetImport() {
        Task { await session.forgetImportedDefinition() }
    }

    private func resetKeymap() {
        Task { await session.resetKeymap() }
    }
}
