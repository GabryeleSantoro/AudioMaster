import Foundation

/// Per-app volume state captured in a routing preset, keyed by bundle identifier.
struct AppAudioState: Codable, Equatable {
    var gain: Float
    var muted: Bool
}

/// Global equalizer state captured in a routing preset.
struct EQSnapshot: Codable, Equatable {
    var enabled: Bool
    var bands: EQBandSettings
}

/// An immutable capture of the audio setup a routing preset restores.
///
/// Every field is optional (or empty) so a preset only touches what it captured:
/// a `nil` `masterVolume` leaves the system volume alone, an empty `appVolumes`
/// leaves per-app volumes alone, and so on.
struct RoutingSnapshot: Codable, Equatable {
    var outputDeviceUID: String?
    var outputDeviceName: String?
    var masterVolume: Double?
    var appVolumes: [String: AppAudioState]
    var equalizer: EQSnapshot?
    var normalizationEnabled: Bool?

    init(
        outputDeviceUID: String? = nil,
        outputDeviceName: String? = nil,
        masterVolume: Double? = nil,
        appVolumes: [String: AppAudioState] = [:],
        equalizer: EQSnapshot? = nil,
        normalizationEnabled: Bool? = nil
    ) {
        self.outputDeviceUID = outputDeviceUID
        self.outputDeviceName = outputDeviceName
        self.masterVolume = masterVolume
        self.appVolumes = appVolumes
        self.equalizer = equalizer
        self.normalizationEnabled = normalizationEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        outputDeviceUID = try container.decodeIfPresent(String.self, forKey: .outputDeviceUID)
        outputDeviceName = try container.decodeIfPresent(String.self, forKey: .outputDeviceName)
        masterVolume = try container.decodeIfPresent(Double.self, forKey: .masterVolume)
        appVolumes = try container.decodeIfPresent([String: AppAudioState].self, forKey: .appVolumes) ?? [:]
        equalizer = try container.decodeIfPresent(EQSnapshot.self, forKey: .equalizer)
        normalizationEnabled = try container.decodeIfPresent(Bool.self, forKey: .normalizationEnabled)
    }
}

/// A named, persistable audio setup the user can reapply with one click.
struct RoutingPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var snapshot: RoutingSnapshot

    init(id: UUID = UUID(), name: String, snapshot: RoutingSnapshot) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
    }
}
