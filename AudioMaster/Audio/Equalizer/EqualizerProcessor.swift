import Foundation
import os.lock

final class EqualizerProcessor {
    private let lock = OSAllocatedUnfairLock<Void>(initialState: ())
    private var filters: [BiquadFilter] = []
    private var settings = EQBandSettings.flat
    private var outputTrim: Float = 1
    private let sampleRate: Double

    init(sampleRate: Double = 48_000) {
        self.sampleRate = sampleRate
        resizeFilters(to: settings.bandCount)
        reconfigureFilters()
    }

    func update(settings newSettings: EQBandSettings) {
        lock.withLock {
            settings = newSettings
            if filters.count != settings.bandCount {
                resizeFilters(to: settings.bandCount)
            }
            reconfigureFilters()
        }
    }

    func process(sample: Float) -> Float {
        lock.withLock {
            var value = sample
            for index in filters.indices where abs(settings.gains[index]) >= 0.05 {
                value = filters[index].process(value)
            }
            return value * outputTrim
        }
    }

    private func resizeFilters(to bandCount: Int) {
        if filters.count < bandCount {
            filters.append(contentsOf: Array(repeating: BiquadFilter(), count: bandCount - filters.count))
        } else if filters.count > bandCount {
            filters = Array(filters.prefix(bandCount))
        }
    }

    private func reconfigureFilters() {
        let frequencies = settings.centerFrequencies
        for index in filters.indices {
            filters[index].configurePeakingEQ(
                sampleRate: sampleRate,
                centerFrequency: frequencies[index],
                gainDecibels: settings.gains[index],
                q: qForBand(at: index, frequencies: frequencies)
            )
            filters[index].resetState()
        }
        outputTrim = makeupGainTrim(for: settings.gains)
    }

    /// Bandwidth matched to band spacing — wider, more musical filters that overlap less when cascaded.
    private func qForBand(at index: Int, frequencies: [Double]) -> Float {
        guard frequencies.count > 1 else { return 1.2 }

        let octaveSpan: Double
        if index == 0 {
            octaveSpan = log2(frequencies[1] / frequencies[0])
        } else if index == frequencies.count - 1 {
            octaveSpan = log2(frequencies[index] / frequencies[index - 1])
        } else {
            octaveSpan = log2(frequencies[index + 1] / frequencies[index - 1]) / 2
        }

        let bandwidth = max(0.25, octaveSpan * 0.85)
        let q = sqrt(pow(2.0, bandwidth)) / (pow(2.0, bandwidth) - 1)
        return Float(min(2.2, max(0.9, q)))
    }

    /// Compensate headroom when multiple bands boost in series (prevents harshness and clipping).
    private func makeupGainTrim(for gains: [Float]) -> Float {
        let positiveSum = gains.filter { $0 > 0 }.reduce(0, +)
        guard positiveSum > 0 else { return 1 }
        let trimDecibels = -positiveSum * 0.3
        return pow(10, trimDecibels / 20)
    }
}
