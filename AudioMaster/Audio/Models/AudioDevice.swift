import Foundation

struct AudioDevice: Identifiable, Equatable, Sendable {
    let id: UUID
    let coreAudioID: UInt32
    let name: String
    let type: DeviceType
    let isInput: Bool
    let isOutput: Bool
    let channels: Int
    let sampleRate: Double
    let manufacturer: String?
    let isSystemDefault: Bool
    let isConnected: Bool
    let deviceUID: String?

    static func stableID(for deviceUID: String?) -> UUID {
        guard let deviceUID, !deviceUID.isEmpty else {
            return UUID()
        }

        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in deviceUID.utf8.enumerated() {
            bytes[index % 16] = bytes[index % 16] &+ byte
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
