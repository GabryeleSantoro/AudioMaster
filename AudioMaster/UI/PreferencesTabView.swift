import SwiftUI

struct PreferencesTabView: View {
    @State private var launchAtLogin = false
    @State private var showInMenuBar = true
    @State private var openWindowOnLaunch = AppDelegate.openWindowOnLaunch
    @State private var rememberAppVolumes = true
    @State private var defaultVolume: Double = 1.0
    @State private var volumeCurve: VolumeCurveOption = .logarithmic
    @AppStorage(AppPreferences.Keys.showDecibels) private var showDecibels = false
    @AppStorage(AppPreferences.Keys.volumeShortcutsEnabled) private var volumeShortcutsEnabled = true
    @AppStorage(AppPreferences.Keys.automaticUpdatesEnabled) private var automaticUpdatesEnabled = true
    @State private var debugLogging = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 32)

                Text("Preferences")
                    .font(.system(size: 24, weight: .bold))

                generalSection
                volumeSection
                shortcutsSection
                advancedSection

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - General

    private var generalSection: some View {
        PreferenceSection(title: "General") {
            PreferenceToggle(title: "Launch at login", subtitle: "Start AudioMaster when you log in", isOn: $launchAtLogin)
            PreferenceToggle(title: "Show in menu bar", subtitle: "Display volume control in the menu bar", isOn: $showInMenuBar)
            PreferenceToggle(
                title: "Open window on launch",
                subtitle: "Show the main window when AudioMaster starts",
                isOn: $openWindowOnLaunch
            )
            .onChange(of: openWindowOnLaunch) { newValue in
                AppDelegate.openWindowOnLaunch = newValue
            }
            PreferenceToggle(title: "Remember app volumes", subtitle: "Persist volume levels across restarts", isOn: $rememberAppVolumes)
            PreferenceToggle(
                title: "Automatic updates",
                subtitle: "Check for and install updates automatically",
                isOn: $automaticUpdatesEnabled
            )
        }
    }

    // MARK: - Volume

    private var volumeSection: some View {
        PreferenceSection(title: "Volume Control") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Default volume for new apps")
                        .font(.system(size: 13))
                    Spacer()
                    Text(VolumeMath.volumeLabel(for: defaultVolume, showDecibels: showDecibels))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 4)

                        Capsule()
                            .fill(AMTheme.accent)
                            .frame(width: geometry.size.width * defaultVolume, height: 4)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                defaultVolume = max(0, min(1, value.location.x / geometry.size.width))
                            }
                    )
                }
                .frame(height: 20)
            }
            .padding(.vertical, 4)

            HStack {
                Text("Volume curve")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $volumeCurve) {
                    ForEach(VolumeCurveOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.vertical, 4)

            PreferenceToggle(title: "Show decibels", subtitle: "Display dB values alongside percentages", isOn: $showDecibels)
        }
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        PreferenceSection(title: "Keyboard Shortcuts") {
            PreferenceToggle(
                title: "Volume shortcuts",
                subtitle: "Adjust the last modified app volume from anywhere",
                isOn: $volumeShortcutsEnabled
            )

            ShortcutRow(title: "Increase volume of last app", shortcut: "⌘⌥↑")
                .opacity(volumeShortcutsEnabled ? 1 : 0.45)
            ShortcutRow(title: "Decrease volume of last app", shortcut: "⌘⌥↓")
                .opacity(volumeShortcutsEnabled ? 1 : 0.45)
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        PreferenceSection(title: "Advanced") {
            PreferenceToggle(title: "Debug logging", subtitle: "Enable verbose logging for troubleshooting", isOn: $debugLogging)

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    resetDefaults()
                }
                .buttonStyle(DestructiveButtonStyle())
            }
            .padding(.top, 4)
        }
    }

    private func resetDefaults() {
        launchAtLogin = false
        showInMenuBar = true
        openWindowOnLaunch = false
        AppDelegate.openWindowOnLaunch = false
        rememberAppVolumes = true
        defaultVolume = 1.0
        volumeCurve = .logarithmic
        AppPreferences.resetToDefaults()
        debugLogging = false
    }
}

// MARK: - Supporting Types

enum VolumeCurveOption: CaseIterable, Identifiable, Hashable {
    case linear
    case logarithmic

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .linear: "Linear"
        case .logarithmic: "Logarithmic"
        }
    }
}

// MARK: - Preference Section

struct PreferenceSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Preference Toggle

struct PreferenceToggle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.75)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let title: LocalizedStringKey
    let shortcut: LocalizedStringKey

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Destructive Button Style

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.red)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
    }
}
