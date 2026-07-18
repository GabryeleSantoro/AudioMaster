import XCTest
@testable import AudioMaster

@MainActor
final class RoutingPresetControllerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var port: FakeRoutingStatePort!

    override func setUp() {
        super.setUp()
        suiteName = "test.routingpresets.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        port = FakeRoutingStatePort(snapshot: Self.sampleSnapshot)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        port = nil
        suiteName = nil
        super.tearDown()
    }

    private static var sampleSnapshot: RoutingSnapshot {
        RoutingSnapshot(
            outputDeviceUID: "dev-1",
            outputDeviceName: "Speakers",
            masterVolume: 0.5,
            appVolumes: ["com.foo": AppAudioState(gain: 0.3, muted: false)],
            equalizer: EQSnapshot(enabled: true, bands: .flat),
            normalizationEnabled: true
        )
    }

    private func makeController() -> RoutingPresetController {
        RoutingPresetController(port: port, defaults: defaults)
    }

    func testStartsEmpty() {
        XCTAssertTrue(makeController().presets.isEmpty)
    }

    func testSaveCurrentCapturesSnapshotFromPort() {
        let controller = makeController()
        controller.saveCurrent(name: "Gaming")

        XCTAssertEqual(controller.presets.count, 1)
        XCTAssertEqual(controller.presets.first?.name, "Gaming")
        XCTAssertEqual(controller.presets.first?.snapshot, Self.sampleSnapshot)
    }

    func testApplyForwardsSnapshotToPort() {
        let controller = makeController()
        controller.saveCurrent(name: "Gaming")
        controller.apply(controller.presets[0])

        XCTAssertEqual(port.appliedSnapshots, [Self.sampleSnapshot])
    }

    func testNormalizationEnabledRoundTripsThroughSaveAndApply() {
        let controller = makeController()
        let preset = controller.saveCurrent(name: "Gaming")

        XCTAssertEqual(preset.snapshot.normalizationEnabled, true)

        controller.apply(preset)

        XCTAssertEqual(port.appliedSnapshots.last?.normalizationEnabled, true)
    }

    func testRenameUpdatesName() {
        let controller = makeController()
        controller.saveCurrent(name: "Old")
        controller.rename(controller.presets[0], to: "New")

        XCTAssertEqual(controller.presets[0].name, "New")
    }

    func testDeleteRemovesPreset() {
        let controller = makeController()
        controller.saveCurrent(name: "A")
        controller.delete(controller.presets[0])

        XCTAssertTrue(controller.presets.isEmpty)
    }

    func testUpdateSnapshotRecapturesFromPort() {
        let controller = makeController()
        controller.saveCurrent(name: "A")

        let updated = RoutingSnapshot(masterVolume: 0.9)
        port.snapshotToReturn = updated
        controller.updateSnapshot(controller.presets[0])

        XCTAssertEqual(controller.presets[0].snapshot, updated)
    }

    func testPresetsPersistAcrossControllerInstances() {
        makeController().saveCurrent(name: "Persisted")

        let reloaded = makeController()

        XCTAssertEqual(reloaded.presets.count, 1)
        XCTAssertEqual(reloaded.presets.first?.name, "Persisted")
    }
}

@MainActor
final class FakeRoutingStatePort: RoutingStatePort {
    var snapshotToReturn: RoutingSnapshot
    private(set) var appliedSnapshots: [RoutingSnapshot] = []

    init(snapshot: RoutingSnapshot) {
        self.snapshotToReturn = snapshot
    }

    func captureSnapshot() -> RoutingSnapshot {
        snapshotToReturn
    }

    func apply(_ snapshot: RoutingSnapshot) {
        appliedSnapshots.append(snapshot)
    }
}

/// Exercises the real `LiveRoutingStatePort` (backed by real managers/controllers, no fakes)
/// to prove the normalization enable/disable state survives a capture/apply round trip, which
/// is what a save-preset-then-apply-preset flow relies on end to end.
@MainActor
final class LiveRoutingStatePortNormalizationTests: XCTestCase {
    private var persistence: PersistenceController!
    private var deviceManager: AudioDeviceManager!
    private var equalizerController: EqualizerController!
    private var normalizationController: NormalizationController!
    private var appVolumeController: AppVolumeController!
    private var port: LiveRoutingStatePort!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.liveRoutingStatePort.normalization.\(UUID().uuidString)"

        persistence = PersistenceController(inMemory: true)
        deviceManager = AudioDeviceManager(persistence: persistence)

        equalizerController = EqualizerController()
        equalizerController.resetToDefaults()

        normalizationController = NormalizationController(defaults: UserDefaults(suiteName: suiteName)!)

        appVolumeController = AppVolumeController(
            equalizerController: equalizerController,
            normalizationController: normalizationController
        )

        port = LiveRoutingStatePort(
            deviceManager: deviceManager,
            appVolumeController: appVolumeController,
            equalizerController: equalizerController,
            normalizationController: normalizationController
        )
    }

    override func tearDown() {
        port = nil
        appVolumeController.stopMonitoring()
        appVolumeController = nil
        normalizationController = nil
        equalizerController = nil
        deviceManager.stopMonitoring()
        deviceManager = nil
        persistence = nil
        UserDefaults().removePersistentDomain(forName: suiteName)
        suiteName = nil
        super.tearDown()
    }

    func testNormalizationEnabledRoundTripsThroughCaptureAndApply() {
        normalizationController.isEnabled = true

        let snapshot = port.captureSnapshot()
        XCTAssertEqual(snapshot.normalizationEnabled, true)

        normalizationController.isEnabled = false
        port.apply(snapshot)

        XCTAssertTrue(normalizationController.isEnabled)
    }

    func testApplyingSnapshotWithNilNormalizationLeavesCurrentStateUnchanged() {
        normalizationController.isEnabled = true

        port.apply(RoutingSnapshot(normalizationEnabled: nil))

        XCTAssertTrue(normalizationController.isEnabled)

        normalizationController.isEnabled = false
        port.apply(RoutingSnapshot(normalizationEnabled: nil))

        XCTAssertFalse(normalizationController.isEnabled)
    }
}
