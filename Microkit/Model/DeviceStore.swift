import Foundation
import Observation

/// Every connected VIA keyboard, kept in sync with USB hot-plug events.
@MainActor
@Observable
final class DeviceStore {
    private(set) var sessions: [KeyboardSession] = []
    var selectedID: UInt64?
    private(set) var monitorError: String?

    @ObservationIgnored private let monitor = HIDDeviceMonitor()
    @ObservationIgnored private var isRunning = false

    var selectedSession: KeyboardSession? {
        sessions.first { $0.id == selectedID } ?? sessions.first
    }

    var hasDemo: Bool { sessions.contains(where: \.isDemo) }

    /// Adds a pretend Micro Pad so every screen can be tried without hardware.
    func addDemo() async {
        guard !hasDemo else { return }
        let keyboard = await DemoKeyboard.makeMicroPad()
        let session = KeyboardSession(transport: keyboard, info: DemoKeyboard.info, demoKeyboard: keyboard)
        sessions.append(session)
        selectedID = session.id
        session.start()
    }

    func removeDemo() async {
        guard let demo = sessions.first(where: \.isDemo) else { return }
        await demo.music?.stop()
        demo.stop()
        sessions.removeAll { $0.isDemo }
        if selectedID == demo.id { selectedID = sessions.first?.id }
    }

    /// Stops music mode everywhere, restoring each keyboard's lighting.
    func stopMusic() async {
        for session in sessions {
            await session.music?.stop()
        }
    }

    /// Runs for the life of the window: starts USB monitoring and applies its events.
    func run() async {
        guard !isRunning else { return }
        isRunning = true
        AppDelegate.beforeQuit = { [weak self] in await self?.stopMusic() }
        if ProcessInfo.processInfo.arguments.contains("--demo") { await addDemo() }
        monitor.start()
        for await event in monitor.events {
            switch event {
            case .added(let transport):
                let session = KeyboardSession(transport: transport, info: transport.info)
                sessions.append(session)
                if selectedID == nil { selectedID = session.id }
                session.start()
            case .removed(let registryID):
                sessions.first { $0.id == registryID }?.stop()
                sessions.removeAll { $0.id == registryID }
                if selectedID == registryID { selectedID = sessions.first?.id }
            case .failed(let message):
                monitorError = message
            }
        }
    }
}
