import Foundation
import IOKit
import IOKit.ps

enum BluetoothBatteryReader {
    struct Entry: Equatable, Sendable {
        let name: String
        let address: String?
        let reading: BluetoothBatteryReading
    }

    static func collectAllEntries() -> [Entry] {
        var merged: [String: Entry] = [:]

        for entry in readPowerSourceEntries() {
            merged[mergeKey(for: entry)] = entry
        }

        for entry in readIORegistryEntries() {
            let key = mergeKey(for: entry)
            if let existing = merged[key] {
                merged[key] = preferRicherEntry(existing, entry)
            } else {
                merged[key] = entry
            }
        }

        for entry in readPlistCacheEntries() {
            let key = mergeKey(for: entry)
            if let existing = merged[key] {
                merged[key] = preferRicherEntry(existing, entry)
            } else {
                merged[key] = entry
            }
        }

        for entry in readPmsetEntries() {
            let key = mergeKey(for: entry)
            if let existing = merged[key] {
                merged[key] = preferRicherEntry(existing, entry)
            } else {
                merged[key] = entry
            }
        }

        return Array(merged.values)
    }

    static func readPmsetEntries() -> [Entry] {
        var entries: [Entry] = []

        // Accessory batteries (AirPods, keyboards, etc.) appear in accps on modern macOS.
        entries.append(contentsOf: parsePmsetOutput(readPmsetOutput(arguments: ["-g", "accps"])))
        entries.append(contentsOf: parsePmsetOutput(readPmsetOutput(arguments: ["-g", "batt"])))

        return entries
    }

    static func readPowerSourceEntries() -> [Entry] {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        guard let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return []
        }

        var entries: [Entry] = []

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            if desc["Type"] as? String == "InternalBattery" { continue }

            guard let name = desc["Name"] as? String,
                  let capacity = desc["Current Capacity"] as? Int,
                  let maxCapacity = desc["Max Capacity"] as? Int,
                  maxCapacity > 0
            else {
                continue
            }

            let level = min(100, (capacity * 100) / maxCapacity)

            entries.append(Entry(
                name: name,
                address: nil,
                reading: BluetoothBatteryReading(primaryLevel: level)
            ))
        }

        return entries
    }

    static func parsePmsetOutput(_ output: String) -> [Entry] {
        // Supports both legacy (`-Device-0 (id=123)`) and modern (`-Device (id=123)`) pmset formats.
        guard let regex = try? NSRegularExpression(
            pattern: #"^\s*-(.+?)(?:-\d+)? \(id=\d+\)\s+(\d+)%;"#,
            options: []
        ) else {
            return []
        }

        var entries: [Entry] = []

        for line in output.split(separator: "\n") {
            let trimmed = String(line)
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            guard
                let match = regex.firstMatch(in: trimmed, options: [], range: range),
                let nameRange = Range(match.range(at: 1), in: trimmed),
                let levelRange = Range(match.range(at: 2), in: trimmed),
                let level = Int(trimmed[levelRange])
            else {
                continue
            }

            let deviceName = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
            guard !deviceName.isEmpty, !deviceName.hasPrefix("InternalBattery") else { continue }

            entries.append(
                Entry(
                    name: deviceName,
                    address: nil,
                    reading: BluetoothBatteryReading(primaryLevel: level)
                )
            )
        }

        return entries
    }

    static func readIORegistryEntries() -> [Entry] {
        var entries: [Entry] = []
        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return entries }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            guard
                let percent = registryInt(for: "BatteryPercent", on: service),
                percent >= 0, percent <= 100
            else {
                continue
            }

            let product = registryString(for: "Product", on: service) ?? String(localized: "Bluetooth Device")
            let address = registryString(for: "DeviceAddress", on: service)

            entries.append(
                Entry(
                    name: product,
                    address: address,
                    reading: BluetoothBatteryReading(primaryLevel: percent)
                )
            )
        }

        return entries
    }

    static func readPlistCacheEntries() -> [Entry] {
        let paths = [
            NSHomeDirectory() + "/Library/Preferences/com.apple.Bluetooth.plist",
            "/Library/Preferences/com.apple.Bluetooth.plist"
        ]

        var entries: [Entry] = []

        for path in paths {
            guard
                let data = FileManager.default.contents(atPath: path),
                let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                let cache = plist["DeviceCache"] as? [String: Any]
            else {
                continue
            }

            for (address, value) in cache {
                guard let device = value as? [String: Any] else { continue }
                let name = (device["Name"] as? String) ?? address

                if let reading = readingFromPlistDevice(device) {
                    entries.append(
                        Entry(
                            name: name,
                            address: address.replacingOccurrences(of: "-", with: ":"),
                            reading: reading
                        )
                    )
                }
            }
        }

        return entries
    }

    // MARK: - Private

    private static func readPmsetOutput(arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static func readingFromPlistDevice(_ device: [String: Any]) -> BluetoothBatteryReading? {
        var components: [BluetoothBatteryComponent] = []

        if let left = intValue(device["BatteryPercentLeft"]) {
            components.append(BluetoothBatteryComponent(kind: .left, level: left))
        }
        if let right = intValue(device["BatteryPercentRight"]) {
            components.append(BluetoothBatteryComponent(kind: .right, level: right))
        }
        if let caseLevel = intValue(device["BatteryPercentCase"]) {
            components.append(BluetoothBatteryComponent(kind: .caseUnit, level: caseLevel))
        }

        if let single = intValue(device["BatteryPercent"]) ?? intValue(device["BatteryLevel"]) {
            return BluetoothBatteryReading(primaryLevel: single, components: components)
        }

        guard !components.isEmpty else { return nil }

        let primary = components.map(\.level).min() ?? components[0].level
        return BluetoothBatteryReading(primaryLevel: primary, components: components)
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private static func registryString(for key: String, on service: io_registry_entry_t) -> String? {
        guard
            let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        else {
            return nil
        }

        if let string = value as? String {
            return string
        }
        if let data = value as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }

    private static func registryInt(for key: String, on service: io_registry_entry_t) -> Int? {
        guard
            let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private static func mergeKey(for entry: Entry) -> String {
        if let address = entry.address {
            return BluetoothNameMatcher.normalizedAddress(address)
        }
        return BluetoothNameMatcher.normalizedName(entry.name)
    }

    private static func preferRicherEntry(_ lhs: Entry, _ rhs: Entry) -> Entry {
        if lhs.reading.components.count >= rhs.reading.components.count {
            if lhs.reading.components.count == rhs.reading.components.count,
               rhs.reading.primaryLevel >= 0 {
                return Entry(name: lhs.name, address: lhs.address ?? rhs.address, reading: rhs.reading)
            }
            return lhs
        }
        return Entry(name: rhs.name, address: rhs.address ?? lhs.address, reading: rhs.reading)
    }
}
