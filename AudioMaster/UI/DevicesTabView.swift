import SwiftUI

struct DevicesTabView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var bluetoothManager: BluetoothDeviceManager
    @State private var hoveredDeviceID: UUID?
    @State private var selectedDeviceID: UUID?
    @State private var isOutputExpanded = true
    @State private var isInputExpanded = true

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 24)

                headerSection
                    .padding(.horizontal, 24)

                outputSection
                    .padding(.horizontal, 24)

                if !deviceManager.inputDevices.isEmpty {
                    inputSection
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Devices")
                .font(.system(size: 18, weight: .semibold))

            if let device = deviceManager.defaultOutputDevice {
                HStack(spacing: 10) {
                    Image(systemName: device.type.sfSymbol)
                        .font(.system(size: 13))
                        .foregroundStyle(AMTheme.deviceAccent(for: device.type))

                    Text(device.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text("·")
                        .foregroundStyle(.quaternary)

                    Text(device.type.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if let battery = bluetoothManager.battery(for: device) {
                        BatteryIndicatorView(level: battery.primaryLevel, compact: true)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                title: "Output",
                count: deviceManager.outputDevices.count,
                isExpanded: $isOutputExpanded
            )

            if isOutputExpanded {
                VStack(spacing: 0) {
                    ForEach(deviceManager.outputDevices) { device in
                        DeviceRow(
                            device: device,
                            isDefault: device.id == deviceManager.defaultOutputDevice?.id,
                            isHovered: hoveredDeviceID == device.id,
                            isExpanded: selectedDeviceID == device.id,
                            battery: bluetoothManager.battery(for: device),
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
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(
                title: "Input",
                count: deviceManager.inputDevices.count,
                isExpanded: $isInputExpanded
            )

            if isInputExpanded {
                VStack(spacing: 0) {
                    ForEach(deviceManager.inputDevices) { device in
                        DeviceRow(
                            device: device,
                            isDefault: device.id == deviceManager.defaultInputDevice?.id,
                            isHovered: hoveredDeviceID == device.id,
                            isExpanded: selectedDeviceID == device.id,
                            battery: bluetoothManager.battery(for: device),
                            onSelect: { selectInputDevice(device) }
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
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: LocalizedStringKey, count: Int, isExpanded: Binding<Bool>) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("(\(count))")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    var battery: BluetoothBatteryReading?
    var onSelect: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                deviceIcon
                deviceInfo
                Spacer()
                if let battery {
                    BatteryIndicatorView(level: battery.primaryLevel, compact: true)
                }

                if isDefault {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AMTheme.accent)
                } else if isHovered, let onSelect {
                    Button(action: onSelect) {
                        Text("Use")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AMTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(rowBackground)
            )

            if isExpanded {
                expandedDetails
            }
        }
        .contentShape(Rectangle())
    }

    private var rowBackground: Color {
        if isHovered {
            return Color.primary.opacity(0.03)
        }
        return .clear
    }

    private var deviceIcon: some View {
        Image(systemName: device.type.sfSymbol)
            .font(.system(size: 13))
            .foregroundStyle(isDefault ? AMTheme.deviceAccent(for: device.type) : .secondary)
            .frame(width: 24)
    }

    private var deviceInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(device.name)
                .font(.system(size: 13, weight: isDefault ? .medium : .regular))
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(device.type.displayName)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)

                if let manufacturer = device.manufacturer {
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(manufacturer)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var expandedDetails: some View {
        HStack(spacing: 20) {
            detailItem(label: "Channels", value: "\(device.channels)")
            detailItem(label: "Sample Rate", value: formatSampleRate(device.sampleRate))
            if let battery {
                detailItem(label: "Battery", value: String(format: String(localized: "%lld%%"), Int64(battery.primaryLevel)))
            }
            if let uid = device.deviceUID {
                detailItem(label: "UID", value: String(uid.prefix(12)) + "…")
            }
            Spacer()
        }
        .padding(.leading, 44)
        .padding(.vertical, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func detailItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.quaternary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func formatSampleRate(_ rate: Double) -> String {
        let kHz = rate / 1000
        if kHz == Double(Int(kHz)) {
            return String(format: String(localized: "%lld kHz"), Int64(kHz))
        }
        return String(format: String(localized: "%.1f kHz"), kHz)
    }
}
