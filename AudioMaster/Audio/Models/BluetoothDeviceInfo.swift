import Foundation

struct BluetoothBatteryComponent: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case main
        case left
        case right
        case caseUnit = "case"
    }

    let kind: Kind
    let level: Int

    var id: String { kind.rawValue }

    var label: String {
        switch kind {
        case .main: String(localized: "Battery")
        case .left: String(localized: "Left")
        case .right: String(localized: "Right")
        case .caseUnit: String(localized: "Case")
        }
    }
}

struct BluetoothBatteryReading: Equatable, Sendable {
    let primaryLevel: Int
    let components: [BluetoothBatteryComponent]

    init(primaryLevel: Int, components: [BluetoothBatteryComponent] = []) {
        self.primaryLevel = primaryLevel
        self.components = components.isEmpty
            ? [BluetoothBatteryComponent(kind: .main, level: primaryLevel)]
            : components
    }
}

struct BluetoothDeviceInfo: Identifiable, Equatable, Sendable {
    let id: String
    let address: String
    let name: String
    let isConnected: Bool
    let isPaired: Bool
    let battery: BluetoothBatteryReading?
    let matchedAudioDeviceUID: String?
    let isAudioDevice: Bool

    var normalizedAddress: String {
        BluetoothNameMatcher.normalizedAddress(address)
    }
}

enum BluetoothNameMatcher {
    static func normalizedAddress(_ address: String) -> String {
        address
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    static func normalizedName(_ name: String) -> String {
        name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "'s", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizedName(lhs)
        let right = normalizedName(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right || left.contains(right) || right.contains(left)
    }
}
