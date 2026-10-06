import Foundation

/// Where Microkit keeps its files: `~/Library/Application Support/Microkit/`.
enum AppPaths {
    static let root = URL.applicationSupportDirectory.appending(path: "Microkit", directoryHint: .isDirectory)
    static let definitions = root.appending(path: "Definitions", directoryHint: .isDirectory)
    /// A full backup is written here before the first change to each keyboard per launch.
    static let backups = root.appending(path: "Backups", directoryHint: .isDirectory)
}
