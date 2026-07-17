import XCTest
@testable import AudioMaster

final class EqualizerSettingsTests: XCTestCase {
    func testFlatSettingsAreFlat() {
        XCTAssertTrue(EQBandSettings.flat.isFlat)
    }

    func testClampGainWithinRange() {
        XCTAssertEqual(EQBandSettings.clampGain(-20), -12)
        XCTAssertEqual(EQBandSettings.clampGain(20), 12)
        XCTAssertEqual(EQBandSettings.clampGain(3), 3)
    }

    func testSetGainUpdatesBand() {
        var settings = EQBandSettings(bandCount: 15)
        settings.setGain(4, at: 0)
        XCTAssertEqual(settings.gain(at: 0), 4)
        XCTAssertFalse(settings.isFlat)
    }

    func testBandCountIsClampedToPreset() {
        let settings = EQBandSettings(bandCount: 99)
        XCTAssertEqual(settings.bandCount, EQBandCountPreset.professional.bandCount)

        let snapped = EQBandSettings(bandCount: 18)
        XCTAssertEqual(snapped.bandCount, EQBandCountPreset.extended.bandCount)
    }

    func testBandCountPresetsCoverRange() {
        XCTAssertEqual(EQBandCountPreset.allCases.first?.bandCount, 15)
        XCTAssertEqual(EQBandCountPreset.allCases.last?.bandCount, 31)
    }

    func testCenterFrequenciesSpanAudibleRange() {
        let frequencies = EQBandLayout.centerFrequencies(bandCount: 15)
        XCTAssertEqual(frequencies.count, 15)
        XCTAssertEqual(frequencies.first ?? 0, 20, accuracy: 0.1)
        XCTAssertEqual(frequencies.last ?? 0, 20_000, accuracy: 1)
    }

    func testResizedSettingsPreserveApproximateCurve() {
        var settings = EQBandSettings(bandCount: 15)
        settings.setGain(6, at: 0)
        settings.setGain(3, at: 1)

        let resized = settings.resized(to: 31)
        XCTAssertEqual(resized.bandCount, 31)
        XCTAssertGreaterThan(resized.gain(at: 0), 0)
    }

    func testPresetBassBoostHasPositiveBass() {
        let settings = EQPreset.bassBoost.settings(bandCount: 15)
        XCTAssertGreaterThan(settings.gain(at: 0), 0.5)
        XCTAssertLessThanOrEqual(settings.gain(at: 0), 2)
    }

    func testPresetAdaptsToBandCount() {
        let fifteen = EQPreset.electronic.settings(bandCount: 15)
        let thirtyOne = EQPreset.electronic.settings(bandCount: 31)
        XCTAssertEqual(fifteen.bandCount, 15)
        XCTAssertEqual(thirtyOne.bandCount, 31)
        XCTAssertGreaterThan(fifteen.gain(at: 0), 0)
        XCTAssertGreaterThan(thirtyOne.gain(at: 0), 0)
    }

    func testPodcastPresetBoostsMidrange() {
        let settings = EQPreset.podcast.settings(bandCount: 15)
        let frequencies = settings.centerFrequencies
        let midIndex = frequencies.enumerated().min(by: {
            abs($0.element - 2_000) < abs($1.element - 2_000)
        })?.offset ?? 0
        XCTAssertGreaterThan(settings.gain(at: midIndex), 0.5)
        XCTAssertLessThanOrEqual(settings.gain(at: midIndex), 2)
    }

    func testHipHopPresetBoostsSubBass() {
        let settings = EQPreset.hipHop.settings(bandCount: 15)
        XCTAssertGreaterThan(settings.gain(at: 0), 0.5)
        XCTAssertLessThanOrEqual(settings.gain(at: 0), 2)
    }

    func testPresetsStayWithinNaturalRange() {
        for preset in EQPreset.allCases where preset != .flat {
            let settings = preset.settings(bandCount: 31)
            for gain in settings.gains {
                XCTAssertGreaterThanOrEqual(gain, -2.5)
                XCTAssertLessThanOrEqual(gain, 2)
            }
        }
    }

    @MainActor
    func testPerAppOverridesGlobalWhenEnabled() {
        let controller = EqualizerController()
        controller.globalEnabled = true
        controller.globalBands = EQPreset.trebleBoost.settings(bandCount: controller.bandCount)
        controller.perAppFeatureEnabled = true
        controller.setPerAppEnabled(true, bundleID: "com.example.app")
        controller.setPerAppGain(6, at: 0, bundleID: "com.example.app")

        let effective = controller.effectiveSettings(for: "com.example.app")
        XCTAssertEqual(effective?.gain(at: 0), 6)
    }

    @MainActor
    func testGlobalUsedWhenPerAppDisabled() {
        let controller = EqualizerController()
        controller.globalEnabled = true
        let vocal = EQPreset.vocal.settings(bandCount: controller.bandCount)
        controller.globalBands = vocal
        controller.perAppFeatureEnabled = true
        controller.setPerAppEnabled(false, bundleID: "com.example.app")

        let effective = controller.effectiveSettings(for: "com.example.app")
        let midIndex = vocal.bandCount / 2
        XCTAssertEqual(effective?.gain(at: midIndex), vocal.gain(at: midIndex))
    }

    @MainActor
    func testChangingBandCountResizesGlobalBands() {
        let controller = EqualizerController()
        controller.bandCount = 20
        XCTAssertEqual(controller.globalBands.bandCount, 20)
        controller.bandCount = 31
        XCTAssertEqual(controller.globalBands.bandCount, 31)
    }

    @MainActor
    func testPerAppBandCountIsIndependentFromGlobal() {
        let controller = EqualizerController()
        controller.bandCount = 15
        controller.setPerAppBandCount(31, bundleID: "com.example.app")

        controller.bandCount = 20
        XCTAssertEqual(controller.globalBands.bandCount, 20)
        XCTAssertEqual(controller.perAppSettings(for: "com.example.app").bands.bandCount, 31)
    }

    @MainActor
    func testApplyPerAppPresetUsesPerAppBandCount() {
        let controller = EqualizerController()
        controller.setPerAppBandCount(25, bundleID: "com.example.app")
        controller.applyPerAppPreset(.bassBoost, bundleID: "com.example.app")

        let settings = controller.perAppSettings(for: "com.example.app").bands
        XCTAssertEqual(settings.bandCount, 25)
        XCTAssertGreaterThan(settings.gain(at: 0), 0.5)
    }

    @MainActor
    func testResetPerAppPreservesBandCount() {
        let controller = EqualizerController()
        controller.setPerAppBandCount(31, bundleID: "com.example.app")
        controller.applyPerAppPreset(.rock, bundleID: "com.example.app")
        controller.resetPerApp(bundleID: "com.example.app")

        let settings = controller.perAppSettings(for: "com.example.app").bands
        XCTAssertEqual(settings.bandCount, 31)
        XCTAssertTrue(settings.isFlat)
    }
}
