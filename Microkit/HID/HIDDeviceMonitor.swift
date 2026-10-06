import Foundation
import IOKit.hid
import os

private let log = Logger(subsystem: "in.pooya.microkit", category: "hid")

/// Watches for VIA raw HID interfaces (usage page 0xFF60, usage 0x61) coming and going.
/// Only that interface is opened, never the keyboard or mouse interfaces of the same device,
/// so no Input Monitoring permission is involved.
final class HIDDeviceMonitor: @unchecked Sendable {
    enum Event: Sendable {
        case added(HIDDeviceTransport)
        case removed(registryID: UInt64)
        case failed(String)
    }

    static let viaUsagePage = 0xFF60
    static let viaUsage = 0x61

    let events: AsyncStream<Event>
    private let continuation: AsyncStream<Event>.Continuation
    private let manager: IOHIDManager

    // Touched only on the HID thread. Keyed by the IOHIDDevice object: the removal callback
    // hands back the same object, while registry lookups on a removed device can fail.
    private var transports: [ObjectIdentifier: HIDDeviceTransport] = [:]

    init() {
        (events, continuation) = AsyncStream.makeStream(of: Event.self)
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func start() {
        HIDThread.shared.perform { [self] in
            IOHIDManagerSetDeviceMatching(manager, [
                kIOHIDDeviceUsagePageKey: Self.viaUsagePage,
                kIOHIDDeviceUsageKey: Self.viaUsage,
            ] as CFDictionary)
            let context = Unmanaged.passUnretained(self).toOpaque()
            IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
                guard let context else { return }
                Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue().deviceAdded(device)
            }, context)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
                guard let context else { return }
                Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue().deviceRemoved(device)
            }, context)
            IOHIDManagerScheduleWithRunLoop(manager, HIDThread.shared.runLoop, CFRunLoopMode.defaultMode.rawValue)
            let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            if result == kIOReturnNotPermitted {
                continuation.yield(.failed("macOS blocked access to keyboards. Allow Microkit in System Settings > Privacy & Security > Input Monitoring, then relaunch."))
            } else if result != kIOReturnSuccess {
                continuation.yield(.failed(String(format: "Could not start USB device monitoring (IOReturn 0x%08X).", result)))
            }
        }
    }

    private func deviceAdded(_ device: IOHIDDevice) {
        guard transports[ObjectIdentifier(device)] == nil else { return }
        let transport = HIDDeviceTransport(device: device, info: HIDDeviceInfo(device: device))
        transports[ObjectIdentifier(device)] = transport
        log.notice("connected \(transport.info.productName, privacy: .public) \(transport.info.idText, privacy: .public)")
        continuation.yield(.added(transport))
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        guard let transport = transports.removeValue(forKey: ObjectIdentifier(device)) else { return }
        transport.invalidate()
        continuation.yield(.removed(registryID: transport.info.registryID))
    }
}
