import AppKit
import Foundation

@MainActor
protocol ApplicationLaunching {
    func openApplication(
        bundleIdentifier: String,
        completion: @escaping @Sendable (Result<Void, any Error>) -> Void
    )
}

enum ApplicationLaunchError: LocalizedError, Equatable {
    case applicationNotInstalled(bundleIdentifier: String)

    var errorDescription: String? {
        switch self {
        case let .applicationNotInstalled(bundleIdentifier):
            "Figma není nainstalovaná nebo ji macOS nemůže najít (\(bundleIdentifier))."
        }
    }
}

@MainActor
struct WorkspaceApplicationLauncher: ApplicationLaunching {
    func openApplication(
        bundleIdentifier: String,
        completion: @escaping @Sendable (Result<Void, any Error>) -> Void
    ) {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) else {
            completion(.failure(ApplicationLaunchError.applicationNotInstalled(bundleIdentifier: bundleIdentifier)))
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: configuration
        ) { _, error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}

@MainActor
final class FigmaApplicationOpener {
    static let bundleIdentifier = "com.figma.Desktop"

    private let launcher: any ApplicationLaunching

    init(launcher: any ApplicationLaunching = WorkspaceApplicationLauncher()) {
        self.launcher = launcher
    }

    func openFigma(completion: @escaping @Sendable (Result<Void, any Error>) -> Void) {
        launcher.openApplication(
            bundleIdentifier: Self.bundleIdentifier,
            completion: completion
        )
    }
}
