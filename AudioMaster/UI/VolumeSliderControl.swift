import SwiftUI

struct VolumeSliderControl: View {
    @Binding var value: Double
    let isMuted: Bool
    let isHovered: Bool
    let trackHeight: CGFloat
    let trackOpacity: Double
    let onValueChange: (Double) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let fillRatio = VolumeMath.sliderFillRatio(value)
            let showKnob = isHovered || isFocused

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(trackOpacity))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(isMuted ? Color.secondary.opacity(0.3) : AMTheme.accent)
                    .frame(width: max(0, geometry.size.width * fillRatio), height: trackHeight)

                if showKnob {
                    Circle()
                        .fill(Color.primary.opacity(0.8))
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, geometry.size.width * fillRatio - 5))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let normalized = drag.location.x / geometry.size.width
                        applyValue(VolumeMath.sliderValue(fromNormalizedPosition: normalized))
                    }
            )
        }
        .focusable()
        .focused($isFocused)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AMTheme.accent.opacity(isFocused ? 0.45 : 0), lineWidth: 1)
                .padding(-3)
        )
        .onKeyPress(.leftArrow) { nudgeVolume(by: -VolumeMath.keyboardStep) }
        .onKeyPress(.rightArrow) { nudgeVolume(by: VolumeMath.keyboardStep) }
        .onKeyPress(.downArrow) { nudgeVolume(by: -VolumeMath.keyboardStep) }
        .onKeyPress(.upArrow) { nudgeVolume(by: VolumeMath.keyboardStep) }
    }

    private func nudgeVolume(by delta: Float) -> KeyPress.Result {
        let updated = VolumeMath.clampSliderValue(Float(value) + delta)
        applyValue(Double(updated))
        return .handled
    }

    private func applyValue(_ newValue: Double) {
        value = newValue
        onValueChange(newValue)
    }
}
