import Foundation

/// Peaking EQ biquad filter (Robert Bristow-Johnson Audio EQ Cookbook).
struct BiquadFilter {
    private(set) var b0: Float = 1
    private(set) var b1: Float = 0
    private(set) var b2: Float = 0
    private(set) var a1: Float = 0
    private(set) var a2: Float = 0

    private var z1: Float = 0
    private var z2: Float = 0

    mutating func configurePeakingEQ(
        sampleRate: Double,
        centerFrequency: Double,
        gainDecibels: Float,
        q: Float = 1.0
    ) {
        let a = pow(10.0, Double(gainDecibels) / 40.0)
        let omega = 2.0 * Double.pi * centerFrequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * Double(q))

        let a0 = 1.0 + alpha / a
        b0 = Float((1.0 + alpha * a) / a0)
        b1 = Float((-2.0 * cosOmega) / a0)
        b2 = Float((1.0 - alpha * a) / a0)
        a1 = Float((-2.0 * cosOmega) / a0)
        a2 = Float((1.0 - alpha / a) / a0)
    }

    mutating func resetState() {
        z1 = 0
        z2 = 0
    }

    mutating func process(_ input: Float) -> Float {
        let output = b0 * input + z1
        z1 = b1 * input - a1 * output + z2
        z2 = b2 * input - a2 * output
        return output
    }
}
