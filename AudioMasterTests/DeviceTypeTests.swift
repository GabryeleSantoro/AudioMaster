import XCTest
@testable import AudioMaster

final class DeviceTypeTests: XCTestCase {
    func testAllCasesHaveDisplayNames() {
        for type in DeviceType.allCases {
            XCTAssertFalse(type.displayName.isEmpty)
        }
    }

    func testAllCasesHaveSFSymbols() {
        for type in DeviceType.allCases {
            XCTAssertFalse(type.sfSymbol.isEmpty)
        }
    }

    func testCodableRoundTrip() throws {
        for type in DeviceType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(DeviceType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    func testRawValuesAreStable() {
        XCTAssertEqual(DeviceType.speaker.rawValue, "speaker")
        XCTAssertEqual(DeviceType.airpods.rawValue, "airpods")
        XCTAssertEqual(DeviceType.aggregate.rawValue, "aggregate")
    }
}
