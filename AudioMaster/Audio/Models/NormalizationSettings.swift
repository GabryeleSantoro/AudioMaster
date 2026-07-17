import Foundation

struct NormalizationSettings: Codable, Equatable {
    var isEnabled: Bool
    var strength: Double

    init(isEnabled: Bool = false, strength: Double = 0.75) {
        self.isEnabled = isEnabled
        self.strength = strength
    }
}
