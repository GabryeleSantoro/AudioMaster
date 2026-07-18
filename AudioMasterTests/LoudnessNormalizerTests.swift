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

    // Test 1: Disabled passthrough
    func testDisabledNormalizerPassthrough() {
        let normalizer = makeNormalizer(enabled: false)
        let input: Float = 0.5
        let output = normalizer.process(input)
        XCTAssertEqual(output, input, accuracy: 0.0001)
    }

    // Test 2: White noise RMS measurement
    func testWhiteNoiseRMSMeasurement() {
        let normalizer = makeNormalizer()
        // Process quiet sine wave through the normalizer
        // The normalizer should properly measure and process the signal
        let gain = drive(normalizer, amplitude: 0.02, seconds: 2)
        // Gain should be positive and finite
        XCTAssertTrue(gain.isFinite && gain > 0)
    }

    // Test 2b: Quiet input should be boosted (gain > 1). This fails under the
    // old broken filter recursion, which diverges to non-finite values within
    // ~100 samples and always clamps to -12dB (currentGain ≈ 0.2512).
    func testQuietToneIsBoostedAboveUnityGain() {
        let normalizer = makeNormalizer(strength: 1.0)
        let gain = drive(normalizer, amplitude: 0.02, seconds: 1.5, frequency: 1_000)
        XCTAssertTrue(gain.isFinite)
        XCTAssertGreaterThan(gain, 1.0, "quiet signal should be boosted toward target loudness")
    }

    // Test 2c: Loud input should be attenuated (gain < 1) — the opposite
    // direction from the quiet case, confirming the sign of the gain
    // calculation (not just that it settles to some clamped constant).
    func testLoudToneIsAttenuatedBelowUnityGain() {
        let normalizer = makeNormalizer(strength: 1.0)
        let gain = drive(normalizer, amplitude: 0.5, seconds: 1.5, frequency: 1_000)
        XCTAssertTrue(gain.isFinite)
        XCTAssertLessThan(gain, 1.0, "loud signal should be attenuated toward target loudness")
        XCTAssertGreaterThan(gain, 0.0)
    }

    // Test 3: Silence gating
    func testGatingBelowThreshold() {
        let normalizer = makeNormalizer()
        // Process silence which should not be adjusted
        let gain = drive(normalizer, amplitude: 0.0, seconds: 2)
        // Gain should remain at 1.0 (no adjustment) because silence is gated
        XCTAssertEqual(gain, 1.0, accuracy: 0.05)
    }

    // Test 4: Gain clamping (upper bound)
    func testGainClamping() {
        let normalizer = makeNormalizer()
        // Very quiet signal that would need extreme gain but should be clamped
        let gain = drive(normalizer, amplitude: 0.0015, seconds: 4)
        // Gain should be clamped at +12 dB. NOTE: `12 / 20` must not be
        // computed as an Int (it previously truncated to 0, silently
        // widening this assertion to `gain <= 1.1`); this only went
        // unnoticed because the old broken filter always clamped to -12dB
        // regardless of input, so the assertion passed vacuously.
        let maxGainLinear = pow(10, Float(12) / 20)  // ≈ 3.98
        XCTAssertLessThanOrEqual(gain, maxGainLinear + 0.1)
    }

    // Test 5: Gain clamping (lower bound) — mirrors testGainClamping but for
    // a very loud signal that would otherwise need more than -12dB of cut.
    func testGainClampingLowerBound() {
        let normalizer = makeNormalizer()
        let gain = drive(normalizer, amplitude: 0.98, seconds: 4)
        let minGainLinear = pow(10, Float(-12) / 20)  // ≈ 0.2512
        XCTAssertGreaterThanOrEqual(gain, minGainLinear - 0.05)
        XCTAssertLessThan(gain, 1.0)
    }

    // Test 6: Filters stay finite under sustained noise-like input, not just
    // pure tones — guards against instability that only shows up with a
    // broader spectral content than a single sine.
    func testFiltersRemainStableUnderNoise() {
        let normalizer = makeNormalizer()
        var generator = SystemRandomNumberGenerator()
        let total = Int(2.0 * sampleRate)
        for _ in 0..<total {
            let sample = Float.random(in: -0.3...0.3, using: &generator)
            let output = normalizer.process(sample)
            XCTAssertTrue(output.isFinite, "output must stay finite for noise input")
        }
        XCTAssertTrue(normalizer.currentGain.isFinite)
        XCTAssertGreaterThan(normalizer.currentGain, 0)
    }
}
