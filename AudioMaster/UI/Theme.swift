import AppKit
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    static var current: AppAppearance {
        AppPreferences.appearance
    }

    func applyToApplication() {
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum AMTheme {
    static let accent = Color.accentColor
    static let surface = Color(nsColor: .windowBackgroundColor)
    static let surfaceElevated = Color(nsColor: .controlBackgroundColor)
    static let surfaceBorder = Color.primary.opacity(0.06)
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
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(0.025))
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

    func appAppearanceAware() -> some View {
        modifier(AppAppearanceModifier())
    }
}

struct AppAppearanceModifier: ViewModifier {
    @AppStorage(AppPreferences.Keys.appearance) private var appearanceRaw = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .system
    }

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearance.colorScheme)
            .onAppear {
                appearance.applyToApplication()
            }
            .onChange(of: appearanceRaw) { _ in
                appearance.applyToApplication()
            }
    }
}

