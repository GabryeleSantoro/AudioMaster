import XCTest
@testable import AudioMaster

final class LoudnessNormalizerTests: XCTestCase {
    private let sampleRate = 48_000.0

    /// Feed a constant-amplitude sine for the given duration and return the
    /// gain the normalizer has settled on.
    @discardableResult
    private func drive(
        _ normalizer: LoudnessNormalizer,
        amplitude: Float,
        seconds: Double,
        frequency: Double = 440
    ) -> Float {
        let total = Int(seconds * sampleRate)
        var lastOutputs: [Float] = []
        for n in 0..<total {
            let phase = 2.0 * Double.pi * frequency * Double(n) / sampleRate
            let input = amplitude * Float(sin(phase))
            let output = normalizer.process(input)
            XCTAssertTrue(output.isFinite, "output must stay finite")
            if n >= total - 256 { lastOutputs.append(output) }
        }
        _ = lastOutputs
        return normalizer.currentGain
    }

    private func makeNormalizer(strength: Double = 1.0, enabled: Bool = true) -> LoudnessNormalizer {
        let normalizer = LoudnessNormalizer(sampleRate: sampleRate)
        normalizer.update(settings: NormalizationSettings(isEnabled: enabled, strength: strength))
        return normalizer
    }

    func testLoudSignalIsAttenuated() {
        let normalizer = makeNormalizer()
        let gain = drive(normalizer, amplitude: 0.9, seconds: 3)
        XCTAssertLessThan(gain, 1.0, "loud signal should be turned down")
    }

    func testQuietSignalIsBoosted() {
        let normalizer = makeNormalizer()
        let gain = drive(normalizer, amplitude: 0.03, seconds: 3)
        XCTAssertGreaterThan(gain, 1.0, "quiet signal should be brought up")
    }

    func testGainNeverExceedsConfiguredMax() {
        let normalizer = makeNormalizer()
        // Very quiet but above the silence gate: raw gain would be enormous.
        let gain = drive(normalizer, amplitude: 0.0015, seconds: 4)
        let maxLinear = powf(10, LoudnessNormalizer.maxGainDecibels / 20)
        XCTAssertLessThanOrEqual(gain, maxLinear + 0.01)
    }

    func testSilenceDoesNotRunAwayBoosting() {
        let normalizer = makeNormalizer()
        let gain = drive(normalizer, amplitude: 0.0, seconds: 2)
        XCTAssertEqual(gain, 1.0, accuracy: 0.05, "silence should leave gain near unity")
    }

    func testDisabledIsPassthrough() {
        let normalizer = makeNormalizer(enabled: false)
        for value: Float in [0.1, 0.5, -0.7, 0.9] {
            XCTAssertEqual(normalizer.process(value), value, accuracy: 0.0001)
        }
    }

    func testZeroStrengthLeavesSignalUnchanged() {
        let normalizer = makeNormalizer(strength: 0)
        let gain = drive(normalizer, amplitude: 0.9, seconds: 1)
        XCTAssertEqual(gain, 1.0, accuracy: 0.01)
    }
}
