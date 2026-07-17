import Combine
import Foundation

@MainActor
final class NormalizationController: ObservableObject {
    @Published var isEnabled = false
    @Published var strength = 0.75

    init(defaults: UserDefaults = .standard) {}

    var settings: NormalizationSettings {
        NormalizationSettings(isEnabled: isEnabled, strength: strength)
    }

    func resetToDefaults() {
        isEnabled = false
        strength = 0.75
    }
}
