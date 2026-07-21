import XCTest
@testable import AudioMaster

@MainActor
final class AppVolumeControllerTests: XCTestCase {
    private static let needsMixerTestBundleID = "com.audiomaster.tests.appvolume.needsMixer"

    private var controller: AppVolumeController!

    override func setUp() {
        super.setUp()
        let equalizerController = EqualizerController()
        equalizerController.resetToDefaults()
        controller = AppVolumeController(
            equalizerController: equalizerController,
            normalizationController: NormalizationController(
                defaults: UserDefaults(suiteName: "test.appVolume.\(UUID().uuidString)")!
            )
        )
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

    func testIncreaseLastModifiedVolume() throws {
        controller.refresh()
        guard let app = controller.apps.first else {
            throw XCTSkip("No running apps available for volume shortcut test")
        }

        controller.setGain(pid: app.pid, gain: 0.5)
        controller.increaseLastModifiedVolume()

        XCTAssertEqual(controller.sliderValue(for: app.pid), 0.55, accuracy: 0.001)
        XCTAssertEqual(controller.lastModifiedPID, app.pid)
    }

    func testDecreaseLastModifiedVolumeUnmutes() throws {
        controller.refresh()
        guard let app = controller.apps.first else {
            throw XCTSkip("No running apps available for volume shortcut test")
        }

        controller.setGain(pid: app.pid, gain: 0.5)
        controller.toggleMute(pid: app.pid)
        controller.decreaseLastModifiedVolume()

        XCTAssertFalse(controller.isMuted(pid: app.pid))
        XCTAssertEqual(controller.sliderValue(for: app.pid), 0.45, accuracy: 0.001)
    }

    func testLastModifiedVolumeFallsBackToPlayingApp() throws {
        controller.refresh()
        guard let app = controller.apps.first(where: \.isPlayingAudio) ?? controller.apps.first else {
            throw XCTSkip("No running apps available for volume shortcut test")
        }

        controller.increaseLastModifiedVolume()
        XCTAssertEqual(controller.lastModifiedPID, app.pid)
    }

    func testNeedsMixerIsFalseByDefaultForPlainEntry() {
        let entry = AppVolumeEntry(
            pid: 42_002,
            bundleID: Self.needsMixerTestBundleID,
            name: "Example",
            isPlayingAudio: true
        )
        XCTAssertFalse(controller.equalizerController.needsProcessing(for: entry.bundleID))
        XCTAssertFalse(controller.needsMixerForTesting(for: entry))
    }

    func testNeedsMixerIsTrueWhenNormalizationEnabled() {
        controller.normalizationController.isEnabled = true

        let entry = AppVolumeEntry(
            pid: 42_003,
            bundleID: Self.needsMixerTestBundleID,
            name: "Example",
            isPlayingAudio: true
        )
        XCTAssertTrue(controller.needsMixerForTesting(for: entry))
    }

    // MARK: - Default output device changes (sleep/wake regression)

    func testDefaultOutputChangeToSameDeviceDoesNotRebuild() {
        // On wake, CoreAudio re-publishes the default-output property with the
        // same device. Rebuilding taps then would re-prompt for audio capture.
        controller.seedDefaultOutputDeviceIDForTesting(77)
        XCTAssertFalse(controller.shouldRebuildForDefaultOutputChangeForTesting(newDeviceID: 77))
    }

    func testDefaultOutputChangeToDifferentDeviceRebuildsOnce() {
        controller.seedDefaultOutputDeviceIDForTesting(77)
        XCTAssertTrue(controller.shouldRebuildForDefaultOutputChangeForTesting(newDeviceID: 88))
        // Same device again: no further rebuild.
        XCTAssertFalse(controller.shouldRebuildForDefaultOutputChangeForTesting(newDeviceID: 88))
    }

    func testDefaultOutputChangeWithUnreadableDeviceDoesNotRebuild() {
        controller.seedDefaultOutputDeviceIDForTesting(77)
        XCTAssertFalse(controller.shouldRebuildForDefaultOutputChangeForTesting(newDeviceID: nil))
    }

    // MARK: - Tap-start in-flight guard (double consent-prompt regression)

    func testSecondStartIsBlockedWhileFirstIsInFlight() {
        // Creating a process tap triggers the system audio-capture consent
        // prompt. A second start for the same pid before the first finishes
        // would create a second tap and re-prompt. The guard must block it.
        XCTAssertTrue(controller.canBeginStartForTesting(pid: 42_010))
        controller.markStartInFlightForTesting(42_010)
        XCTAssertFalse(controller.canBeginStartForTesting(pid: 42_010))
        // A different pid is unaffected.
        XCTAssertTrue(controller.canBeginStartForTesting(pid: 42_011))
    }

    func testFinishingStartClearsInFlightGuard() {
        controller.markStartInFlightForTesting(42_010)
        controller.finishStartForTesting(pid: 42_010)
        XCTAssertTrue(controller.canBeginStartForTesting(pid: 42_010))
    }

    // MARK: - Output device change preserves the tap (re-prompt regression)

    func testDefaultOutputChangeRebindsTapInsteadOfRecreating() async {
        // A genuine output-device change must re-point the existing tap at the new
        // output (rebindOutput) rather than destroying + recreating it. Recreating
        // the tap calls AudioHardwareCreateProcessTap again, which re-triggers the
        // system audio-capture consent prompt on every device change.
        let fake = FakeMixer()
        controller.injectMixerForTesting(pid: 42_020, fake)

        await controller.rebindMixerForTesting(pid: 42_020)

        XCTAssertEqual(fake.rebindCount, 1, "the existing tap should be rebound, not recreated")
        XCTAssertEqual(fake.stopCount, 0, "the tap must not be torn down on a device change")
        XCTAssertTrue(controller.isActive(pid: 42_020), "the mixer must remain active after rebind")
    }

    func testNeedsMixerReturnsToFalseWhenNormalizationDisabledAgain() {
        controller.normalizationController.isEnabled = true
        controller.normalizationController.isEnabled = false

        let entry = AppVolumeEntry(
            pid: 42_004,
            bundleID: Self.needsMixerTestBundleID,
            name: "Example",
            isPlayingAudio: true
        )
        XCTAssertFalse(controller.equalizerController.needsProcessing(for: entry.bundleID))
        XCTAssertFalse(controller.needsMixerForTesting(for: entry))
    }
}

/// Records controller interactions so tests can assert the tap is rebound rather
/// than destroyed and recreated on an output-device change, without touching
/// Core Audio.
private final class FakeMixer: AppVolumeMixing {
    private(set) var rebindCount = 0
    private(set) var stopCount = 0
    private(set) var startCount = 0

    func setGain(_ gain: Float) {}
    func updateEqualizer(_ settings: EQBandSettings?) {}
    func updateNormalization(_ settings: NormalizationSettings) {}
    func start() throws { startCount += 1 }
    func rebindOutput() throws { rebindCount += 1 }
    func stop() { stopCount += 1 }
}
