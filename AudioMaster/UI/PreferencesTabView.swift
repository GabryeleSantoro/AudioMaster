import SwiftUI

struct PreferencesTabView: View {
    @ObservedObject var equalizerController: EqualizerController
    @State private var launchAtLogin = false
    @State private var showInMenuBar = true
    @State private var openWindowOnLaunch = AppDelegate.openWindowOnLaunch
    @State private var rememberAppVolumes = true
    @State private var defaultVolume: Double = 1.0
    @State private var volumeCurve: VolumeCurveOption = .logarithmic
    @AppStorage(AppPreferences.Keys.showDecibels) private var showDecibels = false
    @AppStorage(AppPreferences.Keys.volumeShortcutsEnabled) private var volumeShortcutsEnabled = true
    @AppStorage(AppPreferences.Keys.automaticUpdatesEnabled) private var automaticUpdatesEnabled = true
    @AppStorage(AppPreferences.Keys.appearance) private var appearance = AppAppearance.system.rawValue
    @State private var debugLogging = false
    @State private var selectedGlobalPreset: EQPreset = .flat

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 24)

                Text("Preferences")
                    .font(.system(size: 18, weight: .semibold))

                generalSection
                appearanceSection
                volumeSection
                equalizerSection
                shortcutsSection
                advancedSection

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
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

    // MARK: - Appearance

    private var appearanceSection: some View {
        PreferenceSection(title: "Appearance") {
            HStack(spacing: 8) {
                ForEach(AppAppearance.allCases) { option in
                    AppearanceCard(
                        option: option,
                        isSelected: appearance == option.rawValue
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            appearance = option.rawValue
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Volume

    private var volumeSection: some View {
        PreferenceSection(title: "Volume") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Default volume")
                        .font(.system(size: 13))
                    Spacer()
                    Text(VolumeMath.volumeLabel(for: defaultVolume, showDecibels: showDecibels))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                            .frame(height: 3)

                        Capsule()
                            .fill(AMTheme.accent)
                            .frame(width: geometry.size.width * defaultVolume, height: 3)
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
                .frame(height: 18)
            }
            .padding(.vertical, 3)

            HStack {
                Text("Curve")
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: $volumeCurve) {
                    ForEach(VolumeCurveOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.vertical, 3)

            PreferenceToggle(title: "Show decibels", subtitle: "Display dB values alongside percentages", isOn: $showDecibels)
        }
    }

    // MARK: - Equalizer

    private var equalizerSection: some View {
        PreferenceSection(title: "Equalizer") {
            PreferenceToggle(
                title: "Enable global equalizer",
                subtitle: "Apply EQ to all audio output",
                isOn: $equalizerController.globalEnabled
            )

            EqualizerPresetPicker(selectedPreset: $selectedGlobalPreset) { preset in
                equalizerController.applyPreset(preset)
            }
            .disabled(!equalizerController.globalEnabled)

            EqualizerBandCountPicker(bandCount: $equalizerController.bandCount)
                .disabled(!equalizerController.globalEnabled)

            EqualizerBandControl(
                bands: $equalizerController.globalBands,
                isEnabled: equalizerController.globalEnabled
            ) { index, gain in
                equalizerController.setGlobalGain(gain, at: index)
            }
            .padding(.vertical, 8)

            HStack {
                Spacer()
                Button("Reset EQ") {
                    equalizerController.resetGlobal()
                    selectedGlobalPreset = .flat
                }
                .buttonStyle(SubtleButtonStyle())
                .disabled(!equalizerController.globalEnabled)
            }

            Divider()
                .padding(.vertical, 6)

            PreferenceToggle(
                title: "Per-app equalizer",
                subtitle: "Allow custom EQ settings for individual apps",
                isOn: $equalizerController.perAppFeatureEnabled
            )

            if equalizerController.perAppFeatureEnabled {
                Text("Configure per-app EQ from the Apps tab.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
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
        equalizerController.resetToDefaults()
        selectedGlobalPreset = .flat
        appearance = AppAppearance.system.rawValue
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)

            VStack(spacing: 0) {
                content
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
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
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.75)
        }
        .padding(.vertical, 3)
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
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.03))
                )
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Appearance Card

struct AppearanceCard: View {
    let option: AppAppearance
    let isSelected: Bool
    let action: () -> Void

    private var iconName: String {
        switch option {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? AMTheme.accent : .secondary)

                Text(option.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? AMTheme.accent.opacity(0.08) : Color.primary.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isSelected ? AMTheme.accent.opacity(0.3) : Color.primary.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Destructive Button Style

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.red.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.08 : 0.04))
            )
    }
}
