import XCTest
@testable import AudioMaster

final class RoutingPresetTests: XCTestCase {
    func testSnapshotDefaultsAreEmpty() {
        let snapshot = RoutingSnapshot()
        XCTAssertNil(snapshot.outputDeviceUID)
        XCTAssertNil(snapshot.outputDeviceName)
        XCTAssertNil(snapshot.masterVolume)
        XCTAssertNil(snapshot.equalizer)
        XCTAssertNil(snapshot.normalizationEnabled)
        XCTAssertTrue(snapshot.appVolumes.isEmpty)
    }

    func testPresetCodableRoundTrip() throws {
        let snapshot = RoutingSnapshot(
            outputDeviceUID: "AppleHDAEngineOutput:1",
            outputDeviceName: "MacBook Pro Speakers",
            masterVolume: 0.6,
            appVolumes: [
                "com.spotify.client": AppAudioState(gain: 0.3, muted: false),
                "com.apple.Safari": AppAudioState(gain: 1.0, muted: true),
            ],
            equalizer: EQSnapshot(enabled: true, bands: EQPreset.bassBoost.settings(bandCount: 15))
        )
        let preset = RoutingPreset(name: "Gaming", snapshot: snapshot)

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(RoutingPreset.self, from: data)

        XCTAssertEqual(decoded, preset)
    }

    func testPresetPreservesIdentityAcrossEncoding() throws {
        let preset = RoutingPreset(name: "Work", snapshot: RoutingSnapshot())
        let decoded = try JSONDecoder().decode(RoutingPreset.self, from: JSONEncoder().encode(preset))
        XCTAssertEqual(decoded.id, preset.id)
    }

    func testDecodingToleratesMissingOptionalFields() throws {
        // A snapshot persisted with only per-app volumes must still decode,
        // leaving device/master/EQ untouched (nil).
        let json = Data("""
        { "appVolumes": { "com.foo.bar": { "gain": 0.5, "muted": false } } }
        """.utf8)

        let snapshot = try JSONDecoder().decode(RoutingSnapshot.self, from: json)

        XCTAssertEqual(snapshot.appVolumes["com.foo.bar"], AppAudioState(gain: 0.5, muted: false))
        XCTAssertNil(snapshot.outputDeviceUID)
        XCTAssertNil(snapshot.masterVolume)
        XCTAssertNil(snapshot.equalizer)
        XCTAssertNil(snapshot.normalizationEnabled)
    }

    func testNormalizationEnabledCodableRoundTrip() throws {
        let snapshot = RoutingSnapshot(normalizationEnabled: true)
        let decoded = try JSONDecoder().decode(
            RoutingSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.normalizationEnabled, true)
    }
}
