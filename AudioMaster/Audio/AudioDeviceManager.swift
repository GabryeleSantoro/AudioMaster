import Combine
import CoreAudio
import Foundation
import os.log

@MainActor
final class AudioDeviceManager: ObservableObject {
    @Published private(set) var outputDevices: [AudioDevice] = []
    @Published private(set) var inputDevices: [AudioDevice] = []
    @Published private(set) var defaultOutputDevice: AudioDevice?
    @Published private(set) var defaultInputDevice: AudioDevice?

    var onDevicesUpdated: (([AudioDevice]) -> Void)?

    private let persistence: PersistenceController
    private let logger = Logger(subsystem: "com.audiomaster.app", category: "AudioDeviceManager")
    private let refreshQueue = DispatchQueue(label: "com.audiomaster.audio.refresh", qos: .userInitiated)

    private var listenerContexts: [CoreAudioHelpers.ListenerContext] = []
    private var debounceTask: Task<Void, Never>?
    private var isMonitoring = false

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    deinit {
        debounceTask?.cancel()
    }

    // MARK: - Public API

    func refreshDevices() {
        refreshQueue.async { [weak self] in
            do {
                let snapshot = try Self.enumerateDevicesSnapshot()
                Task { @MainActor in
                    self?.applySnapshot(snapshot)
                }
            } catch {
                Task { @MainActor in
                    self?.logger.error("Device refresh failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func setDefaultOutputDevice(_ device: AudioDevice) throws {
        try CoreAudioHelpers.setDefaultDevice(id: device.coreAudioID, scope: .output)
        try persistence.markDeviceLastUsed(device)
        logger.info("Default output set to: \(device.name)")
        refreshDevices()
    }

    func setDefaultInputDevice(_ device: AudioDevice) throws {
        try CoreAudioHelpers.setDefaultDevice(id: device.coreAudioID, scope: .input)
        try persistence.markDeviceLastUsed(device)
        logger.info("Default input set to: \(device.name)")
        refreshDevices()
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let selectors: [UInt32] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice
        ]

        for selector in selectors {
            do {
                let context = try CoreAudioHelpers.addPropertyListener(selector: selector) { [weak self] in
                    Task { @MainActor in
                        self?.scheduleDebouncedRefresh()
                    }
                }
                listenerContexts.append(context)
            } catch {
                logger.error("Failed to add listener for \(selector): \(error.localizedDescription)")
            }
        }

        logger.info("Started audio device monitoring")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        let selectors: [UInt32] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice
        ]

        for (index, context) in listenerContexts.enumerated() where index < selectors.count {
            CoreAudioHelpers.removePropertyListener(selector: selectors[index], context: context)
        }
        listenerContexts.removeAll()
        debounceTask?.cancel()
        logger.info("Stopped audio device monitoring")
    }

    func logDeviceSummary() {
        let total = outputDevices.count + inputDevices.count
        logger.info("=== AudioMaster Device Summary ===")
        logger.info("Total devices: \(total) (\(self.outputDevices.count) output, \(self.inputDevices.count) input)")

        if let defaultOutput = defaultOutputDevice {
            logger.info("Default output: \(defaultOutput.name) [\(defaultOutput.type.displayName)]")
        }
        if let defaultInput = defaultInputDevice {
            logger.info("Default input: \(defaultInput.name) [\(defaultInput.type.displayName)]")
        }

        var typeCounts: [DeviceType: Int] = [:]
        for device in outputDevices + inputDevices {
            typeCounts[device.type, default: 0] += 1
        }
        for deviceType in DeviceType.allCases {
            if let count = typeCounts[deviceType], count > 0 {
                logger.info("  \(deviceType.displayName): \(count)")
            }
        }

        logger.info("Output devices:")
        for device in outputDevices {
            let marker = device.isSystemDefault ? " (default)" : ""
            logger.info("  • \(device.name) [\(device.type.displayName)]\(marker)")
        }

        logger.info("Input devices:")
        for device in inputDevices {
            let marker = device.isSystemDefault ? " (default)" : ""
            logger.info("  • \(device.name) [\(device.type.displayName)]\(marker)")
        }
        logger.info("==================================")
    }

    // MARK: - Private

    private struct DeviceSnapshot: Sendable {
        let outputs: [AudioDevice]
        let inputs: [AudioDevice]
        let defaultOutput: AudioDevice?
        let defaultInput: AudioDevice?
    }

    nonisolated private static func enumerateDevicesSnapshot() throws -> DeviceSnapshot {
        let deviceIDs = try CoreAudioHelpers.getAllDeviceIDs()
        let defaultInputID = try? CoreAudioHelpers.getDefaultDevice(scope: .input)
        let defaultOutputID = try? CoreAudioHelpers.getDefaultDevice(scope: .output)

        var outputs: [AudioDevice] = []
        var inputs: [AudioDevice] = []
        var defaultOutput: AudioDevice?
        var defaultInput: AudioDevice?

        for deviceID in deviceIDs {
            guard let device = CoreAudioHelpers.buildAudioDevice(
                id: deviceID,
                defaultInputID: defaultInputID,
                defaultOutputID: defaultOutputID
            ) else { continue }

            guard !CoreAudioHelpers.isInternalManagedDevice(name: device.name) else { continue }

            if device.isOutput {
                outputs.append(device)
                if device.coreAudioID == defaultOutputID {
                    defaultOutput = device
                }
            }

            if device.isInput {
                inputs.append(device)
                if device.coreAudioID == defaultInputID {
                    defaultInput = device
                }
            }
        }

        outputs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        inputs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return DeviceSnapshot(
            outputs: outputs,
            inputs: inputs,
            defaultOutput: defaultOutput,
            defaultInput: defaultInput
        )
    }

    private func applySnapshot(_ snapshot: DeviceSnapshot) {
        let previousOutputUIDs = Set(outputDevices.compactMap(\.deviceUID))
        let newOutputUIDs = Set(snapshot.outputs.compactMap(\.deviceUID))
        let removedUIDs = previousOutputUIDs.subtracting(newOutputUIDs)

        if !removedUIDs.isEmpty {
            logger.warning("Devices removed: \(removedUIDs.joined(separator: ", "))")
        }

        outputDevices = snapshot.outputs
        inputDevices = snapshot.inputs
        defaultOutputDevice = snapshot.defaultOutput
        defaultInputDevice = snapshot.defaultInput

        persistDevices(snapshot.outputs + snapshot.inputs)
        onDevicesUpdated?(snapshot.outputs + snapshot.inputs)
        logDeviceSummary()
    }

    private func persistDevices(_ devices: [AudioDevice]) {
        do {
            for device in devices {
                try persistence.upsertDevice(device)
            }
        } catch {
            logger.error("Failed to persist devices: \(error.localizedDescription)")
        }
    }

    private func scheduleDebouncedRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            refreshDevices()
        }
    }
}
