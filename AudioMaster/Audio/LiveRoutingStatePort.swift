import Foundation
import OSLog

/// Live `RoutingStatePort` backed by the real audio managers. Reads the current
/// setup from them and pushes a captured setup back, skipping anything that is no
/// longer available (e.g. an unplugged device or a quit app).
@MainActor
final class LiveRoutingStatePort: RoutingStatePort {
    private let deviceManager: AudioDeviceManager
    private let appVolumeController: AppVolumeController
    private let equalizerController: EqualizerController
    private let normalizationController: NormalizationController
    private let logger = Logger(subsystem: "com.audiomaster.app", category: "RoutingPresets")

    init(
        deviceManager: AudioDeviceManager,
        appVolumeController: AppVolumeController,
        equalizerController: EqualizerController,
        normalizationController: NormalizationController
    ) {
        self.deviceManager = deviceManager
        self.appVolumeController = appVolumeController
        self.equalizerController = equalizerController
        self.normalizationController = normalizationController
    }

    func captureSnapshot() -> RoutingSnapshot {
        let output = deviceManager.defaultOutputDevice

        var appVolumes: [String: AppAudioState] = [:]
        for entry in appVolumeController.apps {
            guard let bundleID = entry.bundleID else { continue }
            let gain = Float(appVolumeController.sliderValue(for: entry.pid))
            let muted = appVolumeController.isMuted(pid: entry.pid)
            // Only capture apps the user actually customised, so applying a preset
            // leaves untouched apps alone instead of forcing them to unity.
            guard muted || abs(gain - 1.0) > 0.001 else { continue }
            appVolumes[bundleID] = AppAudioState(gain: gain, muted: muted)
        }

        return RoutingSnapshot(
            outputDeviceUID: output?.deviceUID,
            outputDeviceName: output?.name,
            masterVolume: appVolumeController.systemVolume,
            appVolumes: appVolumes,
            equalizer: EQSnapshot(
                enabled: equalizerController.globalEnabled,
                bands: equalizerController.globalBands
            ),
            normalizationEnabled: normalizationController.isEnabled
        )
    }

    func apply(_ snapshot: RoutingSnapshot) {
        applyOutputDevice(snapshot)

        if let master = snapshot.masterVolume {
            appVolumeController.setSystemVolume(master)
        }

        applyAppVolumes(snapshot.appVolumes)

        if let equalizer = snapshot.equalizer {
            equalizerController.bandCount = equalizer.bands.bandCount
            equalizerController.globalBands = equalizer.bands
            equalizerController.globalEnabled = equalizer.enabled
        }

        if let enabled = snapshot.normalizationEnabled {
            normalizationController.isEnabled = enabled
        }
    }

    private func applyOutputDevice(_ snapshot: RoutingSnapshot) {
        guard let uid = snapshot.outputDeviceUID else { return }
        guard let device = deviceManager.outputDevices.first(where: { $0.deviceUID == uid }) else {
            logger.info("Routing preset output device not connected; leaving current device")
            return
        }
        do {
            try deviceManager.setDefaultOutputDevice(device)
        } catch {
            logger.error("Failed to switch output device: \(error.localizedDescription)")
        }
    }

    private func applyAppVolumes(_ appVolumes: [String: AppAudioState]) {
        for (bundleID, state) in appVolumes {
            guard let pid = appVolumeController.apps.first(where: { $0.bundleID == bundleID })?.pid else { continue }
            appVolumeController.setGain(pid: pid, gain: state.gain)
            if appVolumeController.isMuted(pid: pid) != state.muted {
                appVolumeController.toggleMute(pid: pid)
            }
        }
    }
}
