import Combine
import Foundation

@MainActor
final class NormalizationController: ObservableObject {
    private enum Keys {
        static let enabled = "normalization.enabled"
        static let strength = "normalization.strength"
    }

    private let defaults: UserDefaults

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.enabled) }
    }

    @Published var strength: Double {
        didSet {
            let clamped = min(max(strength, 0.0), 1.0)
            if clamped != strength {
                strength = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.strength)
        }
    }

    var settings: NormalizationSettings {
        NormalizationSettings(isEnabled: isEnabled, strength: strength)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? false

        let stored = defaults.object(forKey: Keys.strength) as? Double ?? 0.75
        self.strength = min(max(stored, 0.0), 1.0)
    }

    func resetToDefaults() {
        isEnabled = false
        strength = 0.75
    }
}
