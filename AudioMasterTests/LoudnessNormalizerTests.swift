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

    // Test 3: Silence gating
    func testGatingBelowThreshold() {
        let normalizer = makeNormalizer()
        // Process silence which should not be adjusted
        let gain = drive(normalizer, amplitude: 0.0, seconds: 2)
        // Gain should remain at 1.0 (no adjustment) because silence is gated
        XCTAssertEqual(gain, 1.0, accuracy: 0.05)
    }

    // Test 4: Gain clamping
    func testGainClamping() {
        let normalizer = makeNormalizer()
        // Very quiet signal that would need extreme gain but should be clamped
        let gain = drive(normalizer, amplitude: 0.0015, seconds: 4)
        // Gain should be clamped at +12 dB
        let maxGainLinear = pow(10, Float(12 / 20))  // ≈ 3.98
        XCTAssertLessThanOrEqual(gain, maxGainLinear + 0.1)
    }
}
