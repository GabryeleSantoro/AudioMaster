import AppKit
import Combine
import CoreAudio
import Foundation
import os.log

@MainActor
final class AppVolumeController: ObservableObject {
    @Published private(set) var apps: [AppVolumeEntry] = []
    @Published private(set) var errors: [pid_t: String] = [:]
    @Published private(set) var isProcessTapAvailable = false
    @Published private(set) var lastModifiedPID: pid_t?
    @Published var systemVolume: Double = 0.75

    let equalizerController: EqualizerController
    let normalizationController: NormalizationController

    private var gains: [pid_t: Float] = [:]
    private var muted: Set<pid_t> = []
    private var mixers: [pid_t: AppVolumeMixer] = [:]
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 2.0
    private var workspaceObservers: [NSObjectProtocol] = []
    private var defaultOutputListener: AudioObjectPropertyListenerBlock?
    private var equalizerCancellable: AnyCancellable?
    private var normalizationCancellable: AnyCancellable?
    private var activityCancellable: AnyCancellable?
    private var activityCoordinator: ResourceActivityCoordinator?
    private var eqRefreshTask: Task<Void, Never>?
    private var normalizationRefreshTask: Task<Void, Never>?
    private var cachedAudioPIDs: Set<pid_t> = []
    private var lastFullProcessScan: Date = .distantPast
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private let logger = Logger(subsystem: "com.audiomaster.app", category: "AppVolumeController")
    private let gainsDefaultsKey = "com.audiomaster.appVolumeGains"

