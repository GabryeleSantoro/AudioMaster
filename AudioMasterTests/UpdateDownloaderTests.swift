import XCTest
@testable import AudioMaster

final class UpdateDownloaderTests: XCTestCase {
    func testUniqueDestinationAvoidsOverwrite() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("am-dl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let name = "AudioMaster-1.0.0.dmg"
        let first = dir.appendingPathComponent(name)
        try Data([0x00]).write(to: first)

        let second = UpdateDownloader.uniqueDestinationURL(in: dir, preferredName: name)
        XCTAssertEqual(second.lastPathComponent, "AudioMaster-1.0.0-2.dmg")
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
    }
}
