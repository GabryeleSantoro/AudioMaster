import Foundation

enum EQBandLayout {
    static let minBandCount = 15
    static let maxBandCount = 31
    static let defaultBandCount = EQBandCountPreset.standard.bandCount

    static let minFrequency: Double = 20
    static let maxFrequency: Double = 20_000

    static var presetBandCounts: [Int] {
        EQBandCountPreset.allCases.map(\.bandCount)
    }

    static func clampedBandCount(_ count: Int) -> Int {
        if EQBandCountPreset(bandCount: count) != nil {
            return count
        }
        return EQBandCountPreset.allCases.min(by: {
            abs($0.bandCount - count) < abs($1.bandCount - count)
        })?.bandCount ?? defaultBandCount
    }

    static func centerFrequencies(bandCount: Int) -> [Double] {
        let count = clampedBandCount(bandCount)
        guard count > 1 else { return [sqrt(minFrequency * maxFrequency)] }
        return (0..<count).map { index in
            let ratio = Double(index) / Double(count - 1)
            return minFrequency * pow(maxFrequency / minFrequency, ratio)
        }
    }

    static func formatFrequency(_ hz: Double) -> String {
        if hz >= 1_000 {
            let kHz = hz / 1_000
            if kHz >= 10 { return String(format: "%.0fk", kHz) }
            if abs(kHz - kHz.rounded()) < 0.05 { return String(format: "%.0fk", kHz) }
            return String(format: "%.1fk", kHz)
        }
        return String(format: "%.0f", hz)
    }

    static func interpolateGain(
        at frequency: Double,
        frequencies: [Double],
        gains: [Float]
    ) -> Float {
        guard !frequencies.isEmpty, !gains.isEmpty else { return 0 }
        guard frequencies.count == gains.count else { return 0 }

        if frequency <= frequencies[0] { return gains[0] }
        if frequency >= frequencies[frequencies.count - 1] { return gains[gains.count - 1] }

        for index in 0..<(frequencies.count - 1) {
            let lowFrequency = frequencies[index]
            let highFrequency = frequencies[index + 1]
            guard frequency >= lowFrequency, frequency <= highFrequency else { continue }

            let logLow = log10(lowFrequency)
            let logHigh = log10(highFrequency)
            let logTarget = log10(frequency)
            let ratio = (logTarget - logLow) / (logHigh - logLow)
            let lowGain = gains[index]
            let highGain = gains[index + 1]
            return lowGain + Float(ratio) * (highGain - lowGain)
        }

        return 0
    }
}

enum EQBandCountPreset: Int, CaseIterable, Identifiable {
    case standard = 15
    case extended = 20
    case fine = 25
    case professional = 31

    var id: Int { rawValue }

    var bandCount: Int { rawValue }

    var title: String {
        switch self {
        case .standard: String(localized: "Standard")
        case .extended: String(localized: "Extended")
        case .fine: String(localized: "Fine")
        case .professional: String(localized: "Pro")
        }
    }

    var detail: String {
        String(format: String(localized: "%lld bands"), Int64(bandCount))
    }

    init?(bandCount: Int) {
        guard let preset = EQBandCountPreset(rawValue: bandCount) else { return nil }
        self = preset
    }
}

struct EQBandSettings: Codable, Equatable {
    static let minGainDecibels: Float = -12
    static let maxGainDecibels: Float = 12

    var bandCount: Int
    var gains: [Float]

    init(bandCount: Int = EQBandLayout.defaultBandCount, gains: [Float]? = nil) {
        self.bandCount = EQBandLayout.clampedBandCount(bandCount)
        self.gains = Self.normalizedGains(gains ?? [], bandCount: self.bandCount)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedGains = try container.decodeIfPresent([Float].self, forKey: .gains) ?? []
        if let decodedCount = try container.decodeIfPresent(Int.self, forKey: .bandCount) {
            bandCount = EQBandLayout.clampedBandCount(decodedCount)
            gains = Self.normalizedGains(decodedGains, bandCount: bandCount)
            return
        }

        if decodedGains.count == 5 {
            let legacyFrequencies: [Double] = [60, 250, 1_000, 4_000, 16_000]
            let targetCount = EQBandLayout.defaultBandCount
            let targetFrequencies = EQBandLayout.centerFrequencies(bandCount: targetCount)
            let migrated = targetFrequencies.map {
                EQBandLayout.interpolateGain(at: $0, frequencies: legacyFrequencies, gains: decodedGains)
            }
            bandCount = targetCount
            gains = Self.normalizedGains(migrated, bandCount: targetCount)
            return
        }

        bandCount = EQBandLayout.clampedBandCount(decodedGains.count)
        gains = Self.normalizedGains(decodedGains, bandCount: bandCount)
    }

    var centerFrequencies: [Double] {
        EQBandLayout.centerFrequencies(bandCount: bandCount)
    }

    static var flat: EQBandSettings { EQBandSettings() }

    var isFlat: Bool {
        gains.allSatisfy { abs($0) < 0.05 }
    }

    mutating func setGain(_ gain: Float, at index: Int) {
        guard gains.indices.contains(index) else { return }
        gains[index] = Self.clampGain(gain)
    }

    func gain(at index: Int) -> Float {
        guard gains.indices.contains(index) else { return 0 }
        return gains[index]
    }

    func resized(to newBandCount: Int) -> EQBandSettings {
        let count = EQBandLayout.clampedBandCount(newBandCount)
        guard count != bandCount else { return self }

        let sourceFrequencies = centerFrequencies
        let targetFrequencies = EQBandLayout.centerFrequencies(bandCount: count)
        let resizedGains = targetFrequencies.map {
            EQBandLayout.interpolateGain(at: $0, frequencies: sourceFrequencies, gains: gains)
        }
        return EQBandSettings(bandCount: count, gains: resizedGains)
    }

