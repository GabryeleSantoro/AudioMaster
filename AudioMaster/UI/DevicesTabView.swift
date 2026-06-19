import SwiftUI

struct DevicesTabView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @State private var hoveredDeviceID: UUID?
    @State private var selectedDeviceID: UUID?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 32)

                heroCard
                    .padding(.horizontal, 28)

                outputSection
                    .padding(.horizontal, 28)

                if !deviceManager.inputDevices.isEmpty {
                    inputSection
                        .padding(.horizontal, 28)
                }

                Spacer(minLength: 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Devices")
                        .font(.system(size: 24, weight: .bold))

                    Text("\(deviceManager.outputDevices.count + deviceManager.inputDevices.count) devices connected")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                WaveformView(barCount: 5)
            }

            if let device = deviceManager.defaultOutputDevice {
                HStack(spacing: 12) {
                    Image(systemName: device.type.sfSymbol)
                        .font(.system(size: 18))
                        .foregroundStyle(AMTheme.deviceAccent(for: device.type))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AMTheme.deviceAccent(for: device.type).opacity(0.1))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Now playing through")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)

                        Text(device.name)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)

                        Text(device.type.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("Default")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .padding(12)
                .amGlassCard(cornerRadius: 8)
            }
        }
        .padding(20)
        .amGlassCard(cornerRadius: 12)
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Output", icon: "speaker.wave.2.fill", count: deviceManager.outputDevices.count)

            VStack(spacing: 1) {
                ForEach(deviceManager.outputDevices) { device in
                    DeviceRow(
                        device: device,
                        isDefault: device.id == deviceManager.defaultOutputDevice?.id,
                        isHovered: hoveredDeviceID == device.id,
                        isExpanded: selectedDeviceID == device.id,
                        onSelect: { selectDevice(device) }
                    )
                    .onHover { hovered in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            hoveredDeviceID = hovered ? device.id : nil
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDeviceID = selectedDeviceID == device.id ? nil : device.id
                        }
                    }
                }
            }
            .padding(4)
            .amGlassCard(cornerRadius: 10)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Input", icon: "mic.fill", count: deviceManager.inputDevices.count)

            VStack(spacing: 1) {
                ForEach(deviceManager.inputDevices) { device in
                    DeviceRow(
                        device: device,
                        isDefault: device.id == deviceManager.defaultInputDevice?.id,
                        isHovered: hoveredDeviceID == device.id,
                        isExpanded: false,
                        onSelect: { selectInputDevice(device) }
                    )
                    .onHover { hovered in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            hoveredDeviceID = hovered ? device.id : nil
                        }
                    }
                }
            }
            .padding(4)
            .amGlassCard(cornerRadius: 10)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func selectDevice(_ device: AudioDevice) {
        do {
            try deviceManager.setDefaultOutputDevice(device)
        } catch {
            print("[AudioMaster] Failed to switch device: \(error.localizedDescription)")
        }
    }

    private func selectInputDevice(_ device: AudioDevice) {
        do {
            try deviceManager.setDefaultInputDevice(device)
        } catch {
            print("[AudioMaster] Failed to switch input device: \(error.localizedDescription)")
        }
    }
}

// MARK: - Device Row (Full)

struct DeviceRow: View {
    let device: AudioDevice
    let isDefault: Bool
    let isHovered: Bool
    let isExpanded: Bool
    var onSelect: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                deviceIcon
                deviceInfo
                Spacer()
                statusBadge

                if !isDefault, let onSelect {
                    Button(action: onSelect) {
                        Text("Use")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AMTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AMTheme.accent.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered ? 1 : 0.5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(rowBackground)
            )

            if isExpanded {
                expandedDetails
            }
        }
        .contentShape(Rectangle())
    }

    private var rowBackground: Color {
        if isDefault {
            return AMTheme.accent.opacity(0.06)
        }
        if isHovered {
            return Color.primary.opacity(0.03)
        }
        return .clear
    }

    private var deviceIcon: some View {
        Image(systemName: device.type.sfSymbol)
            .font(.system(size: 14))
            .foregroundStyle(AMTheme.deviceAccent(for: device.type))
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(AMTheme.deviceAccent(for: device.type).opacity(0.1))
            )
    }

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(device.name)
                .font(.system(size: 13, weight: isDefault ? .medium : .regular))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(device.type.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)

                if let manufacturer = device.manufacturer {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(manufacturer)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var statusBadge: some View {
        Group {
            if isDefault {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                    Text("Default")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
    }

    private var expandedDetails: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15).padding(.horizontal, 10)

            HStack(spacing: 24) {
                detailItem(label: "Channels", value: "\(device.channels)")
                detailItem(label: "Sample Rate", value: formatSampleRate(device.sampleRate))
                if let uid = device.deviceUID {
                    detailItem(label: "UID", value: String(uid.prefix(12)) + "...")
                }
                Spacer()
            }
            .padding(.horizontal, 54)
            .padding(.vertical, 10)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func detailItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.quaternary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func formatSampleRate(_ rate: Double) -> String {
        let kHz = rate / 1000
        if kHz == Double(Int(kHz)) {
            return "\(Int(kHz)) kHz"
        }
        return String(format: "%.1f kHz", kHz)
    }
}
