import AppKit
import Observation

@MainActor
@Observable
final class FigmaActivityMonitor {
    static let figmaBundleIdentifier = "com.figma.Desktop"

    private(set) var isFigmaActive = false
    var onActivityChanged: ((Bool) -> Void)?

    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    func start() {
        guard activationObserver == nil else { return }

        isFigmaActive = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.figmaBundleIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                self?.handleActivation(bundleIdentifier: application.bundleIdentifier)
            }
        }
    }

    func stop() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
    }

    private func handleActivation(bundleIdentifier: String?) {
        let wasFigmaActive = isFigmaActive
        let nowFigmaActive = bundleIdentifier == Self.figmaBundleIdentifier
        guard wasFigmaActive != nowFigmaActive else { return }

        isFigmaActive = nowFigmaActive
        onActivityChanged?(nowFigmaActive)
    }
}
