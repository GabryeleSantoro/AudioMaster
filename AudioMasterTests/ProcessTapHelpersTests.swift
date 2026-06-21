import CoreAudio
import XCTest
@testable import AudioMaster

final class ProcessTapHelpersTests: XCTestCase {
    func testProcessTapCheckThrowsOnError() {
        XCTAssertThrowsError(try processTapCheck(-50, "unit test")) { error in
            guard let tapError = error as? ProcessTapError else {
                return XCTFail("Expected ProcessTapError")
            }
            XCTAssertEqual(tapError.status, -50)
            XCTAssertTrue(tapError.description.contains("unit test"))
        }
    }

    func testProcessTapCheckReturnsStatusOnSuccess() throws {
        let status = try processTapCheck(noErr, "unit test")
        XCTAssertEqual(status, noErr)
    }

    func testProcessTapGetArrayReturnsProcessList() throws {
        let ids = try processTapGetArray(
            AudioObjectID(kAudioObjectSystemObject),
            kAudioHardwarePropertyProcessObjectList
        )
        XCTAssertFalse(ids.isEmpty)
    }

    func testAudioProcessListReturnsProcesses() throws {
        let processes = try AudioProcessList.all()
        XCTAssertFalse(processes.isEmpty)
        XCTAssertTrue(processes.allSatisfy { $0.pid > 0 })
    }
}
