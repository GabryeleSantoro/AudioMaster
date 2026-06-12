import SwiftUI

struct DevicesTabView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @State private var hoveredDeviceID: UUID?
    @State private var selectedDeviceID: UUID?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 40)

                pageTitle

                outputSection

                if !deviceManager.inputDevices.isEmpty {
                    inputSection
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Page Title

    private var pageTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Devices")
                .font(.system(size: 22, weight: .semibold))

            Text("\(deviceManager.outputDevices.count + deviceManager.inputDevices.count) devices connected")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Output", count: deviceManager.outputDevices.count)

            VStack(spacing: 1) {
                ForEach(deviceManager.outputDevices) { device in
                    DeviceRow(
                        device: device,
                        isDefault: device.id == deviceManager.defaultOutputDevice?.id,
                        isHovered: hoveredDeviceID == device.id,
                        isExpanded: selectedDeviceID == device.id
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

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Input", count: deviceManager.inputDevices.count)

            VStack(spacing: 1) {
                ForEach(deviceManager.inputDevices) { device in
                    DeviceRow(
                        device: device,
                        isDefault: device.id == deviceManager.defaultInputDevice?.id,
                        isHovered: hoveredDeviceID == device.id,
                        isExpanded: false
                    )
                    .onHover { hovered in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            hoveredDeviceID = hovered ? device.id : nil
                        }
                    }
                }
            }
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

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Device Row (Full)

struct DeviceRow: View {
    let device: AudioDevice
    let isDefault: Bool
    let isHovered: Bool
    let isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                deviceIcon
                deviceInfo
                Spacer()
                statusBadge
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )

            if isExpanded {
                expandedDetails
            }
        }
        .contentShape(Rectangle())
    }

    private var deviceIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isDefault ? 0.08 : 0.04))
                .frame(width: 34, height: 34)

            Image(systemName: device.type.sfSymbol)
                .font(.system(size: 14))
                .foregroundStyle(isDefault ? .primary : .secondary)
        }
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
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 5, height: 5)
                    Text("Default")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                )
            }
        }
    }

    private var expandedDetails: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.3).padding(.horizontal, 14)

            HStack(spacing: 20) {
                detailItem(label: "Channels", value: "\(device.channels)")
                detailItem(label: "Sample Rate", value: formatSampleRate(device.sampleRate))
                if let uid = device.deviceUID {
                    detailItem(label: "UID", value: String(uid.prefix(12)) + "...")
                }
                Spacer()
            }
            .padding(.horizontal, 60)
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
