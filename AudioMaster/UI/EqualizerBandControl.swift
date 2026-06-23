import SwiftUI

struct EqualizerBandControl: View {
    @Binding var bands: EQBandSettings
    var isEnabled: Bool = true
    var onChange: ((Int, Float) -> Void)?

    private var sliderWidth: CGFloat {
        switch bands.bandCount {
        case 31: 14
        case 25: 16
        case 20: 18
        default: 22
        }
    }

    private var sliderSpacing: CGFloat {
        bands.bandCount >= 25 ? 4 : 6
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: sliderSpacing) {
                ForEach(Array(bands.centerFrequencies.enumerated()), id: \.offset) { index, frequency in
                    EqualizerBandSlider(
                        frequency: frequency,
                        gain: binding(at: index),
                        sliderWidth: sliderWidth,
                        isEnabled: isEnabled,
                        onChange: { gain in
                            onChange?(index, gain)
                        }
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
        .opacity(isEnabled ? 1 : 0.4)
        .allowsHitTesting(isEnabled)
    }

    private func binding(at index: Int) -> Binding<Float> {
        Binding(
            get: { bands.gain(at: index) },
            set: { newValue in
                var updated = bands
                updated.setGain(newValue, at: index)
                bands = updated
            }
        )
    }
}

private struct EqualizerBandSlider: View {
    let frequency: Double
    @Binding var gain: Float
    let sliderWidth: CGFloat
    let isEnabled: Bool
    let onChange: (Float) -> Void

    private let sliderHeight: CGFloat = 80

    var body: some View {
        VStack(spacing: 4) {
            Text(gainLabel)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(isEnabled ? Color.secondary : Color.secondary.opacity(0.5))
                .frame(height: 10)

            GeometryReader { geometry in
                let halfHeight = geometry.size.height / 2
                let gainRatio = CGFloat(gain / EQBandSettings.maxGainDecibels)
                let barHeight = max(2, abs(gainRatio) * halfHeight)

                ZStack {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 3)

                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 7, height: 0.5)

                    Capsule()
                        .fill(fillColor)
                        .frame(width: 3, height: barHeight)
                        .offset(y: gain >= 0 ? -barHeight / 2 : barHeight / 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = 1 - (value.location.y / geometry.size.height)
                            applyGain(fromNormalized: ratio)
                        }
                )
            }
            .frame(width: sliderWidth, height: sliderHeight)

            Text(EQBandLayout.formatFrequency(frequency))
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: sliderWidth)
    }

    private var gainLabel: String {
        if abs(gain) < 0.05 { return "0" }
        return String(format: "%+.0f", gain)
    }

    private var fillColor: Color {
        if abs(gain) < 0.05 {
            return Color.secondary.opacity(0.25)
        }
        return gain > 0 ? AMTheme.accent.opacity(0.7) : Color.orange.opacity(0.6)
    }

    private func applyGain(fromNormalized ratio: Double) {
        let clamped = max(0, min(1, ratio))
        let range = EQBandSettings.maxGainDecibels - EQBandSettings.minGainDecibels
        let newGain = EQBandSettings.minGainDecibels + Float(clamped) * range
        let stepped = (newGain * 2).rounded() / 2
        gain = stepped
        onChange(stepped)
    }
}

struct EqualizerPresetPicker: View {
    @Binding var selectedPreset: EQPreset
    let onSelect: (EQPreset) -> Void
    var compact = false

    var body: some View {
        HStack {
            Text("Preset")
                .font(compact ? .system(size: 12) : .system(size: 13))
            Spacer()
            Picker("", selection: $selectedPreset) {
                ForEach(EQPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .onChange(of: selectedPreset) { _, preset in
                onSelect(preset)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EqualizerBandCountPicker: View {
    @Binding var bandCount: Int
    var compact = false

    private var selectedPreset: Binding<EQBandCountPreset> {
        Binding(
            get: {
                EQBandCountPreset(bandCount: bandCount) ?? .standard
            },
            set: { preset in
                bandCount = preset.bandCount
            }
        )
    }

    var body: some View {
        HStack {
            Text("Bands")
                .font(compact ? .system(size: 12) : .system(size: 13))
            Spacer()
            if compact {
                Picker("", selection: selectedPreset) {
                    ForEach(EQBandCountPreset.allCases) { preset in
                        Text("\(preset.title) · \(preset.detail)").tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            } else {
                Picker("", selection: selectedPreset) {
                    ForEach(EQBandCountPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
        }
        .padding(.vertical, 4)

        if !compact {
            Text(selectedPreset.wrappedValue.detail)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
    }
}
