import Foundation
import IOKit.hid

// Read-only VIA probe: protocol version, layer count, keycodes version, macro count, encoder map, keymap layer 0.
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDDeviceUsagePageKey: 0xFF60, kIOHIDDeviceUsageKey: 0x61] as CFDictionary)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
print("manager open:", String(IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)), radix: 16))
guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, let dev = devices.first else { print("no device"); exit(1) }
func prop(_ k: String) -> Any? { IOHIDDeviceGetProperty(dev, k as CFString) }
print("product:", prop(kIOHIDProductKey) ?? "-", "vid:", prop(kIOHIDVendorIDKey) ?? "-", "pid:", prop(kIOHIDProductIDKey) ?? "-",
      "maxIn:", prop(kIOHIDMaxInputReportSizeKey) ?? "-", "maxOut:", prop(kIOHIDMaxOutputReportSizeKey) ?? "-")
print("device open:", String(IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone)), radix: 16))
let inBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
var last: [UInt8] = []
let cb: IOHIDReportCallback = { ctx, _, _, _, _, report, len in
  let p = Unmanaged<Box>.fromOpaque(ctx!).takeUnretainedValue(); p.v = Array(UnsafeBufferPointer(start: report, count: len))
}
final class Box { var v: [UInt8] = [] }
let box = Box()
IOHIDDeviceRegisterInputReportCallback(dev, inBuf, 64, cb, Unmanaged.passUnretained(box).toOpaque())
IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
func send(_ bytes: [UInt8]) -> [UInt8] {
  var r = [UInt8](repeating: 0, count: 32); for (i, b) in bytes.enumerated() { r[i] = b }
  box.v = []
  let res = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0, r, 32)
  if res != kIOReturnSuccess { print("setReport err", String(res, radix: 16)); return [] }
  let deadline = Date().addingTimeInterval(1)
  while box.v.isEmpty && Date() < deadline { CFRunLoopRunInMode(.defaultMode, 0.01, true) }
  return box.v
}
func hex(_ a: [UInt8]) -> String { a.map { String(format: "%02x", $0) }.joined(separator: " ") }
let pv = send([0x01]); print("protocol:", hex(Array(pv.prefix(4))))
let lc = send([0x11]); print("layers:", lc.count > 1 ? lc[1] : 0)
print("fw version:", hex(Array(send([0x02, 0x04]).prefix(6))))
print("keycodes version:", hex(Array(send([0x02, 0x06]).prefix(6))))
print("layout options:", hex(Array(send([0x02, 0x02]).prefix(6))))
print("macro count:", hex(Array(send([0x0C]).prefix(2))), "macro buf size:", hex(Array(send([0x0D]).prefix(3))))
var keys: [String] = []
for row in 0..<4 { for col in 0..<4 { let r = send([0x04, 0, UInt8(row), UInt8(col)]); if r.count > 5 { keys.append(String(format: "%02x%02x", r[4], r[5])) } } }
print("layer0 r0-3 c0-3:", keys.joined(separator: " "))
for e in 0..<2 { for cw in 0..<2 { let r = send([0x14, 0, UInt8(e), UInt8(cw)]); print("encoder \(e) cw=\(cw):", hex(Array(r.prefix(6)))) } }
print("rgb matrix brightness/effect:", hex(Array(send([0x08, 0x03, 0x01]).prefix(5))), hex(Array(send([0x08, 0x03, 0x02]).prefix(5))))
print("rgblight brightness/effect:", hex(Array(send([0x08, 0x02, 0x01]).prefix(5))), hex(Array(send([0x08, 0x02, 0x02]).prefix(5))))
print("custom ch0 v1:", hex(Array(send([0x08, 0x00, 0x01]).prefix(5))))
IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
