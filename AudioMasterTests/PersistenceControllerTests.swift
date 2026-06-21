import XCTest
@testable import AudioMaster

final class PersistenceControllerTests: XCTestCase {
    private var persistence: PersistenceController!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        persistence = nil
        super.tearDown()
    }

    func testUpsertAndFetchRoundTrip() throws {
        let device = makeDevice(uid: "persist-001", name: "Desk Speaker")

        try persistence.upsertDevice(device)
        let fetched = try persistence.fetchDevices()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Desk Speaker")
        XCTAssertEqual(fetched.first?.type, .speaker)
        XCTAssertEqual(fetched.first?.deviceUID, "persist-001")
        XCTAssertEqual(fetched.first?.sampleRate, 48_000)
    }

    func testUpsertUpdatesExistingDeviceByUID() throws {
        let original = makeDevice(uid: "persist-002", name: "Old Name")
        let updated = makeDevice(uid: "persist-002", name: "New Name", type: .usb)

        try persistence.upsertDevice(original)
        try persistence.upsertDevice(updated)

        let fetched = try persistence.fetchDevices()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "New Name")
        XCTAssertEqual(fetched.first?.type, .usb)
    }

    func testMarkDeviceLastUsedUpdatesDefaultFlag() throws {
        let device = makeDevice(uid: "persist-003", name: "Mic", isInput: true, isOutput: false)
        try persistence.upsertDevice(device)

        try persistence.markDeviceLastUsed(device)

        let fetched = try persistence.fetchDevices().first
        XCTAssertEqual(fetched?.isSystemDefault, true)
        XCTAssertNotNil(fetched?.deviceUID)
    }

    func testFetchDevicesSortsByLastUsedDescending() throws {
        let older = makeDevice(uid: "persist-004", name: "Older")
        let newer = makeDevice(uid: "persist-005", name: "Newer")

        try persistence.upsertDevice(older)
        try persistence.upsertDevice(newer)
        try persistence.markDeviceLastUsed(newer)

        let fetched = try persistence.fetchDevices()
        XCTAssertEqual(fetched.map(\.name), ["Newer", "Older"])
    }

    private func makeDevice(
        uid: String,
        name: String,
        type: DeviceType = .speaker,
        isInput: Bool = false,
        isOutput: Bool = true
    ) -> AudioDevice {
        AudioDevice(
            id: AudioDevice.stableID(for: uid),
            coreAudioID: 99,
            name: name,
            type: type,
            isInput: isInput,
            isOutput: isOutput,
            channels: 2,
            sampleRate: 48_000,
            manufacturer: "Test",
            isSystemDefault: false,
            isConnected: true,
            deviceUID: uid
        )
    }
}
