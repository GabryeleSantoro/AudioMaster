import Foundation

enum AppPreferences {
    enum Keys {
        static let showDecibels = "showDecibels"
        static let volumeShortcutsEnabled = "volumeShortcutsEnabled"
        static let automaticUpdatesEnabled = "automaticUpdatesEnabled"
    }

    static var showDecibels: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.showDecibels) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.showDecibels) }
    }

    static var volumeShortcutsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.volumeShortcutsEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.volumeShortcutsEnabled)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.volumeShortcutsEnabled) }
    }

    static var automaticUpdatesEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.automaticUpdatesEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.automaticUpdatesEnabled)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.automaticUpdatesEnabled) }
    }

    static func resetToDefaults() {
        showDecibels = false
        volumeShortcutsEnabled = true
        automaticUpdatesEnabled = true
    }
}
