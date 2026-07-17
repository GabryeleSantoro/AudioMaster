import Foundation

final class LoudnessNormalizer {
    static let maxGainDecibels: Float = 12  // ✅ FIXED: was 24, corrected to 12

    private(set) var currentGain: Float = 1
    private let sampleRate: Double

    // Frequency weighting filter state
    private var highPassZ1: Float = 0  // 100Hz high-pass filter history
    private var highPassZ2: Float = 0
    private var shelfZ1: Float = 0     // 2kHz shelf filter history
    private var shelfZ2: Float = 0

    // LUFS measurement state
    private var measurementBuffer: [Float] = []
    private let measurementWindowSamples: Int
    private var bufferIndex = 0

    // Filter coefficients (computed once at init)
    private let highPassB0: Float
    private let highPassB1: Float
    private let highPassA1: Float

    private let shelfB0: Float
    private let shelfB1: Float
    private let shelfA1: Float

    private var isEnabled = false
    private var strength: Float = 1.0  // ✅ ADDED: Track strength parameter

    init(sampleRate: Double = 48_000) {
        self.sampleRate = sampleRate
        self.measurementWindowSamples = Int(0.4 * sampleRate)  // 400ms window
        self.measurementBuffer = Array(repeating: 0, count: measurementWindowSamples)

        // Calculate high-pass filter coefficients (100Hz, Q=0.707)
        let freq100Hz = Float(100 / sampleRate)
        let sqrt2Over2 = Float(0.707)
        let alpha = sin(.pi * freq100Hz) / (2 * sqrt2Over2)
        self.highPassB0 = (1 + cos(.pi * freq100Hz)) / 2
        self.highPassB1 = -(1 + cos(.pi * freq100Hz))
        self.highPassA1 = -2 * cos(.pi * freq100Hz) / (1 + alpha)

        // Calculate 2kHz shelf filter coefficients (boost +4dB, Q=0.6)
        let freq2kHz = Float(2000 / sampleRate)
        let shelfQ = Float(0.6)
        let shelfGain = Float(4)  // +4dB boost
        let A = pow(10, shelfGain / 40)
        let alpha2k = sin(.pi * freq2kHz) / (2 * shelfQ)
        self.shelfB0 = A * ((A + 1) - (A - 1) * cos(.pi * freq2kHz) + 2 * sqrt(A) * alpha2k)
        self.shelfB1 = 2 * A * ((A - 1) - (A + 1) * cos(.pi * freq2kHz))
        self.shelfA1 = -2 * sqrt(A) * alpha2k / ((A + 1) + (A - 1) * cos(.pi * freq2kHz) + 2 * sqrt(A) * alpha2k)
    }

    func update(settings: NormalizationSettings) {
        isEnabled = settings.isEnabled
        strength = Float(settings.strength)  // ✅ FIXED: Store strength parameter
    }

    func process(_ sample: Float) -> Float {
        guard isEnabled else { return sample }

        // Apply frequency weighting filters
        let filtered = applyFrequencyWeighting(sample)

        // Add to measurement buffer
        measurementBuffer[bufferIndex] = filtered * filtered  // Store squared for RMS
        bufferIndex = (bufferIndex + 1) % measurementWindowSamples

        // Calculate current gain based on measured loudness
        let measuredLoudness = calculateLoudness()
        currentGain = calculateGain(for: measuredLoudness)

        // Apply gain to original sample
        return sample * currentGain
    }

    private func applyFrequencyWeighting(_ sample: Float) -> Float {
        // Apply 100Hz high-pass filter
        let highPassed = highPassB0 * sample + highPassB1 * highPassZ1 - highPassA1 * highPassZ2
        highPassZ2 = highPassZ1
        highPassZ1 = highPassed  // ✅ FIXED: Store OUTPUT, not input

        // Apply 2kHz shelf filter
        let shelved = shelfB0 * highPassed + shelfB1 * shelfZ1 - shelfA1 * shelfZ2
        shelfZ2 = shelfZ1
        shelfZ1 = shelved  // ✅ FIXED: Store OUTPUT, not input

        return shelved
    }

    private func calculateLoudness() -> Float {
        let meanSquare = measurementBuffer.reduce(0, +) / Float(measurementWindowSamples)
        let rms = sqrt(max(0, meanSquare))
        let loudnessLUFS = 20 * log10(max(rms, 1e-7))  // Avoid log(0)
        return loudnessLUFS
    }

    private func calculateGain(for measuredLoudness: Float) -> Float {
        let targetLoudness: Float = -14  // LUFS
        let gateThreshold: Float = -70    // Below this, ignore (silence)

        // If measured loudness is below gate, don't adjust
        if measuredLoudness < gateThreshold {
            return 1.0
        }

        let gainDb = (targetLoudness - measuredLoudness) * strength  // ✅ FIXED: Apply strength multiplier
        let gainDbClamped = max(-Self.maxGainDecibels, min(Self.maxGainDecibels, gainDb))
        return pow(10, gainDbClamped / 20)  // Convert dB to linear gain
    }
}
