import SwiftUI

struct PopoverView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var appVolumeController: AppVolumeController
    let menuBarController: MenuBarController

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
        .frame(width: 340)
        .background(AMTheme.surface)
        .onAppear {
            appVolumeController.refresh()
            appVolumeController.refreshSystemVolume()
        }
    }

    // MARK: - App Volumes (primary)

    private var appVolumesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("App Volumes")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                let playing = sortedApps.filter(\.isPlayingAudio).count
                if playing > 0 {
                    Text("\(playing) playing")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if sortedApps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No apps running")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 1) {
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
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 280)
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
                HStack(spacing: 8) {
                    Image(systemName: isOutputExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(systemName: "hifispeaker.2.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AMTheme.accent)

                    Text("Output")
                        .font(.system(size: 12, weight: .medium))

                    Spacer()

                    if let current = deviceManager.defaultOutputDevice {
                        Text(current.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOutputExpanded {
                VStack(spacing: 0) {
                    masterVolumeRow
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 1) {
                            ForEach(deviceManager.outputDevices) { device in
                                DeviceRowCompact(
                                    device: device,
                                    isSelected: device.id == deviceManager.defaultOutputDevice?.id,
                                    isHovered: hoveredDeviceID == device.id
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
                        .padding(.horizontal, 8)
                    }
                    .frame(maxHeight: 160)
                }
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var masterVolumeRow: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Master")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(appVolumeController.systemVolume * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 4)

                    Capsule()
                        .fill(AMTheme.accent)
                        .frame(width: geometry.size.width * appVolumeController.systemVolume, height: 4)
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
            .frame(height: 18)
        }
    }

    // MARK: - Open App

    private var openAppButton: some View {
        Button(action: { menuBarController.openMainWindow() }) {
            Label("Open AudioMaster", systemImage: "macwindow")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PopoverButtonStyle(isPrimary: true))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

    @State private var localVolume: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            appIcon

            Text(app.displayName)
                .font(.system(size: 12, weight: app.isPlayingAudio ? .semibold : .regular))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(volumeLabel)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(isActive || app.isPlayingAudio ? AMTheme.accent : .secondary)
                .frame(width: 28, alignment: .trailing)

            volumeSlider

            Button(action: onMuteToggle) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isMuted ? .primary : .tertiary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
        .onAppear { localVolume = volume }
        .onChange(of: volume) { newValue in localVolume = newValue }
    }

    private var rowBackground: Color {
        if app.isPlayingAudio {
            return AMTheme.accent.opacity(isHovered ? 0.12 : 0.06)
        }
        if isHovered {
            return Color.primary.opacity(0.04)
        }
        return .clear
    }

    private var appIcon: some View {
        Group {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    )
            }
        }
    }

    private var volumeSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 3)

                Capsule()
                    .fill(isMuted ? Color.secondary.opacity(0.3) : AMTheme.accent)
                    .frame(width: max(0, geometry.size.width * localVolume), height: 3)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newVolume = max(0, min(1, value.location.x / geometry.size.width))
                        localVolume = newVolume
                        onVolumeChange(newVolume)
                    }
            )
        }
        .frame(width: 72, height: 20)
    }

    private var volumeLabel: String {
        if isMuted { return "—" }
        return "\(Int(localVolume * 100))"
    }
}

// MARK: - Compact Device Row (Popover)

struct DeviceRowCompact: View {
    let device: AudioDevice
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.type.sfSymbol)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? AMTheme.deviceAccent(for: device.type) : .secondary)
                .frame(width: 20)

            Text(device.name)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AMTheme.accent)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundFill)
        )
        .contentShape(Rectangle())
    }

    private var backgroundFill: Color {
        if isSelected {
            return AMTheme.accent.opacity(0.1)
        }
        if isHovered {
            return Color.primary.opacity(0.04)
        }
        return .clear
    }
}

// MARK: - Button Styles

struct SubtleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04))
            )
    }
}

struct PopoverButtonStyle: ButtonStyle {
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isPrimary ? .white : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isPrimary
                            ? AnyShapeStyle(AMTheme.accent.opacity(configuration.isPressed ? 0.85 : 1))
                            : AnyShapeStyle(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.05))
                    )
            )
    }
}
