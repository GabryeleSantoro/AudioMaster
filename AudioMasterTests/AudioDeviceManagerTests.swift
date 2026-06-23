import XCTest
@testable import AudioMaster

final class AudioDeviceManagerTests: XCTestCase {
    private var persistence: PersistenceController!
    private var manager: AudioDeviceManager!

    @MainActor
    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        manager = AudioDeviceManager(persistence: persistence)
    }

    @MainActor
    override func tearDown() {
        manager.stopMonitoring()
        manager = nil
        persistence = nil
        super.tearDown()
    }

    @MainActor
    func testEnumerationFindsAtLeastOneOutputDevice() async {
        manager.refreshDevices()

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if !manager.outputDevices.isEmpty { break }
        }

        XCTAssertFalse(manager.outputDevices.isEmpty)
    }

    @MainActor
    func testDefaultOutputIsInEnumeratedList() async {
        manager.refreshDevices()

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if manager.defaultOutputDevice != nil { break }
        }

        guard let defaultOutput = manager.defaultOutputDevice else {
            return XCTFail("No default output device found")
        }

        XCTAssertTrue(
            manager.outputDevices.contains(where: { $0.coreAudioID == defaultOutput.coreAudioID })
        )
    }

    @MainActor
    func testRefreshPersistsDevicesToStore() async throws {
        manager.refreshDevices()

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if !manager.outputDevices.isEmpty { break }
        }

        let stored = try persistence.fetchDevices()
        XCTAssertFalse(stored.isEmpty)
    }

    @MainActor
    func testMonitoringCanStartAndStopSafely() {
        manager.startMonitoring()
        manager.startMonitoring()
        manager.stopMonitoring()
        manager.stopMonitoring()
    }

    func testInternalManagedDevicesAreExcludedFromEnumeration() {
        XCTAssertTrue(CoreAudioHelpers.isInternalManagedDevice(name: "AudioMaster-1234"))
        XCTAssertTrue(CoreAudioHelpers.isInternalManagedDevice(name: "AudioMaster-tap-5678"))
        XCTAssertFalse(CoreAudioHelpers.isInternalManagedDevice(name: "MacBook Pro Speakers"))
        XCTAssertFalse(CoreAudioHelpers.isInternalManagedDevice(name: "External USB Audio"))
    }

    @MainActor
    func testEnumeratedDevicesExcludeAudioMasterInternals() async {
        manager.refreshDevices()

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if !manager.outputDevices.isEmpty { break }
        }

        let allDevices = manager.outputDevices + manager.inputDevices
        XCTAssertFalse(allDevices.contains { CoreAudioHelpers.isInternalManagedDevice(name: $0.name) })
    }
}
