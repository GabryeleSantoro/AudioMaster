import XCTest
@testable import AudioMaster

final class UpdateVersionTests: XCTestCase {
    func testIsNewerDetectsPatchBump() {
        XCTAssertTrue(UpdateVersion.isNewer("1.0.1", than: "1.0.0"))
        XCTAssertTrue(UpdateVersion.isNewer("v1.0.1", than: "1.0.0"))
    }

    func testIsNewerFalseWhenEqual() {
        XCTAssertFalse(UpdateVersion.isNewer("1.2.3", than: "1.2.3"))
        XCTAssertFalse(UpdateVersion.isNewer("v1.2.3", than: "1.2.3"))
    }

    func testIsNewerFalseWhenOlder() {
        XCTAssertFalse(UpdateVersion.isNewer("1.0.0", than: "1.0.1"))
    }

    func testParseIgnoresPrereleaseSuffix() {
        XCTAssertEqual(UpdateVersion.parse("1.2.3-beta"), [1, 2, 3])
    }

    func testIsNewerPadsMissingComponentsAsZero() {
        XCTAssertTrue(UpdateVersion.isNewer("1.1", than: "1.0.9"))
        XCTAssertFalse(UpdateVersion.isNewer("1.0", than: "1.0.1"))
    }
}
