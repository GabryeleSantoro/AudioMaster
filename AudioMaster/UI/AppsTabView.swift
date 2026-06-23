import SwiftUI

struct AppsTabView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var appVolumeController: AppVolumeController
    @State private var searchText: String = ""
    @State private var hoveredPID: pid_t?
    @State private var expandedEQPID: pid_t?

    private var equalizerController: EqualizerController {
        appVolumeController.equalizerController
    }

    private var filteredApps: [AppVolumeEntry] {
        if searchText.isEmpty { return appVolumeController.apps }
        return appVolumeController.apps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 24)

            headerSection
                .padding(.horizontal, 24)

            if !appVolumeController.isProcessTapAvailable {
                unavailableBanner
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
            }

            Spacer().frame(height: 10)

            searchBar
                .padding(.horizontal, 24)

            Spacer().frame(height: 10)

            if filteredApps.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            VStack(spacing: 0) {
                                AppVolumeRow(
                                    app: app,
                                    volume: appVolumeController.sliderValue(for: app.pid),
                                    isMuted: appVolumeController.isMuted(pid: app.pid),
                                    isActive: appVolumeController.isActive(pid: app.pid),
                                    isHovered: hoveredPID == app.pid,
                                    errorMessage: appVolumeController.errors[app.pid],
                                    showsEQButton: equalizerController.perAppFeatureEnabled,
                                    isEQExpanded: expandedEQPID == app.pid,
                                    hasCustomEQ: equalizerController.isPerAppEnabled(for: app.bundleID),
                                    onVolumeChange: { newVolume in
                                        appVolumeController.setGain(pid: app.pid, gain: Float(newVolume))
                                    },
                                    onMuteToggle: {
                                        appVolumeController.toggleMute(pid: app.pid)
                                    },
                                    onEQToggle: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            expandedEQPID = expandedEQPID == app.pid ? nil : app.pid
                                        }
                                    }
                                )
                                .onHover { hovered in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        hoveredPID = hovered ? app.pid : nil
                                    }
                                }

                                if equalizerController.perAppFeatureEnabled,
                                   expandedEQPID == app.pid {
                                    AppEqualizerPanel(
                                        bundleID: app.bundleID,
                                        equalizerController: equalizerController
                                    )
                                    .padding(.horizontal, 10)
                                    .padding(.bottom, 6)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appVolumeController.refresh()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Apps")
                .font(.system(size: 18, weight: .semibold))

            let playing = appVolumeController.apps.filter(\.isPlayingAudio).count
            let total = appVolumeController.apps.count
            if playing > 0 {
                Text(String(format: String(localized: "%lld playing · %lld open"), Int64(playing), Int64(total)))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text(String(format: String(localized: "%lld open"), Int64(total)))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var unavailableBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
            Text("Per-app volume requires macOS 14.2 or later.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .amGlassCard(cornerRadius: 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("No apps running")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 40)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            TextField("Filter…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

// MARK: - App Volume Row

struct AppVolumeRow: View {
    let app: AppVolumeEntry
    let volume: Double
    let isMuted: Bool
    let isActive: Bool
    let isHovered: Bool
    let errorMessage: String?
    var showsEQButton = false
    var isEQExpanded = false
    var hasCustomEQ = false
    let onVolumeChange: (Double) -> Void
    let onMuteToggle: () -> Void
    var onEQToggle: (() -> Void)?

    @AppStorage(AppPreferences.Keys.showDecibels) private var showDecibels = false
    @State private var localVolume: Double

    init(
        app: AppVolumeEntry,
        volume: Double,
        isMuted: Bool,
        isActive: Bool,
        isHovered: Bool,
        errorMessage: String?,
        showsEQButton: Bool = false,
        isEQExpanded: Bool = false,
        hasCustomEQ: Bool = false,
        onVolumeChange: @escaping (Double) -> Void,
        onMuteToggle: @escaping () -> Void,
        onEQToggle: (() -> Void)? = nil
    ) {
        self.app = app
        self.volume = volume
        self.isMuted = isMuted
        self.isActive = isActive
        self.isHovered = isHovered
        self.errorMessage = errorMessage
        self.showsEQButton = showsEQButton
        self.isEQExpanded = isEQExpanded
        self.hasCustomEQ = hasCustomEQ
        self.onVolumeChange = onVolumeChange
        self.onMuteToggle = onMuteToggle
        self.onEQToggle = onEQToggle
        _localVolume = State(initialValue: volume)
    }

    var body: some View {
        HStack(spacing: 10) {
            appIcon
            appName
            Spacer()
            if showsEQButton {
                eqButton
            }
            volumeSlider
            muteButton
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.primary.opacity(0.025) : Color.clear)
        )
        .overlay(alignment: .bottomLeading) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 1)
            }
        }
        .onChange(of: volume) { _, newValue in
            localVolume = newValue
        }
    }

    private var appIcon: some View {
        Group {
            if let icon = AppVolumeEntry.icon(for: app.pid) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
    }

    private var appName: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(app.displayName)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Text(volumeLabel)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(isActive ? AMTheme.accent : Color.secondary)
        }
        .frame(width: 110, alignment: .leading)
    }

    private var volumeSlider: some View {
        VolumeSliderControl(
            value: $localVolume,
            isMuted: isMuted,
            isHovered: isHovered,
            trackHeight: 3,
            trackOpacity: 0.05,
            onValueChange: onVolumeChange
        )
        .frame(width: 130, height: 20)
    }

    private var muteButton: some View {
        Button(action: onMuteToggle) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 11))
                .foregroundStyle(isMuted ? .primary : .tertiary)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
    }

    private var eqButton: some View {
        Button {
            onEQToggle?()
        } label: {
            Image(systemName: isEQExpanded ? "slider.vertical.3" : "slider.horizontal.3")
                .font(.system(size: 11))
                .foregroundStyle(hasCustomEQ ? AMTheme.accent : Color.secondary.opacity(0.5))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Custom equalizer"))
    }

    private var volumeLabel: String {
        if isMuted { return String(localized: "Muted") }
        if isActive || app.isPlayingAudio {
            return VolumeMath.volumeLabel(for: localVolume, showDecibels: showDecibels)
        }
        return String(localized: "Ready")
    }
}