    init(equalizerController: EqualizerController, normalizationController: NormalizationController) {
        self.equalizerController = equalizerController
        self.normalizationController = normalizationController
        if #available(macOS 14.2, *) {
            isProcessTapAvailable = true
        }
        loadSavedGains()
        refreshSystemVolume()
        observeEqualizerChanges()
        observeNormalizationChanges()
    }

    deinit {
        refreshTimer?.invalidate()
        eqRefreshTask?.cancel()
        normalizationRefreshTask?.cancel()
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        refresh()
        rescheduleRefreshTimer()
        if workspaceObservers.isEmpty {
            observeWorkspaceChanges()
        }
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

    func bind(activityCoordinator: ResourceActivityCoordinator) {
        self.activityCoordinator = activityCoordinator
        activityCancellable = activityCoordinator.$snapshot
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.rescheduleRefreshTimer()
                }
            }
        rescheduleRefreshTimer()
        notifyMixersChanged()
    }

    func notifyMixersChanged() {
        activityCoordinator?.setActiveMixerCount(mixers.count)
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
        objectWillChange.send()
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
        objectWillChange.send()
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

        let sorted = sortEntries(entries)
        if sorted != apps {
            apps = sorted
        }

        // Start mixers for apps that began playing with a non-default saved level or active EQ.
        for entry in sorted where entry.isPlayingAudio {
            if needsMixer(for: entry) {
                applyEffectiveGain(pid: entry.pid)
            }
        }
        notifyMixersChanged()
    }

    // MARK: - Private

    private func rescheduleRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        let snapshot = activityCoordinator?.snapshot ?? ResourceActivitySnapshot(
            uiVisibility: .hidden,
            activeMixerCount: mixers.count,
            hasConnectedBluetoothAudio: false,
            isSystemSleeping: false
        )
        refreshInterval = ResourceActivityPolicy.appVolumeRefreshInterval(for: snapshot)
        guard refreshInterval > 0 else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func buildAppList() -> [AppVolumeEntry] {
        let playingPIDs = audioPlayingPIDs()

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
                isPlayingAudio: playingPIDs.contains(pid)
            )
        }
    }

    private func audioPlayingPIDs() -> Set<pid_t> {
        let now = Date()
        let needsFullScan = now.timeIntervalSince(lastFullProcessScan) > 10 || cachedAudioPIDs.isEmpty
        guard needsFullScan,
              isProcessTapAvailable,
              let audioProcesses = try? AudioProcessList.all() else {
            return cachedAudioPIDs
        }

        lastFullProcessScan = now
        cachedAudioPIDs = Set(
            audioProcesses
                .filter { $0.pid != ownPID && $0.isRunning }
                .map(\.pid)
        )
        return cachedAudioPIDs
    }

    private func sortEntries(_ entries: [AppVolumeEntry]) -> [AppVolumeEntry] {
        entries.sorted { lhs, rhs in
            let lhsMixing = mixers[lhs.pid] != nil
            let rhsMixing = mixers[rhs.pid] != nil
            if lhsMixing != rhsMixing { return lhsMixing }
            if lhs.isPlayingAudio != rhs.isPlayingAudio { return lhs.isPlayingAudio }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func observeEqualizerChanges() {
        equalizerCancellable = equalizerController.objectWillChange.sink { [weak self] _ in
            self?.eqRefreshTask?.cancel()
            self?.eqRefreshTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                self?.refreshEqualizerOnActiveMixers()
            }
        }
    }

    private func refreshEqualizerOnActiveMixers() {
        guard #available(macOS 14.2, *) else { return }
        for (pid, mixer) in mixers {
            let bundleID = apps.first(where: { $0.pid == pid })?.bundleID
            mixer.updateEqualizer(equalizerController.effectiveSettings(for: bundleID))
        }
    }

    private func observeNormalizationChanges() {
        normalizationCancellable = normalizationController.objectWillChange.sink { [weak self] _ in
            self?.normalizationRefreshTask?.cancel()
            self?.normalizationRefreshTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }
                self?.refreshNormalizationOnActiveMixers()
            }
        }
    }

    private func refreshNormalizationOnActiveMixers() {
        guard #available(macOS 14.2, *) else { return }
        let settings = normalizationController.settings
        for (_, mixer) in mixers {
            mixer.updateNormalization(settings)
        }
    }

    private func needsMixer(for entry: AppVolumeEntry) -> Bool {
        if gains[entry.pid] != nil || muted.contains(entry.pid) {
            return true
        }
        if normalizationController.isEnabled {
            return true
        }
        return equalizerController.needsProcessing(for: entry.bundleID)
    }

    private func bundleID(for pid: pid_t) -> String? {
        apps.first(where: { $0.pid == pid })?.bundleID
    }

    private func isPlayingAudio(pid: pid_t) -> Bool {
        apps.first(where: { $0.pid == pid })?.isPlayingAudio ?? false
    }

    private func eqSettings(for pid: pid_t) -> EQBandSettings? {
        equalizerController.effectiveSettings(for: bundleID(for: pid))
    }

    private func observeWorkspaceChanges() {
        let center = NSWorkspace.shared.notificationCenter

        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        )

        workspaceObservers.append(
            center.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        )
    }

    private func applyEffectiveGain(pid: pid_t) {
        guard #available(macOS 14.2, *) else { return }

        let mixerCountBefore = mixers.count
        defer {
            if mixers.count != mixerCountBefore {
                notifyMixersChanged()
            }
        }

        errors[pid] = nil
        let effective = effectiveGain(pid: pid)

        if let mixer = mixers[pid] {
            if !needsProcessing(pid: pid) || !isPlayingAudio(pid: pid) {
                mixer.stop()
                mixers.removeValue(forKey: pid)
                return
            }
            mixer.setGain(effective)
            mixer.updateEqualizer(eqSettings(for: pid))
            mixer.updateNormalization(normalizationController.settings)
            return
        }

        guard needsProcessing(pid: pid), isPlayingAudio(pid: pid) else { return }

        let mixer = AppVolumeMixer(
            targetPID: pid,
            gain: effective,
            eqSettings: eqSettings(for: pid),
            normalizationSettings: normalizationController.settings
        )
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

    private func needsProcessing(pid: pid_t) -> Bool {
        effectiveGain(pid: pid) != 1.0 || eqSettings(for: pid) != nil || normalizationController.isEnabled
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
        notifyMixersChanged()
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
        notifyMixersChanged()
    }

    private func rebuildActiveMixers() {
        guard #available(macOS 14.2, *) else { return }

        let activePIDs = Array(mixers.keys)
        guard !activePIDs.isEmpty else { return }

        for pid in activePIDs {
            mixers[pid]?.stop()
            mixers.removeValue(forKey: pid)
            let mixer = AppVolumeMixer(
                targetPID: pid,
                gain: effectiveGain(pid: pid),
                eqSettings: eqSettings(for: pid),
                normalizationSettings: normalizationController.settings
            )
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

#if DEBUG
extension AppVolumeController {
    var currentRefreshIntervalForTesting: TimeInterval { refreshInterval }

    func applyRefreshPolicyForTesting() {
        rescheduleRefreshTimer()
    }

    func needsMixerForTesting(for entry: AppVolumeEntry) -> Bool {
        needsMixer(for: entry)
    }
}
#endif

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
