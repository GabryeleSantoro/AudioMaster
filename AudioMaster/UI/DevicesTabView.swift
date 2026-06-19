import SwiftUI

struct DevicesTabView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @State private var hoveredDeviceID: UUID?
    @State private var selectedDeviceID: UUID?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                Spacer().frame(height: 36)

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
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(AMTheme.surfaceElevated.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AMTheme.heroGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(AMTheme.surfaceBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Audio Devices")
                            .font(.system(size: 26, weight: .bold, design: .rounded))

                        Text("\(deviceManager.outputDevices.count + deviceManager.inputDevices.count) devices connected")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    WaveformView(barCount: 7)
                        .padding(.trailing, 4)
                }

                if let device = deviceManager.defaultOutputDevice {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AMTheme.deviceAccent(for: device.type).opacity(0.2))
                                .frame(width: 52, height: 52)
                            Image(systemName: device.type.sfSymbol)
                                .font(.system(size: 22))
                                .foregroundStyle(AMTheme.deviceAccent(for: device.type))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Now playing through")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text(device.name)
                                .font(.system(size: 17, weight: .semibold))
                                .lineLimit(1)

                            Text(device.type.displayName)
                                .font(.system(size: 12))
                                .foregroundStyle(AMTheme.deviceAccent(for: device.type))
                        }

                        Spacer()

                        Button(action: { selectDevice(device) }) {
                            Text("Default")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(AMTheme.accentGradient))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .amGlassCard(cornerRadius: 12)
                }
            }
            .padding(22)
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Output", icon: "speaker.wave.2.fill", count: deviceManager.outputDevices.count)

            VStack(spacing: 2) {
                ForEach(deviceManager.outputDevices) { device in
                    DeviceRow(
                        device: device,
                        isDefault: device.id == deviceManager.defaultOutputDevice?.id,
                        isHovered: hoveredDeviceID == device.id,
                        isExpanded: selectedDeviceID == device.id,
                        onSelect: { selectDevice(device) }
                    )
                    .onHover { hovered in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            hoveredDeviceID = hovered ? device.id : nil
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedDeviceID = selectedDeviceID == device.id ? nil : device.id
                        }
                    }
                }
            }
            .padding(6)
            .amGlassCard(cornerRadius: 14)
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Input", icon: "mic.fill", count: deviceManager.inputDevices.count)

            VStack(spacing: 2) {
                ForEach(deviceManager.inputDevices) { device in
                    DeviceRow(
                        device: device,
                        isDefault: device.id == deviceManager.defaultInputDevice?.id,
                        isHovered: hoveredDeviceID == device.id,
                        isExpanded: false,
                        onSelect: { selectInputDevice(device) }
                    )
                    .onHover { hovered in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            hoveredDeviceID = hovered ? device.id : nil
                        }
                    }
                }
            }
            .padding(6)
            .amGlassCard(cornerRadius: 14)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(AMTheme.accent)

            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.06)))
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
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(AMTheme.accent.opacity(isHovered ? 0.18 : 0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered || isDefault ? 1 : 0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
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
            return AMTheme.accent.opacity(0.08)
        }
        if isHovered {
            return Color.white.opacity(0.04)
        }
        return .clear
    }

    private var deviceIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(AMTheme.deviceAccent(for: device.type).opacity(isDefault ? 0.22 : 0.12))
                .frame(width: 38, height: 38)

            Image(systemName: device.type.sfSymbol)
                .font(.system(size: 15))
                .foregroundStyle(AMTheme.deviceAccent(for: device.type))
        }
    }

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(device.name)
                .font(.system(size: 13, weight: isDefault ? .semibold : .regular))
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
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Default")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.12))
                )
            }
        }
    }

    private var expandedDetails: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2).padding(.horizontal, 12)

            HStack(spacing: 24) {
                detailItem(label: "Channels", value: "\(device.channels)")
                detailItem(label: "Sample Rate", value: formatSampleRate(device.sampleRate))
                if let uid = device.deviceUID {
                    detailItem(label: "UID", value: String(uid.prefix(12)) + "...")
                }
                Spacer()
            }
            .padding(.horizontal, 62)
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
