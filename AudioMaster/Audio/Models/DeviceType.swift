import Foundation

enum DeviceType: String, Codable, CaseIterable, Sendable {
    case speaker
    case headphones
    case airpods
    case usb
    case hdmi
    case bluetooth
    case aggregate
    case unknown

    var displayName: String {
        switch self {
        case .speaker: return String(localized: "Speaker")
        case .headphones: return String(localized: "Headphones")
        case .airpods: return String(localized: "AirPods")
        case .usb: return String(localized: "USB")
        case .hdmi: return String(localized: "HDMI")
        case .bluetooth: return String(localized: "Bluetooth")
        case .aggregate: return String(localized: "Aggregate")
        case .unknown: return String(localized: "Unknown")
        }
    }

    var sfSymbol: String {
        switch self {
        case .speaker: return "hifispeaker.2"
        case .headphones: return "headphones"
        case .airpods: return "airpodspro"
        case .usb: return "cable.connector"
        case .hdmi: return "tv"
        case .bluetooth: return "wave.3.right"
        case .aggregate: return "square.stack.3d.up"
        case .unknown: return "questionmark.circle"
        }
    }

    var supportsBatteryIndicator: Bool {
        switch self {
        case .airpods, .headphones, .bluetooth: true
        default: false
        }
    }
}
