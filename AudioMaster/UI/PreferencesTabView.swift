import SwiftUI

struct PreferencesTabView: View {
    @State private var launchAtLogin = false
    @State private var showInMenuBar = true
    @State private var rememberAppVolumes = true
    @State private var defaultVolume: Double = 1.0
    @State private var volumeCurve: VolumeCurveOption = .logarithmic
    @State private var showDecibels = false
    @State private var notifyDeviceSwitch = true
    @State private var notifyAppDetection = false
    @State private var notifyBluetoothDisconnect = true
    @State private var debugLogging = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                Spacer().frame(height: 40)

                Text("Preferences")
                    .font(.system(size: 22, weight: .semibold))

                generalSection
                volumeSection
                notificationsSection
                advancedSection

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - General

    private var generalSection: some View {
        PreferenceSection(title: "General") {
            PreferenceToggle(title: "Launch at login", subtitle: "Start AudioMaster when you log in", isOn: $launchAtLogin)
            PreferenceToggle(title: "Show in menu bar", subtitle: "Display volume control in the menu bar", isOn: $showInMenuBar)
            PreferenceToggle(title: "Remember app volumes", subtitle: "Persist volume levels across restarts", isOn: $rememberAppVolumes)
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
                    Text("\(Int(defaultVolume * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.primary.opacity(0.4))
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
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            .padding(.vertical, 4)

            PreferenceToggle(title: "Show decibels", subtitle: "Display dB values alongside percentages", isOn: $showDecibels)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        PreferenceSection(title: "Notifications") {
            PreferenceToggle(title: "Device switch", subtitle: "Notify when audio output changes", isOn: $notifyDeviceSwitch)
            PreferenceToggle(title: "App detection", subtitle: "Notify when new audio apps are detected", isOn: $notifyAppDetection)
            PreferenceToggle(title: "Bluetooth disconnect", subtitle: "Notify when a Bluetooth device disconnects", isOn: $notifyBluetoothDisconnect)
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
        rememberAppVolumes = true
        defaultVolume = 1.0
        volumeCurve = .logarithmic
        showDecibels = false
        notifyDeviceSwitch = true
        notifyAppDetection = false
        notifyBluetoothDisconnect = true
        debugLogging = false
    }
}

// MARK: - Supporting Types

enum VolumeCurveOption: String, CaseIterable, Identifiable {
    case linear = "Linear"
    case logarithmic = "Logarithmic"

    var id: String { rawValue }
}

// MARK: - Preference Section

struct PreferenceSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Preference Toggle

struct PreferenceToggle: View {
    let title: String
    let subtitle: String
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

// MARK: - Destructive Button Style

struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}
