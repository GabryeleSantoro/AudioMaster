import SwiftUI

struct BatteryIndicatorView: View {
    let level: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            Image(systemName: symbolName)
                .font(.system(size: compact ? 10 : 11, weight: .medium))
                .foregroundStyle(color)

            Text(String(format: String(localized: "%lld%%"), Int64(level)))
                .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var symbolName: String {
        switch level {
        case ..<10: "battery.0"
        case ..<35: "battery.25"
        case ..<65: "battery.50"
        case ..<90: "battery.75"
        default: "battery.100"
        }
    }

    private var color: Color {
        switch level {
        case ..<15: .red
        case ..<30: .orange
        default: .secondary
        }
    }
}

struct BluetoothBatteryDetailView: View {
    let reading: BluetoothBatteryReading

    var body: some View {
        if reading.components.count <= 1 {
            BatteryIndicatorView(level: reading.primaryLevel)
        } else {
            HStack(spacing: 8) {
                ForEach(reading.components) { component in
                    VStack(spacing: 2) {
                        Text(component.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.quaternary)
                        BatteryIndicatorView(level: component.level, compact: true)
                    }
                }
            }
        }
    }
}
