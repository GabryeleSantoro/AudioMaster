import XCTest
@testable import AudioMaster

final class AudioDeviceTests: XCTestCase {
    func testStableIDIsDeterministic() {
        let uid = "CoreAudio-UID-ABC123"
        XCTAssertEqual(AudioDevice.stableID(for: uid), AudioDevice.stableID(for: uid))
    }

    func testStableIDDiffersForDifferentUIDs() {
        let first = AudioDevice.stableID(for: "device-a")
        let second = AudioDevice.stableID(for: "device-b")
        XCTAssertNotEqual(first, second)
    }

    func testStableIDGeneratesUUIDForMissingUID() {
        let id = AudioDevice.stableID(for: nil)
        XCTAssertNotNil(id.uuidString)
    }

    func testStableIDGeneratesUUIDForEmptyUID() {
        let id = AudioDevice.stableID(for: "")
        XCTAssertNotNil(id.uuidString)
    }

    func testEquatableDevicesMatch() {
        let id = UUID()
        let first = makeDevice(id: id, name: "Speaker")
        let second = makeDevice(id: id, name: "Speaker")
        XCTAssertEqual(first, second)
    }

    private func makeDevice(id: UUID, name: String) -> AudioDevice {
        AudioDevice(
            id: id,
            coreAudioID: 1,
            name: name,
            type: .speaker,
            isInput: false,
            isOutput: true,
            channels: 2,
            sampleRate: 48_000,
            manufacturer: "Apple Inc.",
            isSystemDefault: true,
            isConnected: true,
            deviceUID: "uid-\(name)"
        )
    }
}
