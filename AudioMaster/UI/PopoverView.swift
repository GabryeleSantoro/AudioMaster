import SwiftUI

struct PopoverView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var appVolumeController: AppVolumeController
    let menuBarController: MenuBarController

    @State private var hoveredDeviceID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            deviceList
            Divider().opacity(0.3)
            volumeSection
            Divider().opacity(0.3)
            footer
        }
        .frame(width: 320)
        .background(AMTheme.surface)
        .onAppear {
            appVolumeController.refreshSystemVolume()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AMTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("OUTPUT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)

                if let current = deviceManager.defaultOutputDevice {
                    Text(current.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
            }

            Spacer()

            WaveformView(barCount: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Device List

    private var deviceList: some View {
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
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .frame(maxHeight: 220)
    }

    // MARK: - Volume

    private var volumeSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Master Volume")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(appVolumeController.systemVolume * 100))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

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
                .frame(height: 20)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: { menuBarController.openMainWindow() }) {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(PopoverButtonStyle())

            Spacer()

            Button(action: { menuBarController.openMainWindow() }) {
                Label("App Volumes", systemImage: "square.grid.2x2")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(PopoverButtonStyle(isPrimary: true))
        }
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
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isPrimary
                            ? AnyShapeStyle(AMTheme.accent.opacity(configuration.isPressed ? 0.8 : 1))
                            : AnyShapeStyle(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.05))
                    )
            )
    }
}
