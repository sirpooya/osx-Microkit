import Foundation
import IOKit.hid
import MicrokitCore
import os

private let log = Logger(subsystem: "in.pooya.microkit", category: "hid")

/// `ReportTransport` over one IOHIDDevice (the VIA raw HID interface, usage page 0xFF60).
///
/// Exchanges run one at a time on a private serial queue: send an output report, then block
/// that queue (never the main thread or the cooperative pool) until a matching input report
/// arrives from the HID thread or the timeout passes.
final class HIDDeviceTransport: ReportTransport, @unchecked Sendable {
    let info: HIDDeviceInfo
    private let device: IOHIDDevice
    private let queue: DispatchQueue
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private let reportBufferSize: Int

    // Guarded by `lock`.
    private let lock = NSLock()
    private var inbox: [[UInt8]] = []
    private var isInvalidated = false
    private let arrived = DispatchSemaphore(value: 0)

    /// Call on the HID thread: the device is scheduled on its run loop.
    init(device: IOHIDDevice, info: HIDDeviceInfo) {
        self.device = device
        self.info = info
        queue = DispatchQueue(label: "in.pooya.microkit.hid.\(info.registryID)", qos: .userInitiated)
        reportBufferSize = max(info.maxInputReportSize, 64)
        reportBuffer = .allocate(capacity: reportBufferSize)
        reportBuffer.initialize(repeating: 0, count: reportBufferSize)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, reportBufferSize, { context, _, _, _, _, report, length in
            guard let context else { return }
            let transport = Unmanaged<HIDDeviceTransport>.fromOpaque(context).takeUnretainedValue()
            transport.received(Array(UnsafeBufferPointer(start: report, count: length)))
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, HIDThread.shared.runLoop, CFRunLoopMode.defaultMode.rawValue)
    }

    deinit {
        reportBuffer.deallocate()
    }

    /// Stops callbacks. The buffer is released once the HID thread has let go of it.
    func invalidate() {
        lock.withLock { isInvalidated = true }
        arrived.signal()
        // The block keeps `self` (and so the buffer) alive until the callback is unregistered.
        HIDThread.shared.perform { [self] in
            IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, reportBufferSize, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, HIDThread.shared.runLoop, CFRunLoopMode.defaultMode.rawValue)
        }
    }

    func exchange(_ request: [UInt8], timeout: Duration, matches: @escaping @Sendable ([UInt8]) -> Bool) async throws -> [UInt8] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try self.exchangeNow(request, timeout: timeout, matches: matches) })
            }
        }
    }

    private func exchangeNow(_ request: [UInt8], timeout: Duration, matches: ([UInt8]) -> Bool) throws -> [UInt8] {
        let command = request.first ?? 0
        try lock.withLock {
            if isInvalidated { throw VIAError.transport("The keyboard was disconnected.") }
            inbox.removeAll()
        }
        while arrived.wait(timeout: .now()) == .success {}

        // Every command that changes the keyboard is logged, so a stray write is easy to spot:
        // log show --predicate 'subsystem == "in.pooya.microkit"' --last 10m
        if let viaCommand = VIACommand(rawValue: command), viaCommand.writes {
            let bytes = request.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " ")
            if viaCommand == .customSetValue {
                // Live lighting values (music mode streams ~30 a second) never reach EEPROM.
                log.debug("set \(bytes, privacy: .public)")
            } else {
                log.notice("write \(bytes, privacy: .public)")
            }
        }
        var report = [UInt8](repeating: 0, count: VIAClient.reportSize)
        report.replaceSubrange(0..<min(request.count, report.count), with: request.prefix(report.count))
        let result = report.withUnsafeBufferPointer { buffer in
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, buffer.baseAddress!, buffer.count)
        }
        guard result == kIOReturnSuccess else {
            throw VIAError.transport(String(format: "Could not send to the keyboard (IOReturn 0x%08X).", result))
        }

        let deadline = DispatchTime.now() + .nanoseconds(Int(timeout.nanoseconds))
        while true {
            // Drain the inbox before sleeping: the semaphore can run ahead of or behind it.
            let next: [UInt8]? = try lock.withLock {
                if isInvalidated { throw VIAError.transport("The keyboard was disconnected.") }
                return inbox.isEmpty ? nil : inbox.removeFirst()
            }
            if let next {
                if matches(next) { return next }
                continue
            }
            if arrived.wait(timeout: deadline) == .timedOut {
                throw VIAError.timeout(command: command)
            }
        }
    }

    private func received(_ report: [UInt8]) {
        lock.withLock { inbox.append(report) }
        arrived.signal()
    }
}

private extension Duration {
    var nanoseconds: Int64 {
        let (seconds, attoseconds) = components
        return seconds * 1_000_000_000 + attoseconds / 1_000_000_000
    }
}
