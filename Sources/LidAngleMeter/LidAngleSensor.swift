import Foundation
import IOKit
import IOKit.hid

/// Reads the MacBook lid-angle sensor.
///
/// Verified on MacBookPro18,3 / macOS 26: the sensor is an Apple HID device
/// (0x05AC:0x8104) published on the standard HID sensor usage page
/// 0x0020 / usage 0x008A. Feature report 1 carries the angle in degrees in
/// bytes 1..2 (little endian). The same product also publishes vendor-page
/// (0xFF00) interfaces that fail the report read — those are simply skipped
/// while probing, they are not a failure of the sensor.
final class LidAngleSensor {

    private static let sensorUsagePage = 0x0020
    private static let sensorUsage = 0x008A
    private static let featureReportID: CFIndex = 1
    private static let reportSize = 8

    private let manager: IOHIDManager
    private var device: IOHIDDevice?

    /// Fails if no lid-angle interface can be opened and read.
    init?() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)

        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: LidAngleSensor.sensorUsagePage,
            kIOHIDDeviceUsageKey: LidAngleSensor.sensorUsage
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        guard IOHIDManagerOpen(manager, 0) == kIOReturnSuccess else { return nil }
        guard let matched = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return nil }

        // Keep the first interface that actually answers the feature read, and
        // hold it open for the lifetime of the app (no open/close per tick).
        for candidate in matched {
            guard IOHIDDeviceOpen(candidate, 0) == kIOReturnSuccess else { continue }
            if LidAngleSensor.readRaw(from: candidate) != nil {
                device = candidate
                break
            }
            IOHIDDeviceClose(candidate, 0)
        }

        if device == nil { return nil }
    }

    deinit {
        if let device = device {
            IOHIDDeviceClose(device, 0)
        }
        IOHIDManagerClose(manager, 0)
    }

    /// Current lid angle in degrees, or nil if this read failed.
    func readAngle() -> Double? {
        guard let device = device else { return nil }
        return LidAngleSensor.readRaw(from: device)
    }

    private static func readRaw(from device: IOHIDDevice) -> Double? {
        var report = [UInt8](repeating: 0, count: reportSize)
        var length: CFIndex = report.count
        let result = IOHIDDeviceGetReport(device,
                                          kIOHIDReportTypeFeature,
                                          featureReportID,
                                          &report,
                                          &length)
        guard result == kIOReturnSuccess, length >= 3 else { return nil }
        let raw = (UInt16(report[2]) << 8) | UInt16(report[1])
        return Double(raw)
    }
}
