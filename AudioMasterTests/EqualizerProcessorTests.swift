import XCTest
@testable import AudioMaster

final class EqualizerProcessorTests: XCTestCase {
    private let sampleRate = 48_000.0

    /// Long enough for LoudnessNormalizer's gain to settle from its initial
    /// value, short enough to keep this test file fast given its O(n)-per-
    /// sample RMS scan over the (0.4s) measurement window.
    private let settleSeconds = 0.2

    /// Drives the processor with a sine wave and returns the peak absolute
    /// output over the final full cycle, which is a phase-independent proxy
    /// for the settled gain (a single trailing sample can land near a zero
    /// crossing regardless of gain, and would make the assertion flaky).
    private func drivePeakOutput(
        _ processor: EqualizerProcessor,
        amplitude: Float,
        seconds: Double,
        frequency: Double = 440
    ) -> Float {
        let total = Int(seconds * sampleRate)
        let samplesPerCycle = max(1, Int(sampleRate / frequency))
        var peak: Float = 0
        for n in 0..<total {
            let phase = 2.0 * Double.pi * frequency * Double(n) / sampleRate
            let input = amplitude * Float(sin(phase))
            let output = processor.process(sample: input)
            XCTAssertTrue(output.isFinite, "output must stay finite")
            if n >= total - samplesPerCycle {
                peak = max(peak, abs(output))
            }
        }
        return peak
    }

    func testNormalizationDisabledByDefaultPreservesExistingBehavior() {
        let processor = EqualizerProcessor(sampleRate: sampleRate)
        let input: Float = 0.5
        let output = processor.process(sample: input)
        XCTAssertEqual(output, input, accuracy: 0.0001)
    }

    /// Verifies the normalizer is actually wired into `process(sample:)` by
    /// comparing against an identical, disabled run: with the same input,
    /// enabling normalization must change the output. This intentionally
    /// does not assert a boost/cut direction or exact gain — that behavior
    /// belongs to LoudnessNormalizer and is covered by its own tests.
    func testEnablingNormalizationChangesOutputVersusDisabled() {
        let amplitude: Float = 0.02

        let disabledProcessor = EqualizerProcessor(sampleRate: sampleRate)
        let disabledPeak = drivePeakOutput(disabledProcessor, amplitude: amplitude, seconds: settleSeconds)

        let enabledProcessor = EqualizerProcessor(sampleRate: sampleRate)
        enabledProcessor.updateNormalization(settings: NormalizationSettings(isEnabled: true, strength: 1.0))
        let enabledPeak = drivePeakOutput(enabledProcessor, amplitude: amplitude, seconds: settleSeconds)

        XCTAssertEqual(disabledPeak, amplitude, accuracy: 0.0001, "disabled normalizer should be a passthrough")
        XCTAssertGreaterThan(
            abs(enabledPeak - disabledPeak),
            0.001,
            "enabling normalization should measurably change the processed output"
        )
    }

    func testNormalizationRunsAfterEqualizerGain() {
        let processor = EqualizerProcessor(sampleRate: sampleRate)

        var boosted = EQBandSettings(bandCount: 15)
        boosted.setGain(12, at: 0)
        processor.update(settings: boosted)
        processor.updateNormalization(settings: NormalizationSettings(isEnabled: true, strength: 1.0))

        // Feed a low-frequency tone matching the boosted band so the EQ raises
        // the signal fed into the normalizer; confirm the chain stays stable
        // and finite end-to-end (EQ -> trim -> normalizer).
        let peakOutput = drivePeakOutput(processor, amplitude: 0.02, seconds: settleSeconds, frequency: 60)
        XCTAssertTrue(peakOutput.isFinite)
        XCTAssertLessThanOrEqual(peakOutput, 1.0, "normalizer gain clamp should prevent runaway output")
    }

    func testUpdateNormalizationDisablingReturnsToEqualizerOnlyOutput() {
        let processor = EqualizerProcessor(sampleRate: sampleRate)
        processor.updateNormalization(settings: NormalizationSettings(isEnabled: true, strength: 1.0))
        _ = drivePeakOutput(processor, amplitude: 0.02, seconds: settleSeconds)

        processor.updateNormalization(settings: NormalizationSettings(isEnabled: false, strength: 1.0))
        let input: Float = 0.5
        let output = processor.process(sample: input)
        XCTAssertEqual(output, input, accuracy: 0.0001)
    }
}
