import Carbon
import Foundation

final class GlobalHotKeyService: @unchecked Sendable {
    enum RegistrationError: LocalizedError {
        case eventHandler(OSStatus)
        case hotKey(String, OSStatus)

        var errorDescription: String? {
            switch self {
            case let .eventHandler(status):
                "The global shortcut could not be prepared (Carbon \(status))."
            case let .hotKey(chord, status):
                "The shortcut \(chord) could not be registered (Carbon \(status)). It may be taken by another app."
            }
        }
    }

    private static let signature: OSType = 0x464D4943 // FMIC
    private static let identifier: UInt32 = 1

    private let handler: @Sendable () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    func register(_ shortcut: GlobalShortcut) throws {
        unregisterHotKey()

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            let handlerStatus = InstallEventHandler(
                GetApplicationEventTarget(),
                globalHotKeyEventHandler,
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandlerRef
            )
            guard handlerStatus == noErr else {
                throw RegistrationError.eventHandler(handlerStatus)
            }
        }

        let hotKeyID = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let registrationStatus = RegisterEventHotKey(
            shortcut.macKeyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registrationStatus == noErr else {
            throw RegistrationError.hotKey(shortcut.chord.displayName, registrationStatus)
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    func unregister() {
        unregisterHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate func handleEvent(_ event: EventRef?) -> OSStatus {
        guard let event else { return OSStatus(eventNotHandledErr) }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr,
              hotKeyID.signature == Self.signature,
              hotKeyID.id == Self.identifier else { return OSStatus(eventNotHandledErr) }
        handler()
        return noErr
    }
}

private let globalHotKeyEventHandler: EventHandlerUPP = { _, event, context in
    guard let context else { return OSStatus(eventNotHandledErr) }
    let service = Unmanaged<GlobalHotKeyService>.fromOpaque(context).takeUnretainedValue()
    return service.handleEvent(event)
}
