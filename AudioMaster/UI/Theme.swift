import SwiftUI

enum AMTheme {
    static let accent = Color.blue
    static let surface = Color(nsColor: .windowBackgroundColor)
    static let surfaceElevated = Color(nsColor: .controlBackgroundColor)
    static let surfaceBorder = Color.primary.opacity(0.08)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static func deviceAccent(for type: DeviceType) -> Color {
        switch type {
        case .airpods: return .blue
        case .speaker: return .purple
        case .headphones: return .orange
        case .usb: return .teal
        case .hdmi: return .indigo
        case .bluetooth: return .cyan
        case .aggregate: return .green
        case .unknown: return .gray
        }
    }
}

struct AMBackground: View {
    var body: some View {
        AMTheme.surface
            .ignoresSafeArea()
    }
}

struct AMGlassCard: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AMTheme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(AMTheme.surfaceBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func amGlassCard(cornerRadius: CGFloat = 10) -> some View {
        modifier(AMGlassCard(cornerRadius: cornerRadius))
    }
}

struct WaveformView: View {
    @State private var phase: CGFloat = 0
    let barCount: Int
    let isAnimating: Bool

    init(barCount: Int = 5, isAnimating: Bool = true) {
        self.barCount = barCount
        self.isAnimating = isAnimating
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(AMTheme.accent.opacity(0.7))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 18)
        .onAppear {
            guard isAnimating else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base: [CGFloat] = [8, 14, 18, 12, 10, 16, 11]
        let value = base[index % base.count]
        guard isAnimating else { return value * 0.6 }
        let offset = sin((CGFloat(index) * 0.9) + phase * .pi * 2) * 4
        return max(4, value + offset)
    }
}
