import XCTest
@testable import AudioMaster

final class UpdateSchedulerTests: XCTestCase {
    func testEligibleWhenNeverCheckedAndEnabled() {
        XCTAssertTrue(
            UpdateScheduler.isEligibleForAutomaticCheck(
                enabled: true,
                lastCheck: nil,
                now: Date(timeIntervalSince1970: 1_000_000)
            )
        )
    }

    func testNotEligibleWhenDisabled() {
        XCTAssertFalse(
            UpdateScheduler.isEligibleForAutomaticCheck(
                enabled: false,
                lastCheck: nil,
                now: Date()
            )
        )
    }

    func testNotEligibleInsideTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let last = now.addingTimeInterval(-3600)
        XCTAssertFalse(
            UpdateScheduler.isEligibleForAutomaticCheck(
                enabled: true,
                lastCheck: last,
                now: now
            )
        )
    }

    func testEligibleAfterTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let last = now.addingTimeInterval(-24 * 60 * 60)
        XCTAssertTrue(
            UpdateScheduler.isEligibleForAutomaticCheck(
                enabled: true,
                lastCheck: last,
                now: now
            )
        )
    }

    func testOpenDMGImmediatelyOnlyForManualContext() {
        XCTAssertTrue(UpdateScheduler.shouldOpenDMGImmediately(context: .manual))
        XCTAssertFalse(UpdateScheduler.shouldOpenDMGImmediately(context: .silent))
    }
}
