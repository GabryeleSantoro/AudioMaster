import Foundation

final class LoudnessNormalizer {
    static let maxGainDecibels: Float = 12

    private(set) var currentGain: Float = 1
    private let sampleRate: Double

    /// Direct Form I biquad section: `y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2]
    /// - a1*y[n-1] - a2*y[n-2]`. Input and output history are tracked in
    /// separate state variables (`x1`/`x2` vs `y1`/`y2`) — mixing them, or
    /// feeding numerator coefficients output history, is what made the
    /// previous implementation diverge to `±inf` within ~100 samples.
    private struct Biquad {
        var b0: Float
        var b1: Float
        var b2: Float
        var a1: Float
        var a2: Float

        private var x1: Float = 0
        private var x2: Float = 0
        private var y1: Float = 0
        private var y2: Float = 0

        init(b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
            self.b0 = b0
            self.b1 = b1
            self.b2 = b2
            self.a1 = a1
            self.a2 = a2
        }

        mutating func process(_ x0: Float) -> Float {
            let y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
            return y0
        }
    }

    // Frequency weighting filters (100Hz high-pass + 2kHz high-shelf boost),
    // a simplified stand-in for full ITU-R BS.1770-4 K-weighting.
    private var highPassFilter: Biquad
    private var shelfFilter: Biquad

    // LUFS measurement state: 400ms sliding-window mean-square, maintained via
    // a running sum so each `process(_:)` call is O(1) rather than re-summing
    // the whole window (this runs per-sample on the real-time audio path).
    private var measurementBuffer: [Float]
    private let measurementWindowSamples: Int
    private var bufferIndex = 0
    private var runningSumSquares: Float = 0

    private var isEnabled = false
    private var strength: Float = 1.0

    init(sampleRate: Double = 48_000) {
        self.sampleRate = sampleRate
        self.measurementWindowSamples = max(1, Int(0.4 * sampleRate))  // 400ms window
        self.measurementBuffer = Array(repeating: 0, count: measurementWindowSamples)

        // 100Hz high-pass, Q=0.707 (RBJ Audio Cookbook "High Pass Filter").
        self.highPassFilter = Self.makeHighPass(frequency: 100, q: 0.707, sampleRate: sampleRate)
        // 2kHz high-shelf, +4dB boost, Q=0.6 (RBJ Audio Cookbook "High Shelf").
        self.shelfFilter = Self.makeHighShelf(frequency: 2_000, gainDecibels: 4, q: 0.6, sampleRate: sampleRate)
    }

    private static func makeHighPass(frequency: Double, q: Double, sampleRate: Double) -> Biquad {
        let w0 = 2 * Double.pi * frequency / sampleRate
        let cosW0 = cos(w0)
        let alpha = sin(w0) / (2 * q)

        let b0 = (1 + cosW0) / 2
        let b1 = -(1 + cosW0)
        let b2 = (1 + cosW0) / 2
        let a0 = 1 + alpha
        let a1 = -2 * cosW0
        let a2 = 1 - alpha

        return Biquad(
            b0: Float(b0 / a0),
            b1: Float(b1 / a0),
            b2: Float(b2 / a0),
            a1: Float(a1 / a0),
            a2: Float(a2 / a0)
        )
    }

    private static func makeHighShelf(frequency: Double, gainDecibels: Double, q: Double, sampleRate: Double) -> Biquad {
        let w0 = 2 * Double.pi * frequency / sampleRate
        let cosW0 = cos(w0)
        let alpha = sin(w0) / (2 * q)
        let A = pow(10, gainDecibels / 40)
        let sqrtA = sqrt(A)

        let b0 = A * ((A + 1) + (A - 1) * cosW0 + 2 * sqrtA * alpha)
        let b1 = -2 * A * ((A - 1) + (A + 1) * cosW0)
        let b2 = A * ((A + 1) + (A - 1) * cosW0 - 2 * sqrtA * alpha)
        let a0 = (A + 1) - (A - 1) * cosW0 + 2 * sqrtA * alpha
        let a1 = 2 * ((A - 1) - (A + 1) * cosW0)
        let a2 = (A + 1) - (A - 1) * cosW0 - 2 * sqrtA * alpha

        return Biquad(
            b0: Float(b0 / a0),
            b1: Float(b1 / a0),
            b2: Float(b2 / a0),
            a1: Float(a1 / a0),
            a2: Float(a2 / a0)
        )
    }

    func update(settings: NormalizationSettings) {
        isEnabled = settings.isEnabled
        strength = Float(settings.strength)
    }

    func process(_ sample: Float) -> Float {
        guard isEnabled else { return sample }

        // Apply frequency weighting filters
        let filtered = applyFrequencyWeighting(sample)

        // Update the running mean-square sum for the 400ms sliding window.
        let squared = filtered * filtered
        runningSumSquares += squared - measurementBuffer[bufferIndex]
        runningSumSquares = max(0, runningSumSquares)  // guard against float drift
        measurementBuffer[bufferIndex] = squared
        bufferIndex = (bufferIndex + 1) % measurementWindowSamples

        // Calculate current gain based on measured loudness
        let measuredLoudness = calculateLoudness()
        currentGain = calculateGain(for: measuredLoudness)

        // Apply gain to original sample
        return sample * currentGain
    }

    private func applyFrequencyWeighting(_ sample: Float) -> Float {
        let highPassed = highPassFilter.process(sample)
        return shelfFilter.process(highPassed)
    }

    private func calculateLoudness() -> Float {
        let meanSquare = runningSumSquares / Float(measurementWindowSamples)
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

        let gainDb = (targetLoudness - measuredLoudness) * strength  // Apply strength multiplier
        let gainDbClamped = max(-Self.maxGainDecibels, min(Self.maxGainDecibels, gainDb))
        return pow(10, gainDbClamped / 20)  // Convert dB to linear gain
    }
}
