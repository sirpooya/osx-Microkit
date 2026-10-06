import Foundation
import MicrokitCore

/// Finds the VIA definition for a keyboard: an imported file first, then the local cache,
/// then usevia.app. Downloaded definitions are cached so the app works offline afterwards.
struct DefinitionStore: Sendable {
    enum Source: String, Sendable {
        case imported = "Imported file"
        case cache = "usevia.app (cached)"
        case usevia = "usevia.app"
    }

    struct Loaded: Sendable {
        let definition: KeyboardDefinition
        let source: Source
    }

    enum StoreError: Error, LocalizedError {
        case notListed(vendorProductID: UInt32)
        case network(String)

        var errorDescription: String? {
            switch self {
            case .notListed:
                "usevia.app has no layout for this keyboard. Import its VIA definition (a .json file) to configure it."
            case .network(let message):
                "The keyboard layout could not be downloaded from usevia.app: \(message)"
            }
        }
    }

    static let shared = DefinitionStore()
    static let remoteBase = URL(string: "https://usevia.app/definitions/v3/")!

    let root: URL

    init(root: URL = AppPaths.definitions) {
        self.root = root
    }

    func load(vendorProductID: UInt32, refresh: Bool = false) async throws -> Loaded {
        if let data = try? Data(contentsOf: importedURL(vendorProductID)) {
            return Loaded(definition: try KeyboardDefinition.decode(data), source: .imported)
        }
        if !refresh, let data = try? Data(contentsOf: cachedURL(vendorProductID)),
           let definition = try? KeyboardDefinition.decode(data) {
            return Loaded(definition: definition, source: .cache)
        }
        let url = Self.remoteBase.appending(path: "\(vendorProductID).json")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            if let cached = try? Data(contentsOf: cachedURL(vendorProductID)), let definition = try? KeyboardDefinition.decode(cached) {
                return Loaded(definition: definition, source: .cache)
            }
            throw StoreError.network(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw StoreError.notListed(vendorProductID: vendorProductID)
        }
        let definition = try KeyboardDefinition.decode(data)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? data.write(to: cachedURL(vendorProductID), options: .atomic)
        return Loaded(definition: definition, source: .usevia)
    }

    /// Copies a definition file into the store. It wins over usevia.app for its keyboard.
    func importDefinition(from url: URL) throws -> KeyboardDefinition {
        let data = try Data(contentsOf: url)
        let definition = try KeyboardDefinition.decode(data)
        try FileManager.default.createDirectory(at: root.appending(path: "Imported"), withIntermediateDirectories: true)
        try data.write(to: importedURL(definition.vendorProductId), options: .atomic)
        return definition
    }

    func removeImported(vendorProductID: UInt32) {
        try? FileManager.default.removeItem(at: importedURL(vendorProductID))
    }

    private func cachedURL(_ id: UInt32) -> URL { root.appending(path: "\(id).json") }
    private func importedURL(_ id: UInt32) -> URL { root.appending(path: "Imported/\(id).json") }
}
