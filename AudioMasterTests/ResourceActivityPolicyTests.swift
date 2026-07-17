import XCTest
@testable import AudioMaster

final class ResourceActivityPolicyTests: XCTestCase {
    func testHiddenIdleUsesSlowAppVolumePolling() {
        let snapshot = ResourceActivitySnapshot(
            uiVisibility: .hidden,
            activeMixerCount: 0,
            hasConnectedBluetoothAudio: false,
            isSystemSleeping: false
        )
        XCTAssertEqual(ResourceActivityPolicy.appVolumeRefreshInterval(for: snapshot), 15.0)
    }

    func testVisibleUIUsesFastAppVolumePolling() {
        let snapshot = ResourceActivitySnapshot(
            uiVisibility: .popoverVisible,
            activeMixerCount: 0,
            hasConnectedBluetoothAudio: false,
            isSystemSleeping: false
        )
        XCTAssertEqual(ResourceActivityPolicy.appVolumeRefreshInterval(for: snapshot), 2.0)
    }

    func testActiveMixersKeepModeratePollingWhenHidden() {
        let snapshot = ResourceActivitySnapshot(
            uiVisibility: .hidden,
            activeMixerCount: 2,
            hasConnectedBluetoothAudio: false,
            isSystemSleeping: false
        )
        XCTAssertEqual(ResourceActivityPolicy.appVolumeRefreshInterval(for: snapshot), 5.0)
    }

    func testSleepPausesPolling() {
        let snapshot = ResourceActivitySnapshot(
            uiVisibility: .mainWindowVisible,
            activeMixerCount: 3,
            hasConnectedBluetoothAudio: true,
            isSystemSleeping: true
        )
        XCTAssertEqual(ResourceActivityPolicy.appVolumeRefreshInterval(for: snapshot), 0)
        XCTAssertEqual(ResourceActivityPolicy.bluetoothRefreshInterval(for: snapshot), 0)
    }

    func testHeavyBluetoothScanOnlyWhenNeeded() {
        let idle = ResourceActivitySnapshot(
            uiVisibility: .hidden,
            activeMixerCount: 0,
            hasConnectedBluetoothAudio: false,
            isSystemSleeping: false
        )
        XCTAssertFalse(ResourceActivityPolicy.shouldRunHeavyBluetoothBatteryScan(for: idle))

        let btActive = ResourceActivitySnapshot(
            uiVisibility: .hidden,
            activeMixerCount: 0,
            hasConnectedBluetoothAudio: true,
            isSystemSleeping: false
        )
        XCTAssertTrue(ResourceActivityPolicy.shouldRunHeavyBluetoothBatteryScan(for: btActive))
    }
}
