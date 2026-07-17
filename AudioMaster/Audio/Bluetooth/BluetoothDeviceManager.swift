import Combine
import Foundation
import IOBluetooth
import os.log

@MainActor
final class BluetoothDeviceManager: ObservableObject {
    @Published private(set) var devices: [BluetoothDeviceInfo] = []

    private let persistence: PersistenceController
    private let logger = Logger(subsystem: "com.audiomaster.app", category: "BluetoothDeviceManager")
    private var refreshTimer: Timer?
    private var isMonitoring = false
    private var audioDeviceNames: [String] = []
    private var audioDeviceUIDs: [String: String] = [:]
    private var latestBatteryEntries: [BluetoothBatteryReader.Entry] = []
    private var refreshTask: Task<Void, Never>?
    private var refreshDebounceTask: Task<Void, Never>?

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    deinit {
        refreshTimer?.invalidate()
        refreshTask?.cancel()
        refreshDebounceTask?.cancel()
    }

    func updateAudioDeviceContext(from audioDevices: [AudioDevice]) {
        audioDeviceNames = audioDevices.map(\.name)
        audioDeviceUIDs = Dictionary(
            audioDevices.compactMap { device in
                guard let uid = device.deviceUID else { return nil }
                return (BluetoothNameMatcher.normalizedName(device.name), uid)
            },
            uniquingKeysWith: { first, _ in first }
        )
        refreshDevices()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        performRefresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performRefresh()
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
        refreshDebounceTask?.cancel()
    }

    func refreshDevices() {
        guard !Self.isRunningUnderTest else { return }

        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.performRefresh()
        }
    }

    private func performRefresh() {
        guard !Self.isRunningUnderTest else { return }

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }

            let batteryEntries = await Task.detached(priority: .utility) {
                BluetoothBatteryReader.collectAllEntries()
            }.value

            guard !Task.isCancelled else { return }

            // IOBluetooth must run on the main thread; calling it from a background queue can hang in mach_msg.
            let pairedDevices = Self.pairedBluetoothDevices()
            applySnapshot(pairedDevices: pairedDevices, batteryEntries: batteryEntries)
        }
    }

    func battery(for audioDevice: AudioDevice) -> BluetoothBatteryReading? {
        guard audioDevice.type.supportsBatteryIndicator else { return nil }
        return battery(matchingName: audioDevice.name)
    }

    func battery(matchingName name: String) -> BluetoothBatteryReading? {
        if let deviceBattery = devices.first(where: {
            ($0.isConnected || $0.isAudioDevice) && BluetoothNameMatcher.namesMatch($0.name, name)
        })?.battery {
            return deviceBattery
        }

        return batteryReading(matchingName: name, entries: latestBatteryEntries)
    }

    func connect(_ device: BluetoothDeviceInfo) {
        guard let ioDevice = IOBluetoothDevice(addressString: device.address) else { return }
        let result = ioDevice.openConnection()
        if result != kIOReturnSuccess {
            logger.error("Failed to connect \(device.name): \(result)")
        } else {
            logger.info("Connecting to \(device.name)")
            performRefresh()
        }
    }

    func disconnect(_ device: BluetoothDeviceInfo) {
        guard let ioDevice = IOBluetoothDevice(addressString: device.address) else { return }
        ioDevice.closeConnection()
        logger.info("Disconnecting from \(device.name)")
        performRefresh()
    }

    var connectedAudioDevices: [BluetoothDeviceInfo] {
        devices.filter(\.isConnected).sorted { lhs, rhs in
            if lhs.isAudioDevice != rhs.isAudioDevice {
                return lhs.isAudioDevice && !rhs.isAudioDevice
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var pairedDevices: [BluetoothDeviceInfo] {
        devices.sorted { lhs, rhs in
            if lhs.isConnected != rhs.isConnected {
                return lhs.isConnected && !rhs.isConnected
            }
            if lhs.isAudioDevice != rhs.isAudioDevice {
                return lhs.isAudioDevice && !rhs.isAudioDevice
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Private

    private struct RawBluetoothDevice: Sendable {
        let address: String
        let name: String
        let isConnected: Bool
        let isPaired: Bool
    }

    nonisolated private static func pairedBluetoothDevices() -> [RawBluetoothDevice] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }

        return paired.compactMap { device -> RawBluetoothDevice? in
            guard let address = device.addressString, !address.isEmpty else { return nil }
            let name = device.name ?? address
            return RawBluetoothDevice(
                address: address,
                name: name,
                isConnected: device.isConnected(),
                isPaired: device.isPaired()
            )
        }
    }

    private func applySnapshot(pairedDevices: [RawBluetoothDevice], batteryEntries: [BluetoothBatteryReader.Entry]) {
        latestBatteryEntries = batteryEntries

        let mapped = pairedDevices.map { raw in
            let isActiveAudioRoute = audioDeviceNames.contains(where: { BluetoothNameMatcher.namesMatch($0, raw.name) })
            let battery = (raw.isConnected || isActiveAudioRoute)
                ? battery(for: raw, entries: batteryEntries)
                : nil
            let matchedUID = audioDeviceUIDs.first { key, _ in
                BluetoothNameMatcher.namesMatch(key, raw.name)
            }?.value
            let isAudioDevice = audioDeviceNames.contains(where: { BluetoothNameMatcher.namesMatch($0, raw.name) })

            return BluetoothDeviceInfo(
                id: BluetoothNameMatcher.normalizedAddress(raw.address),
                address: raw.address,
                name: raw.name,
                isConnected: raw.isConnected,
                isPaired: raw.isPaired,
                battery: battery,
                matchedAudioDeviceUID: matchedUID,
                isAudioDevice: isAudioDevice
            )
        }

        devices = mapped
        persistDevices(mapped)
    }

    private func battery(for raw: RawBluetoothDevice, entries: [BluetoothBatteryReader.Entry]) -> BluetoothBatteryReading? {
        let normalizedAddress = BluetoothNameMatcher.normalizedAddress(raw.address)

        if let match = entries.first(where: { entry in
            if let address = entry.address {
                return BluetoothNameMatcher.normalizedAddress(address) == normalizedAddress
            }
            return false
        }) {
            return match.reading
        }

        if let match = entries.first(where: { BluetoothNameMatcher.namesMatch($0.name, raw.name) }) {
            return match.reading
        }

        return nil
    }

    private func batteryReading(
        matchingName name: String,
        entries: [BluetoothBatteryReader.Entry]
    ) -> BluetoothBatteryReading? {
        entries.first(where: { BluetoothNameMatcher.namesMatch($0.name, name) })?.reading
    }

    private func persistDevices(_ devices: [BluetoothDeviceInfo]) {
        do {
            for device in devices {
                try persistence.upsertBluetoothDevice(device)
            }
        } catch {
            logger.error("Failed to persist Bluetooth devices: \(error.localizedDescription)")
        }
    }

    private static var isRunningUnderTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
