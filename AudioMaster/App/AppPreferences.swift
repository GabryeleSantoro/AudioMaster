import Foundation

enum AppPreferences {
    enum Keys {
        static let showDecibels = "showDecibels"
        static let volumeShortcutsEnabled = "volumeShortcutsEnabled"
        static let automaticUpdatesEnabled = "automaticUpdatesEnabled"
        static let lastAutomaticUpdateCheckAt = "lastAutomaticUpdateCheckAt"
        static let appearance = "appearance"
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

    static var lastAutomaticUpdateCheckAt: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastAutomaticUpdateCheckAt) as? Date }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Keys.lastAutomaticUpdateCheckAt)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.lastAutomaticUpdateCheckAt)
            }
        }
    }

    static var appearance: AppAppearance {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Keys.appearance),
                  let value = AppAppearance(rawValue: raw) else {
                return .system
            }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.appearance) }
    }

    static func resetToDefaults() {
        showDecibels = false
        volumeShortcutsEnabled = true
        automaticUpdatesEnabled = true
        appearance = .system
    }
}
