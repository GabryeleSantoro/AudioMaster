import XCTest
@testable import AudioMaster

final class BluetoothBatteryReaderTests: XCTestCase {
    func testParsePmsetOutputExtractsDeviceBatteryLevels() {
        let output = """
        Now drawing from 'AC Power'
         -Magic Keyboard-0 (id=123)	85%; AC attached; not charging present: true
         -Gabriele's AirPods Pro-0 (id=456)	72%; not attached; present: true
        """

        let entries = BluetoothBatteryReader.parsePmsetOutput(output)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].name, "Magic Keyboard")
        XCTAssertEqual(entries[0].reading.primaryLevel, 85)
        XCTAssertEqual(entries[1].name, "Gabriele's AirPods Pro")
        XCTAssertEqual(entries[1].reading.primaryLevel, 72)
    }

    func testParsePmsetOutputIgnoresNonAccessoryLines() {
        let output = """
        Now drawing from 'AC Power'
         -InternalBattery-0 (id=1)	80%; AC attached; not charging present: true
        """

        let entries = BluetoothBatteryReader.parsePmsetOutput(output)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "InternalBattery")
    }
}

final class BluetoothNameMatcherTests: XCTestCase {
    func testNamesMatchForAirPodsVariants() {
        XCTAssertTrue(
            BluetoothNameMatcher.namesMatch("Gabriele's AirPods Pro", "AirPods Pro")
        )
    }

    func testNormalizedAddressUsesUppercaseDashFormat() {
        XCTAssertEqual(
            BluetoothNameMatcher.normalizedAddress("50:57:8a:c9:63:4c"),
            "50-57-8A-C9-63-4C"
        )
    }
}
