import Foundation

final class LoudnessNormalizer {
    static let maxGainDecibels: Float = 24

    private(set) var currentGain: Float = 1

    init(sampleRate: Double = 48_000) {}

    func update(settings: NormalizationSettings) {}

    func process(_ sample: Float) -> Float {
        sample
    }
}
