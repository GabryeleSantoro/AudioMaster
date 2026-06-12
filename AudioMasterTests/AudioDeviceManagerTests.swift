import CoreAudio
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

    // MARK: - Device Enumeration

    @MainActor
    func testEnumerationFindsAtLeastOneOutputDevice() async {
        manager.refreshDevices()

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if !manager.outputDevices.isEmpty { break }
        }

        XCTAssertFalse(manager.outputDevices.isEmpty, "Expected at least one output device")
    }

    @MainActor
    func testDefaultOutputIsInEnumeratedList() async {
        manager.refreshDevices()

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if manager.defaultOutputDevice != nil { break }
        }

        guard let defaultOutput = manager.defaultOutputDevice else {
            XCTFail("No default output device found")
            return
        }
        XCTAssertTrue(
            manager.outputDevices.contains(where: { $0.coreAudioID == defaultOutput.coreAudioID }),
            "Default output should appear in output device list"
        )
    }

    // MARK: - Device Type Inference

    func testInferDeviceTypeAirPods() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "Gabriele's AirPods Pro",
            transportType: kAudioDeviceTransportTypeBluetooth,
            isAggregate: false
        )
        XCTAssertEqual(type, .airpods)
    }

    func testInferDeviceTypeUSB() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "Scarlett 2i2",
            transportType: kAudioDeviceTransportTypeUSB,
            isAggregate: false
        )
        XCTAssertEqual(type, .usb)
    }

    func testInferDeviceTypeAggregate() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "Multi-Output",
            transportType: 0,
            isAggregate: true
        )
        XCTAssertEqual(type, .aggregate)
    }

    func testInferDeviceTypeBuiltInSpeaker() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "MacBook Pro Speakers",
            transportType: kAudioDeviceTransportTypeBuiltIn,
            isAggregate: false
        )
        XCTAssertEqual(type, .speaker)
    }

    // MARK: - Persistence

    func testPersistenceRoundTrip() throws {
        let device = AudioDevice(
            id: UUID(),
            coreAudioID: 42,
            name: "Test Speaker",
            type: .speaker,
            isInput: false,
            isOutput: true,
            channels: 2,
            sampleRate: 48000,
            manufacturer: "Apple Inc.",
            isSystemDefault: true,
            isConnected: true,
            deviceUID: "test-device-uid-001"
        )

        try persistence.upsertDevice(device)
        let fetched = try persistence.fetchDevices()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test Speaker")
        XCTAssertEqual(fetched.first?.type, .speaker)
        XCTAssertEqual(fetched.first?.deviceUID, "test-device-uid-001")
        XCTAssertEqual(fetched.first?.sampleRate, 48000)
    }

    func testStableIDIsDeterministic() {
        let uid = "CoreAudio-UID-ABC123"
        let id1 = AudioDevice.stableID(for: uid)
        let id2 = AudioDevice.stableID(for: uid)
        XCTAssertEqual(id1, id2)
    }

    // MARK: - Volume Math

    func testLinearToDecibels() {
        XCTAssertEqual(VolumeMath.linearToDecibels(1.0), 0, accuracy: 0.001)
        XCTAssertEqual(VolumeMath.linearToDecibels(0.5), -6.02, accuracy: 0.1)
        XCTAssertEqual(VolumeMath.linearToDecibels(0), VolumeMath.minDecibels)
    }

    func testDecibelsToLinear() {
        XCTAssertEqual(VolumeMath.decibelsToLinear(0), 1.0, accuracy: 0.001)
        XCTAssertEqual(VolumeMath.decibelsToLinear(-6.02), 0.5, accuracy: 0.05)
        XCTAssertEqual(VolumeMath.decibelsToLinear(-120), 0, accuracy: 0.001)
    }
}
