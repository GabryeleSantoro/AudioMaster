import Combine
import Foundation

@MainActor
final class EqualizerController: ObservableObject {
    @Published var globalEnabled = false {
        didSet { saveGlobalEnabled() }
    }
    @Published var bandCount = EQBandLayout.defaultBandCount {
        didSet {
            let clamped = EQBandLayout.clampedBandCount(bandCount)
            if bandCount != clamped {
                bandCount = clamped
                return
            }
            applyBandCountChange()
            saveBandCount()
        }
    }
    @Published var globalBands = EQBandSettings.flat {
        didSet { saveGlobalBands() }
    }
    @Published var perAppFeatureEnabled = false {
        didSet { savePerAppFeatureEnabled() }
    }

    private var perAppSettingsByBundleID: [String: PerAppEQSettings] = [:]
    private let globalEnabledKey = "com.audiomaster.eq.globalEnabled"
    private let bandCountKey = "com.audiomaster.eq.bandCount"
    private let globalBandsKey = "com.audiomaster.eq.globalBands"
    private let perAppFeatureKey = "com.audiomaster.eq.perAppFeatureEnabled"
    private let perAppSettingsKey = "com.audiomaster.eq.perAppSettings"

    init() {
        load()
        syncBandCountAcrossSettings()
    }

    // MARK: - Global

    func applyPreset(_ preset: EQPreset) {
        globalBands = preset.settings(bandCount: bandCount)
    }

    func resetGlobal() {
        globalBands = EQBandSettings(bandCount: bandCount)
    }

    func setGlobalGain(_ gain: Float, at index: Int) {
        var updated = globalBands
        updated.setGain(gain, at: index)
        globalBands = updated
    }

    var isGlobalActive: Bool {
        globalEnabled && !globalBands.isFlat
    }

    // MARK: - Per App

    func perAppSettings(for bundleID: String?) -> PerAppEQSettings {
        guard let bundleID else { return PerAppEQSettings(bands: EQBandSettings(bandCount: bandCount)) }
        return perAppSettingsByBundleID[bundleID]
            ?? PerAppEQSettings(bands: EQBandSettings(bandCount: bandCount))
    }

    func isPerAppEnabled(for bundleID: String?) -> Bool {
        perAppSettings(for: bundleID).isEnabled
    }

    func setPerAppEnabled(_ enabled: Bool, bundleID: String?) {
        guard let bundleID else { return }
        var settings = perAppSettings(for: bundleID)
        settings.isEnabled = enabled
        perAppSettingsByBundleID[bundleID] = settings
        savePerAppSettings()
        objectWillChange.send()
    }

    func setPerAppGain(_ gain: Float, at index: Int, bundleID: String?) {
        guard let bundleID else { return }
        var settings = perAppSettings(for: bundleID)
        settings.bands.setGain(gain, at: index)
        perAppSettingsByBundleID[bundleID] = settings
        savePerAppSettings()
        objectWillChange.send()
    }

    func setPerAppBands(_ bands: EQBandSettings, bundleID: String?) {
        guard let bundleID else { return }
        var settings = perAppSettings(for: bundleID)
        settings.bands = bands
        perAppSettingsByBundleID[bundleID] = settings
        savePerAppSettings()
        objectWillChange.send()
    }

    func setPerAppBandCount(_ count: Int, bundleID: String?) {
        guard let bundleID else { return }
        var settings = perAppSettings(for: bundleID)
        settings.bands = settings.bands.resized(to: count)
        perAppSettingsByBundleID[bundleID] = settings
        savePerAppSettings()
        objectWillChange.send()
    }

    func applyPerAppPreset(_ preset: EQPreset, bundleID: String?) {
        guard let bundleID else { return }
        var settings = perAppSettings(for: bundleID)
        settings.bands = preset.settings(bandCount: settings.bands.bandCount)
        perAppSettingsByBundleID[bundleID] = settings
        savePerAppSettings()
        objectWillChange.send()
    }

    func resetPerApp(bundleID: String?) {
        guard let bundleID else { return }
        var settings = perAppSettings(for: bundleID)
        settings.bands = EQBandSettings(bandCount: settings.bands.bandCount)
        perAppSettingsByBundleID[bundleID] = settings
        savePerAppSettings()
        objectWillChange.send()
    }

    func effectiveSettings(for bundleID: String?) -> EQBandSettings? {
        if perAppFeatureEnabled,
           let bundleID,
           perAppSettings(for: bundleID).isActive {
            return perAppSettings(for: bundleID).bands
        }
        if isGlobalActive {
            return globalBands
        }
        return nil
    }

    func needsProcessing(for bundleID: String?) -> Bool {
        effectiveSettings(for: bundleID) != nil
    }

    // MARK: - Reset

    func resetToDefaults() {
        globalEnabled = false
        bandCount = EQBandLayout.defaultBandCount
        globalBands = EQBandSettings(bandCount: bandCount)
        perAppFeatureEnabled = false
        perAppSettingsByBundleID = [:]
        saveGlobalEnabled()
        saveBandCount()
        saveGlobalBands()
        savePerAppFeatureEnabled()
        savePerAppSettings()
    }

    // MARK: - Persistence

    private func load() {
        globalEnabled = UserDefaults.standard.bool(forKey: globalEnabledKey)
        let storedBandCount = UserDefaults.standard.integer(forKey: bandCountKey)
        if storedBandCount >= EQBandLayout.minBandCount {
            bandCount = EQBandLayout.clampedBandCount(storedBandCount)
        }
        if let data = UserDefaults.standard.data(forKey: globalBandsKey),
           let decoded = try? JSONDecoder().decode(EQBandSettings.self, from: data) {
            globalBands = decoded.resized(to: bandCount)
        } else {
            globalBands = EQBandSettings(bandCount: bandCount)
        }
        perAppFeatureEnabled = UserDefaults.standard.bool(forKey: perAppFeatureKey)
        if let data = UserDefaults.standard.data(forKey: perAppSettingsKey),
           let decoded = try? JSONDecoder().decode([String: PerAppEQSettings].self, from: data) {
            perAppSettingsByBundleID = decoded
        }
        syncBandCountAcrossSettings()
    }

    private func applyBandCountChange() {
        globalBands = globalBands.resized(to: bandCount)
        saveGlobalBands()
        objectWillChange.send()
    }

    private func syncBandCountAcrossSettings() {
        if globalBands.bandCount != bandCount {
            globalBands = globalBands.resized(to: bandCount)
        }
    }

    private func saveGlobalEnabled() {
        UserDefaults.standard.set(globalEnabled, forKey: globalEnabledKey)
    }

    private func saveBandCount() {
        UserDefaults.standard.set(bandCount, forKey: bandCountKey)
    }

    private func saveGlobalBands() {
        if let data = try? JSONEncoder().encode(globalBands) {
            UserDefaults.standard.set(data, forKey: globalBandsKey)
        }
    }

    private func savePerAppFeatureEnabled() {
        UserDefaults.standard.set(perAppFeatureEnabled, forKey: perAppFeatureKey)
    }

    private func savePerAppSettings() {
        if let data = try? JSONEncoder().encode(perAppSettingsByBundleID) {
            UserDefaults.standard.set(data, forKey: perAppSettingsKey)
        }
    }
}
