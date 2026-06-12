import SwiftUI

struct PopoverView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    let menuBarController: MenuBarController

    @State private var hoveredDeviceID: UUID?
    @State private var systemVolume: Double = 0.75

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            deviceList
            Divider().opacity(0.5)
            volumeSection
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("OUTPUT")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if let current = deviceManager.defaultOutputDevice {
                    Text(current.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
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
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredDeviceID = hovered ? device.id : nil
                        }
                    }
                    .onTapGesture {
                        selectDevice(device)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 220)
    }

    // MARK: - Volume

    private var volumeSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: geometry.size.width * systemVolume, height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            systemVolume = max(0, min(1, value.location.x / geometry.size.width))
                        }
                )
            }
            .frame(height: 20)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: { menuBarController.openMainWindow() }) {
                Text("Settings")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SubtleButtonStyle())

            Spacer()

            Button(action: { menuBarController.openMainWindow() }) {
                Text("App Volumes")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(SubtleButtonStyle())
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
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 20)

            Text(device.name)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Button Style

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
