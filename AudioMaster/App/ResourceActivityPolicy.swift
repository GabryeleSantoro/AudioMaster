import Foundation

enum AppUIVisibility: Equatable {
    case hidden
    case popoverVisible
    case mainWindowVisible
}

struct ResourceActivitySnapshot: Equatable {
    var uiVisibility: AppUIVisibility
    var activeMixerCount: Int
    var hasConnectedBluetoothAudio: Bool
    var isSystemSleeping: Bool
}

enum ResourceActivityPolicy {
    static func appVolumeRefreshInterval(for snapshot: ResourceActivitySnapshot) -> TimeInterval {
        if snapshot.isSystemSleeping { return 0 }
        switch snapshot.uiVisibility {
        case .mainWindowVisible, .popoverVisible:
            return 2.0
        case .hidden:
            return snapshot.activeMixerCount > 0 ? 5.0 : 15.0
        }
    }

    static func bluetoothRefreshInterval(for snapshot: ResourceActivitySnapshot) -> TimeInterval {
        if snapshot.isSystemSleeping { return 0 }
        if snapshot.uiVisibility != .hidden { return 30.0 }
        return snapshot.hasConnectedBluetoothAudio ? 90.0 : 300.0
    }

    static func shouldRunHeavyBluetoothBatteryScan(for snapshot: ResourceActivitySnapshot) -> Bool {
        if snapshot.isSystemSleeping { return false }
        if snapshot.uiVisibility != .hidden { return true }
        return snapshot.hasConnectedBluetoothAudio
    }
}