// MARK: - App Equalizer Panel

struct AppEqualizerPanel: View {
    let bundleID: String?
    @ObservedObject var equalizerController: EqualizerController
    @State private var selectedPreset: EQPreset = .flat

    private var isEnabled: Bool {
        equalizerController.isPerAppEnabled(for: bundleID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: perAppEnabledBinding) {
                    Text("Custom EQ")
                        .font(.system(size: 12, weight: .medium))
                }
                .toggleStyle(.switch)
                .scaleEffect(0.7)

                Spacer()

                Button("Reset") {
                    equalizerController.resetPerApp(bundleID: bundleID)
                    selectedPreset = .flat
                }
                .buttonStyle(SubtleButtonStyle())
                .disabled(!isEnabled)
            }

            EqualizerPresetPicker(selectedPreset: $selectedPreset, compact: true) { preset in
                equalizerController.applyPerAppPreset(preset, bundleID: bundleID)
            }
            .disabled(!isEnabled)

            EqualizerBandCountPicker(bandCount: perAppBandCountBinding, compact: true)
                .disabled(!isEnabled)

            EqualizerBandControl(
                bands: bandsBinding,
                isEnabled: isEnabled
            ) { index, gain in
                equalizerController.setPerAppGain(gain, at: index, bundleID: bundleID)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        )
    }

    private var perAppEnabledBinding: Binding<Bool> {
        Binding(
            get: { equalizerController.isPerAppEnabled(for: bundleID) },
            set: { equalizerController.setPerAppEnabled($0, bundleID: bundleID) }
        )
    }

    private var bandsBinding: Binding<EQBandSettings> {
        Binding(
            get: { equalizerController.perAppSettings(for: bundleID).bands },
            set: { equalizerController.setPerAppBands($0, bundleID: bundleID) }
        )
    }

    private var perAppBandCountBinding: Binding<Int> {
        Binding(
            get: { equalizerController.perAppSettings(for: bundleID).bands.bandCount },
            set: { equalizerController.setPerAppBandCount($0, bundleID: bundleID) }
        )
    }
}
