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
        case .speaker: return "Speaker"
        case .headphones: return "Headphones"
        case .airpods: return "AirPods"
        case .usb: return "USB"
        case .hdmi: return "HDMI"
        case .bluetooth: return "Bluetooth"
        case .aggregate: return "Aggregate"
        case .unknown: return "Unknown"
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
}
