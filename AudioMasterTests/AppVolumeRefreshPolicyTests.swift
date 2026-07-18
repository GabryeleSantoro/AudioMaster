import XCTest
@testable import AudioMaster

@MainActor
final class AppVolumeRefreshPolicyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "com.audiomaster.appVolumeGains")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "com.audiomaster.appVolumeGains")
        super.tearDown()
    }

    func testRefreshDoesNotReplaceAppsWhenNothingChanged() {
        let equalizerController = EqualizerController()
        let normalizationController = NormalizationController(
            defaults: UserDefaults(suiteName: "test.appVolumeRefresh.\(UUID().uuidString)")!
        )
        let controller = AppVolumeController(
            equalizerController: equalizerController,
            normalizationController: normalizationController
        )

        controller.refresh()
        let first = controller.apps

        controller.refresh()

        XCTAssertEqual(controller.apps, first)
    }

    func testAdaptiveTimerUsesCoordinatorInterval() {
        let equalizerController = EqualizerController()
        let normalizationController = NormalizationController(
            defaults: UserDefaults(suiteName: "test.appVolumeRefresh.\(UUID().uuidString)")!
        )
        let controller = AppVolumeController(
            equalizerController: equalizerController,
            normalizationController: normalizationController
        )
        let coordinator = ResourceActivityCoordinator()
        controller.bind(activityCoordinator: coordinator)

        coordinator.setUIVisibility(.hidden)
        controller.startMonitoring()
        XCTAssertEqual(controller.currentRefreshIntervalForTesting, 15.0)

        coordinator.setUIVisibility(.popoverVisible)
        controller.applyRefreshPolicyForTesting()
        XCTAssertEqual(controller.currentRefreshIntervalForTesting, 2.0)
    }
}
