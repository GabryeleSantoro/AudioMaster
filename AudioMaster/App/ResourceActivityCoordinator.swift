import Combine
import Foundation

@MainActor
final class ResourceActivityCoordinator: ObservableObject {
    @Published private(set) var snapshot: ResourceActivitySnapshot

    init(
        snapshot: ResourceActivitySnapshot = ResourceActivitySnapshot(
            uiVisibility: .hidden,
            activeMixerCount: 0,
            hasConnectedBluetoothAudio: false,
            isSystemSleeping: false
        )
    ) {
        self.snapshot = snapshot
    }

    func setUIVisibility(_ visibility: AppUIVisibility) {
        guard snapshot.uiVisibility != visibility else { return }
        snapshot.uiVisibility = visibility
    }

    func setActiveMixerCount(_ count: Int) {
        guard snapshot.activeMixerCount != count else { return }
        snapshot.activeMixerCount = max(0, count)
    }

    func setHasConnectedBluetoothAudio(_ value: Bool) {
        guard snapshot.hasConnectedBluetoothAudio != value else { return }
        snapshot.hasConnectedBluetoothAudio = value
    }

    func setSystemSleeping(_ value: Bool) {
        guard snapshot.isSystemSleeping != value else { return }
        snapshot.isSystemSleeping = value
    }
}
