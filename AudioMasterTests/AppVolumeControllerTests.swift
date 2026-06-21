import XCTest
@testable import AudioMaster

@MainActor
final class AppVolumeControllerTests: XCTestCase {
    private var controller: AppVolumeController!

    override func setUp() {
        super.setUp()
        controller = AppVolumeController()
    }

    override func tearDown() {
        controller.stopMonitoring()
        controller = nil
        super.tearDown()
    }

    func testDefaultGainIsUnity() {
        XCTAssertEqual(controller.gain(for: 42_001), 1.0, accuracy: 0.001)
    }

    func testDefaultSliderValueIsUnity() {
        XCTAssertEqual(controller.sliderValue(for: 42_001), 1.0, accuracy: 0.001)
    }

    func testSetGainUpdatesSliderValue() {
        controller.setGain(pid: 42_001, gain: 0.6)
        XCTAssertEqual(controller.sliderValue(for: 42_001), 0.6, accuracy: 0.001)
    }

    func testSetGainClampsHighValues() {
        controller.setGain(pid: 42_001, gain: 3.0)
        XCTAssertEqual(controller.sliderValue(for: 42_001), Double(VolumeMath.maxSliderValue), accuracy: 0.001)
        XCTAssertEqual(controller.gain(for: 42_001), VolumeMath.maxSliderValue, accuracy: 0.001)
    }

    func testSetGainAllowsBoostAboveUnity() {
        controller.setGain(pid: 42_001, gain: 1.5)
        XCTAssertEqual(controller.sliderValue(for: 42_001), 1.5, accuracy: 0.001)
        XCTAssertEqual(controller.gain(for: 42_001), 1.5, accuracy: 0.001)
    }

    func testSetGainClampsLowValues() {
        controller.setGain(pid: 42_001, gain: -0.5)
        XCTAssertEqual(controller.sliderValue(for: 42_001), 0, accuracy: 0.001)
    }

    func testToggleMuteSilencesGain() {
        controller.setGain(pid: 42_001, gain: 0.8)
        controller.toggleMute(pid: 42_001)

        XCTAssertTrue(controller.isMuted(pid: 42_001))
        XCTAssertEqual(controller.gain(for: 42_001), 0, accuracy: 0.001)
    }

    func testToggleMuteRestoresGain() {
        controller.setGain(pid: 42_001, gain: 0.8)
        controller.toggleMute(pid: 42_001)
        controller.toggleMute(pid: 42_001)

        XCTAssertFalse(controller.isMuted(pid: 42_001))
        XCTAssertGreaterThan(controller.gain(for: 42_001), 0)
    }

    func testRefreshBuildsAppListWithoutCrashing() {
        controller.refresh()
        XCTAssertFalse(controller.apps.isEmpty)
    }

    func testStartAndStopMonitoringIsIdempotent() {
        controller.startMonitoring()
        controller.startMonitoring()
        controller.stopMonitoring()
        controller.stopMonitoring()
    }
}
