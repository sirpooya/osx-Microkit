import Foundation

/// A dedicated thread whose run loop receives every IOKit HID callback (device added,
/// removed, input report). Keeping HID off the main run loop means a busy UI never delays a
/// keyboard reply, and a slow keyboard never stalls the UI.
final class HIDThread: Thread, @unchecked Sendable {
    static let shared: HIDThread = {
        let thread = HIDThread()
        thread.name = "in.pooya.microkit.hid"
        thread.qualityOfService = .userInitiated
        thread.start()
        thread.ready.wait()
        return thread
    }()

    private let ready = DispatchSemaphore(value: 0)
    // Written once in main() before `ready` is signalled, read-only afterwards.
    private var loop: CFRunLoop?

    var runLoop: CFRunLoop {
        guard let loop else { preconditionFailure("HIDThread used before start") }
        return loop
    }

    override func main() {
        loop = CFRunLoopGetCurrent()
        // A run loop with no sources exits immediately; a port keeps it alive.
        RunLoop.current.add(NSMachPort(), forMode: .default)
        ready.signal()
        while !isCancelled {
            RunLoop.current.run(mode: .default, before: .distantFuture)
        }
    }

    /// Runs `block` on the HID thread's run loop.
    func perform(_ block: @escaping @Sendable () -> Void) {
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.defaultMode.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }
}
