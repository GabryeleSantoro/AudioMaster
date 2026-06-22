import AppKit
import Combine
import CoreAudio
import Foundation
import os.log

struct AppVolumeEntry: Identifiable, Equatable {
    var id: pid_t { pid }

    let pid: pid_t
    let bundleID: String?
    let name: String
    let icon: NSImage?
    /// Whether Core Audio reports this process is currently producing output.
    let isPlayingAudio: Bool

    var displayName: String { name }
}

@MainActor
final class AppVolumeController: ObservableObject {
    @Published private(set) var apps: [AppVolumeEntry] = []
    @Published private(set) var errors: [pid_t: String] = [:]
    @Published private(set) var isProcessTapAvailable = false
    @Published private(set) var lastModifiedPID: pid_t?
    @Published var systemVolume: Double = 0.75

    private var gains: [pid_t: Float] = [:]
    private var muted: Set<pid_t> = []
    private var mixers: [pid_t: AppVolumeMixer] = [:]
    private var refreshTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var defaultOutputListener: AudioObjectPropertyListenerBlock?
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let logger = Logger(subsystem: "com.audiomaster.app", category: "AppVolumeController")
    private let gainsDefaultsKey = "com.audiomaster.appVolumeGains"

    init() {
        if #available(macOS 14.2, *) {
            isProcessTapAvailable = true
        }
        loadSavedGains()
        refreshSystemVolume()
    }

    deinit {
        refreshTimer?.invalidate()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        observeWorkspaceChanges()
        if #available(macOS 14.2, *) {
            startListeningForDefaultOutputChanges()
        }
    }

    func stopMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        if #available(macOS 14.2, *) {
            stopListeningForDefaultOutputChanges()
        }
        releaseAllMixers()
    }

    // MARK: - Public API

    func gain(for pid: pid_t) -> Float {
        if muted.contains(pid) { return 0 }
        return Self.gainCurve(gains[pid] ?? 1.0)
    }

    func sliderValue(for pid: pid_t) -> Double {
        Double(gains[pid] ?? 1.0)
    }

    func isMuted(pid: pid_t) -> Bool {
        muted.contains(pid)
    }

    func isActive(pid: pid_t) -> Bool {
        mixers[pid] != nil
    }

    func setGain(pid: pid_t, gain: Float) {
        gains[pid] = VolumeMath.clampSliderValue(gain)
        lastModifiedPID = pid
        saveGain(for: pid)
        if isPlayingAudio(pid: pid) {
            applyEffectiveGain(pid: pid)
        }
    }

    func toggleMute(pid: pid_t) {
        if muted.contains(pid) {
            muted.remove(pid)
        } else {
            muted.insert(pid)
        }
        lastModifiedPID = pid
        if isPlayingAudio(pid: pid) {
            applyEffectiveGain(pid: pid)
        }
    }

    func increaseLastModifiedVolume() {
        adjustLastModifiedVolume(by: VolumeMath.keyboardStep)
    }

    func decreaseLastModifiedVolume() {
        adjustLastModifiedVolume(by: -VolumeMath.keyboardStep)
    }

    func lastModifiedAppName() -> String? {
        guard let pid = targetPIDForKeyboardShortcuts() else { return nil }
        return apps.first(where: { $0.pid == pid })?.displayName
    }

    func adjustLastModifiedVolume(by delta: Float) {
        guard let pid = targetPIDForKeyboardShortcuts() else { return }
        if muted.contains(pid) {
            muted.remove(pid)
        }
        let current = gains[pid] ?? 1.0
        setGain(pid: pid, gain: current + delta)
    }

    private func targetPIDForKeyboardShortcuts() -> pid_t? {
        if let pid = lastModifiedPID, apps.contains(where: { $0.pid == pid }) {
            return pid
        }
        return apps.first(where: \.isPlayingAudio)?.pid ?? apps.first?.pid
    }

    func setSystemVolume(_ value: Double) {
        let clamped = max(0, min(1, value))
        systemVolume = clamped
        do {
            try CoreAudioHelpers.setOutputVolume(Float(clamped))
        } catch {
            logger.error("Failed to set system volume: \(error.localizedDescription)")
        }
    }

    func refreshSystemVolume() {
        do {
            systemVolume = Double(try CoreAudioHelpers.getOutputVolume())
        } catch {
            logger.debug("Could not read system volume: \(error.localizedDescription)")
        }
    }

    // MARK: - Refresh

    func refresh() {
        pruneDeadProcesses()

        let entries = buildAppList()
        applySavedGains(to: entries)

        apps = entries.sorted { lhs, rhs in
            let lhsMixing = mixers[lhs.pid] != nil
            let rhsMixing = mixers[rhs.pid] != nil
            if lhsMixing != rhsMixing { return lhsMixing }
            if lhs.isPlayingAudio != rhs.isPlayingAudio { return lhs.isPlayingAudio }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        // Start mixers for apps that began playing with a non-default saved level.
        for entry in apps where entry.isPlayingAudio {
            if gains[entry.pid] != nil || muted.contains(entry.pid) {
                applyEffectiveGain(pid: entry.pid)
            }
        }
    }

    // MARK: - Private

    private func buildAppList() -> [AppVolumeEntry] {
        var audioStateByPID: [pid_t: Bool] = [:]

        if isProcessTapAvailable, let audioProcesses = try? AudioProcessList.all() {
            for process in audioProcesses where process.pid != ownPID {
                audioStateByPID[process.pid] = process.isRunning
            }
        }

        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular &&
            app.bundleIdentifier != nil &&
            app.processIdentifier != ownPID &&
            app.localizedName != nil
        }

        return runningApps.map { app in
            let pid = app.processIdentifier
            return AppVolumeEntry(
                pid: pid,
                bundleID: app.bundleIdentifier,
                name: app.localizedName ?? app.bundleIdentifier ?? String(localized: "Unknown"),
                icon: app.icon,
                isPlayingAudio: audioStateByPID[pid] ?? false
            )
        }
    }

    private func isPlayingAudio(pid: pid_t) -> Bool {
        apps.first(where: { $0.pid == pid })?.isPlayingAudio ?? false
    }

    private func observeWorkspaceChanges() {
        let center = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        )

        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        )
    }

    private func applyEffectiveGain(pid: pid_t) {
        guard #available(macOS 14.2, *) else { return }

        errors[pid] = nil
        let effective = effectiveGain(pid: pid)

        if let mixer = mixers[pid] {
            mixer.setGain(effective)
            return
        }

        guard effective != 1.0, isPlayingAudio(pid: pid) else { return }

        let mixer = AppVolumeMixer(targetPID: pid, gain: effective)
        do {
            try mixer.start()
            mixers[pid] = mixer
        } catch {
            errors[pid] = describe(error)
            gains[pid] = 1.0
            muted.remove(pid)
            logger.error("Failed to start mixer for pid \(pid): \(error.localizedDescription)")
        }
    }

    private func effectiveGain(pid: pid_t) -> Float {
        muted.contains(pid) ? 0 : Self.gainCurve(gains[pid] ?? 1.0)
    }

    private static func gainCurve(_ position: Float) -> Float {
        let value = max(0, position)
        if value >= 1.0 { return value }
        let curve = expf(4.605 * value) / 100.0
        return value < 0.1 ? curve * (value / 0.1) : curve
    }

    private func pruneDeadProcesses() {
        let tracked = Set(mixers.keys)
            .union(gains.keys)
            .union(muted)
            .union(errors.keys)

        for pid in tracked where !isProcessAlive(pid) {
            mixers[pid]?.stop()
            mixers.removeValue(forKey: pid)
            gains.removeValue(forKey: pid)
            muted.remove(pid)
            errors.removeValue(forKey: pid)
        }
    }

    private func isProcessAlive(_ pid: pid_t) -> Bool {
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    private func releaseAllMixers() {
        for (_, mixer) in mixers {
            mixer.stop()
        }
        mixers.removeAll()
    }

    private func rebuildActiveMixers() {
        guard #available(macOS 14.2, *) else { return }

        let activePIDs = Array(mixers.keys)
        guard !activePIDs.isEmpty else { return }

        for pid in activePIDs {
            mixers[pid]?.stop()
            mixers.removeValue(forKey: pid)
            let mixer = AppVolumeMixer(targetPID: pid, gain: effectiveGain(pid: pid))
            do {
                try mixer.start()
                mixers[pid] = mixer
            } catch {
                errors[pid] = describe(error)
            }
        }
    }

    @available(macOS 14.2, *)
    private func startListeningForDefaultOutputChanges() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.rebuildActiveMixers()
                self?.refreshSystemVolume()
            }
        }

        defaultOutputListener = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            block
        )
    }

    @available(macOS 14.2, *)
    private func stopListeningForDefaultOutputChanges() {
        guard let block = defaultOutputListener else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            block
        )
        defaultOutputListener = nil
    }

    private func saveGain(for pid: pid_t) {
        guard let bundleID = apps.first(where: { $0.pid == pid })?.bundleID else { return }
        var saved = UserDefaults.standard.dictionary(forKey: gainsDefaultsKey) as? [String: Float] ?? [:]
        saved[bundleID] = gains[pid]
        UserDefaults.standard.set(saved, forKey: gainsDefaultsKey)
    }

    private func loadSavedGains() {
        guard let saved = UserDefaults.standard.dictionary(forKey: gainsDefaultsKey) as? [String: Float] else {
            return
        }
        savedGainsByBundleID = saved
    }

    private var savedGainsByBundleID: [String: Float] = [:]

    private func applySavedGains(to entries: [AppVolumeEntry]) {
        for entry in entries {
            guard gains[entry.pid] == nil,
                  let bundleID = entry.bundleID,
                  let saved = savedGainsByBundleID[bundleID] else { continue }
            gains[entry.pid] = saved
        }
    }

    private func describe(_ error: Error) -> String {
        if let tapError = error as? ProcessTapError {
            switch tapError.status {
            case 1852797029:
                return String(localized: "Grant Audio Capture in System Settings → Privacy & Security")
            default:
                return tapError.description
            }
        }
        return error.localizedDescription
    }
}

// Backward compatibility for views still referencing `processes`.
extension AppVolumeController {
    var processes: [AudioProcessInfo] {
        apps.map { entry in
            AudioProcessInfo(
                audioObjectID: 0,
                pid: entry.pid,
                bundleID: entry.bundleID,
                executable: nil,
                isRunning: entry.isPlayingAudio
            )
        }
    }
}
