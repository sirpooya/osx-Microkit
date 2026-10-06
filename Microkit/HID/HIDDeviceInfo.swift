import Foundation
import IOKit.hid

/// What IOKit tells us about one raw HID interface, read once when it appears.
struct HIDDeviceInfo: Hashable, Sendable {
    /// IORegistry entry id: stable while the device stays plugged in.
    let registryID: UInt64
    let productName: String
    let manufacturer: String
    let vendorID: UInt16
    let productID: UInt16
    let serialNumber: String?
    /// "USB", "Bluetooth Low Energy", ...
    let transport: String
    let maxInputReportSize: Int

    init(registryID: UInt64, productName: String, manufacturer: String, vendorID: UInt16, productID: UInt16,
         serialNumber: String? = nil, transport: String, maxInputReportSize: Int = 32) {
        self.registryID = registryID
        self.productName = productName
        self.manufacturer = manufacturer
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.transport = transport
        self.maxInputReportSize = maxInputReportSize
    }

    init(device: IOHIDDevice) {
        func property<T>(_ key: String) -> T? {
            IOHIDDeviceGetProperty(device, key as CFString) as? T
        }
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &entryID)
        registryID = entryID
        productName = property(kIOHIDProductKey) ?? "Keyboard"
        manufacturer = property(kIOHIDManufacturerKey) ?? ""
        vendorID = UInt16(truncatingIfNeeded: property(kIOHIDVendorIDKey) as Int? ?? 0)
        productID = UInt16(truncatingIfNeeded: property(kIOHIDProductIDKey) as Int? ?? 0)
        serialNumber = property(kIOHIDSerialNumberKey)
        transport = property(kIOHIDTransportKey) ?? "USB"
        maxInputReportSize = property(kIOHIDMaxInputReportSizeKey) ?? 32
    }

    /// `VID:PID` in hex, the way keyboard people write it.
    var idText: String { String(format: "%04X:%04X", vendorID, productID) }
}
