import SwiftUI

struct PopoverView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var bluetoothManager: BluetoothDeviceManager
    @ObservedObject var appVolumeController: AppVolumeController
    let menuBarController: MenuBarController

    @AppStorage(AppPreferences.Keys.showDecibels) private var showDecibels = false
    @State private var hoveredPID: pid_t?
    @State private var hoveredDeviceID: UUID?
    @State private var isOutputExpanded = false

    private var sortedApps: [AppVolumeEntry] {
        appVolumeController.apps
    }

    var body: some View {
        VStack(spacing: 0) {
            appVolumesSection

            Divider().opacity(0.25)

            outputSection

            Divider().opacity(0.25)

            openAppButton
        }
        .frame(width: 320)
        .background(AMTheme.surface)
        .appAppearanceAware()
        .onAppear {
            appVolumeController.refresh()
            appVolumeController.refreshSystemVolume()
        }
    }

    // MARK: - App Volumes (primary)

    private var appVolumesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Apps")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                let playing = sortedApps.filter(\.isPlayingAudio).count
                if playing > 0 {
                    Text(String(format: String(localized: "%lld playing"), Int64(playing)))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if sortedApps.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                    Text("No apps running")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedApps) { app in
                            PopoverAppVolumeRow(
                                app: app,
                                volume: appVolumeController.sliderValue(for: app.pid),
                                isMuted: appVolumeController.isMuted(pid: app.pid),
                                isActive: appVolumeController.isActive(pid: app.pid),
                                isHovered: hoveredPID == app.pid,
                                onVolumeChange: { newVolume in
                                    appVolumeController.setGain(pid: app.pid, gain: Float(newVolume))
                                },
                                onMuteToggle: {
                                    appVolumeController.toggleMute(pid: app.pid)
                                }
                            )
                            .onHover { hovered in
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    hoveredPID = hovered ? app.pid : nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
                .frame(maxHeight: 260)
            }
        }
    }

    // MARK: - Output Devices (collapsed by default)

    private var outputSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isOutputExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isOutputExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)

                    Text("Output")
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    if let current = deviceManager.defaultOutputDevice {
                        HStack(spacing: 5) {
                            Text(current.name)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let battery = bluetoothManager.battery(for: current) {
                                BatteryIndicatorView(level: battery.primaryLevel, compact: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOutputExpanded {
                VStack(spacing: 0) {
                    masterVolumeRow
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(deviceManager.outputDevices) { device in
                                DeviceRowCompact(
                                    device: device,
                                    isSelected: device.id == deviceManager.defaultOutputDevice?.id,
                                    isHovered: hoveredDeviceID == device.id,
                                    battery: bluetoothManager.battery(for: device)
                                )
                                .onHover { hovered in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        hoveredDeviceID = hovered ? device.id : nil
                                    }
                                }
                                .onTapGesture {
                                    selectDevice(device)
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var masterVolumeRow: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Master")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(VolumeMath.volumeLabel(for: appVolumeController.systemVolume, showDecibels: showDecibels))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 3)

                    Capsule()
                        .fill(AMTheme.accent)
                        .frame(width: geometry.size.width * appVolumeController.systemVolume, height: 3)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newVolume = max(0, min(1, value.location.x / geometry.size.width))
                            appVolumeController.setSystemVolume(newVolume)
                        }
                )
            }
            .frame(height: 16)
        }
    }

    // MARK: - Open App

    private var openAppButton: some View {
        Button(action: { menuBarController.openMainWindow() }) {
            Label("Open AudioMaster", systemImage: "macwindow")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PopoverButtonStyle(isPrimary: false))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func selectDevice(_ device: AudioDevice) {
        do {
            try deviceManager.setDefaultOutputDevice(device)
        } catch {
            print("[AudioMaster] Failed to switch device: \(error.localizedDescription)")
        }
    }
}

// MARK: - Compact App Volume Row (Popover)

struct PopoverAppVolumeRow: View {
    let app: AppVolumeEntry
    let volume: Double
    let isMuted: Bool
    let isActive: Bool
    let isHovered: Bool
    let onVolumeChange: (Double) -> Void
    let onMuteToggle: () -> Void

    @AppStorage(AppPreferences.Keys.showDecibels) private var showDecibels = false
    @State private var localVolume: Double = 0

    var body: some View {
        HStack(spacing: 6) {
            appIcon

            Text(app.displayName)
                .font(.system(size: 12, weight: app.isPlayingAudio ? .medium : .regular))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(volumeLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isActive || app.isPlayingAudio ? AMTheme.accent : Color.secondary)
                .frame(minWidth: showDecibels ? 62 : 30, alignment: .trailing)

            volumeSlider

            Button(action: onMuteToggle) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isMuted ? .primary : .quaternary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(rowBackground)
        )
        .onAppear { localVolume = volume }
        .onChange(of: volume) { newValue in localVolume = newValue }
    }

    private var rowBackground: Color {
        if isHovered {
            return Color.primary.opacity(0.03)
        }
        return .clear
    }

    private var appIcon: some View {
        Group {
            if let icon = AppVolumeEntry.icon(for: app.pid) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
    }

    private var volumeSlider: some View {
        VolumeSliderControl(
            value: $localVolume,
            isMuted: isMuted,
            isHovered: isHovered,
            trackHeight: 2.5,
            trackOpacity: 0.06,
            onValueChange: onVolumeChange
        )
        .frame(width: 66, height: 18)
    }

    private var volumeLabel: String {
        if isMuted { return String(localized: "—") }
        return VolumeMath.volumeLabel(for: localVolume, showDecibels: showDecibels)
    }
}

// MARK: - Compact Device Row (Popover)

struct DeviceRowCompact: View {
    let device: AudioDevice
    let isSelected: Bool
    let isHovered: Bool
    var battery: BluetoothBatteryReading?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.type.sfSymbol)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? AMTheme.deviceAccent(for: device.type) : Color.secondary)
                .frame(width: 20)

            Text(device.name)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)

            Spacer()

            if let battery {
                BatteryIndicatorView(level: battery.primaryLevel, compact: true)
            }

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AMTheme.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(backgroundFill)
        )
        .contentShape(Rectangle())
    }

    private var backgroundFill: Color {
        if isHovered {
            return Color.primary.opacity(0.03)
        }
        return .clear
    }
}

// MARK: - Button Styles

struct SubtleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.06 : 0.03))
            )
    }
}

struct PopoverButtonStyle: ButtonStyle {
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isPrimary ? .white : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isPrimary
                            ? AnyShapeStyle(AMTheme.accent.opacity(configuration.isPressed ? 0.85 : 1))
                            : AnyShapeStyle(Color.primary.opacity(configuration.isPressed ? 0.06 : 0.03))
                    )
            )
    }
}
