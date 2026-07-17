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

    func testParsePmsetOutputIgnoresInternalBattery() {
        let output = """
        Now drawing from 'AC Power'
         -InternalBattery-0 (id=1)	80%; AC attached; not charging present: true
        """

        let entries = BluetoothBatteryReader.parsePmsetOutput(output)
        XCTAssertTrue(entries.isEmpty)
    }

    func testParsePmsetOutputSupportsModernFormatWithoutSuffixIndex() {
        let output = """
        Now drawing from 'Battery Power'
         -AirPods Pro di Gabriele (id=77796925)	96%; discharging present: true
        """

        let entries = BluetoothBatteryReader.parsePmsetOutput(output)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "AirPods Pro di Gabriele")
        XCTAssertEqual(entries[0].reading.primaryLevel, 96)
    }

    func testReadPmsetEntriesIncludesAccpsStyleAccessories() {
        let entries = BluetoothBatteryReader.readPmsetEntries()

        // On CI / machines without connected BT accessories this may be empty.
        if !entries.isEmpty {
            XCTAssertTrue(entries.allSatisfy { (0 ... 100).contains($0.reading.primaryLevel) })
        }
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