    static func clampGain(_ gain: Float) -> Float {
        min(maxGainDecibels, max(minGainDecibels, gain))
    }

    private static func normalizedGains(_ gains: [Float], bandCount: Int) -> [Float] {
        var normalized = gains.map(clampGain)
        while normalized.count < bandCount {
            normalized.append(0)
        }
        if normalized.count > bandCount {
            normalized = Array(normalized.prefix(bandCount))
        }
        return normalized
    }
}

enum EQPreset: String, CaseIterable, Identifiable {
    case flat
    case bassBoost
    case trebleBoost
    case vocal
    case pop
    case rock
    case jazz
    case classical
    case hipHop
    case electronic
    case acoustic
    case podcast
    case loudness
    case warm
    case bright

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flat: String(localized: "Flat")
        case .bassBoost: String(localized: "Bass Boost")
        case .trebleBoost: String(localized: "Treble Boost")
        case .vocal: String(localized: "Vocal")
        case .pop: String(localized: "Pop")
        case .rock: String(localized: "Rock")
        case .jazz: String(localized: "Jazz")
        case .classical: String(localized: "Classical")
        case .hipHop: String(localized: "Hip-Hop")
        case .electronic: String(localized: "Electronic")
        case .acoustic: String(localized: "Acoustic")
        case .podcast: String(localized: "Podcast")
        case .loudness: String(localized: "Loudness")
        case .warm: String(localized: "Warm")
        case .bright: String(localized: "Bright")
        }
    }

    /// Standard 10-band graphic EQ anchor frequencies (Hz), widely used for preset calibration.
    private static let anchorFrequencies: [Double] = [32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]

    func settings(bandCount: Int = EQBandLayout.defaultBandCount) -> EQBandSettings {
        let frequencies = EQBandLayout.centerFrequencies(bandCount: bandCount)
        let gains = frequencies.map { interpolateGain(at: $0) }
        return EQBandSettings(bandCount: bandCount, gains: gains)
    }

    private func interpolateGain(at frequency: Double) -> Float {
        EQBandLayout.interpolateGain(at: frequency, frequencies: Self.anchorFrequencies, gains: anchorGains)
    }

    /// Gain values (dB) at `anchorFrequencies`.
    ///
    /// Calibrated for natural listening: ±1.5 dB max, subtractive-first, no aggressive V-curves.
    /// Graphic EQ bands cascade in series — large boosts compound and sound harsh; subtle moves
    /// follow guidance from mastering references (Sonoro, iZotope, Harman/neutral curves).
    private var anchorGains: [Float] {
        switch self {
        case .flat:
            return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

        case .bassBoost:
            // Spread low-end lift across sub/bass bands instead of one heavy slider.
            return [1.5, 1.5, 1, 0.5, 0, 0, 0, 0, 0, 0]

        case .trebleBoost:
            // Gentle air and presence — no treble spike.
            return [0, 0, 0, 0, 0, 0, 0.5, 1, 1.5, 1.5]

        case .vocal:
            // High-pass character on rumble; modest 1–4 kHz presence for intelligibility.
            return [-1.5, -1, -0.5, 0, 0.5, 1, 1.5, 1, 0, -0.5]

        case .pop:
            // Neutral foundation with slight vocal-forward mids (Harman-style neutrality).
            return [-0.5, 0, 0, 0.5, 1, 1, 0.5, 0, -0.5, -0.5]

        case .rock:
            // Cut mud in low-mids; tiny presence — avoids fatiguing V-curve.
            return [0.5, 0.5, 0, -0.5, -1, 0, 0.5, 1, 0.5, 0]

        case .jazz:
            // Warm body and open top, mids left natural.
            return [0.5, 1, 0.5, 0, 0, 0, 0.5, 1, 1, 0.5]

        case .classical:
            // Near-flat; barely perceptible air for space and detail.
            return [0, 0, 0, 0, 0, 0, 0, 0.5, 1, 0.5]

        case .hipHop:
            // Sub emphasis with low-mid cleanup — not a bass-max preset.
            return [1.5, 1, 0.5, 0, -1, -0.5, 0.5, 0.5, 0, 0.5]

        case .electronic:
            // Controlled sub, reduced boxiness, light detail on top.
            return [1, 1, 0.5, 0, -1, -0.5, 0, 0.5, 1, 1]

        case .acoustic:
            // Low-mid warmth and mid presence for strings and voice.
            return [0, 0.5, 0.5, 0.5, 0, 0.5, 1, 0.5, 0, 0]

        case .podcast:
            // Remove rumble; lift speech band without shouting.
            return [-2, -1.5, -1, 0, 0.5, 1, 1.5, 1, 0.5, 0]

        case .loudness:
            // Gentle U-curve for quiet listening / small speakers (Fletcher-Munson inspired).
            return [1, 0.5, 0, 0, -0.5, 0, 0.5, 1, 1, 0.5]

        case .warm:
            // Slight low-mid richness, soft top — relaxed tone.
            return [0.5, 1, 0.5, 0.5, 0, 0, -0.5, -0.5, 0, 0]

        case .bright:
            // Subtractive mud cut first, then modest clarity on top.
            return [-0.5, -0.5, -0.5, -0.5, 0, 0.5, 0.5, 1, 1, 0.5]
        }
    }
}

struct PerAppEQSettings: Codable, Equatable {
    var isEnabled = false
    var bands = EQBandSettings.flat

    var isActive: Bool {
        isEnabled && !bands.isFlat
    }
}
