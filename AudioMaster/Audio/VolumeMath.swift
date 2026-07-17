import Foundation

enum VolumeMath {
    static let minDecibels: Float = -120
    static let maxDecibels: Float = 0
    /// Slider position 1.0 = 100%. Values above 1.0 boost per-app volume via software gain.
    static let maxSliderValue: Float = 2.0
    /// Volume change per arrow key press or keyboard shortcut step (5%).
    static let keyboardStep: Float = 0.05

    static func clampSliderValue(_ value: Float) -> Float {
        max(0, min(maxSliderValue, value))
    }

    static func sliderFillRatio(_ value: Double) -> Double {
        guard maxSliderValue > 0 else { return 0 }
        return value / Double(maxSliderValue)
    }

    static func sliderValue(fromNormalizedPosition position: Double) -> Double {
        max(0, min(Double(maxSliderValue), position * Double(maxSliderValue)))
    }

    static func displayPercent(_ sliderValue: Double) -> Int {
        Int((sliderValue * 100).rounded())
    }

    static func displayDecibels(_ sliderValue: Double) -> String {
        String(format: String(localized: "%+.1f dB"), linearToDecibels(Float(sliderValue)))
    }

    static func volumeLabel(for sliderValue: Double, showDecibels: Bool) -> String {
        let percent = displayPercent(sliderValue)
        guard showDecibels else {
            return String(format: String(localized: "%lld%%"), Int64(percent))
        }
        return String(format: String(localized: "%lld%% · %@"), Int64(percent), displayDecibels(sliderValue))
    }

    /// Maps linear slider value (0.0–1.0) to decibels.
    static func linearToDecibels(_ linear: Float) -> Float {
        guard linear > 0 else { return minDecibels }
        return 20 * log10(linear)
    }

    /// Maps decibels to linear gain (0.0–1.0).
    static func decibelsToLinear(_ decibels: Float) -> Float {
        guard decibels > minDecibels else { return 0 }
        return pow(10, decibels / 20)
    }

    /// Logarithmic slider mapping for human perception.
    static func sliderToGain(_ sliderValue: Float) -> Float {
        decibelsToLinear(linearToDecibels(sliderValue))
    }
}
