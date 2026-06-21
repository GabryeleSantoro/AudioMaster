import XCTest
@testable import AudioMaster

final class VolumeMathTests: XCTestCase {
    func testLinearToDecibelsAtFullScale() {
        XCTAssertEqual(VolumeMath.linearToDecibels(1.0), 0, accuracy: 0.001)
    }

    func testLinearToDecibelsAtHalf() {
        XCTAssertEqual(VolumeMath.linearToDecibels(0.5), -6.02, accuracy: 0.1)
    }

    func testLinearToDecibelsAtZeroReturnsMinimum() {
        XCTAssertEqual(VolumeMath.linearToDecibels(0), VolumeMath.minDecibels)
    }

    func testLinearToDecibelsRejectsNegativeValues() {
        XCTAssertEqual(VolumeMath.linearToDecibels(-0.5), VolumeMath.minDecibels)
    }

    func testDecibelsToLinearAtZero() {
        XCTAssertEqual(VolumeMath.decibelsToLinear(0), 1.0, accuracy: 0.001)
    }

    func testDecibelsToLinearAtMinusSix() {
        XCTAssertEqual(VolumeMath.decibelsToLinear(-6.02), 0.5, accuracy: 0.05)
    }

    func testDecibelsToLinearAtMinimumReturnsZero() {
        XCTAssertEqual(VolumeMath.decibelsToLinear(-120), 0, accuracy: 0.001)
    }

    func testDecibelsToLinearBelowMinimumReturnsZero() {
        XCTAssertEqual(VolumeMath.decibelsToLinear(-200), 0, accuracy: 0.001)
    }

    func testSliderToGainRoundTrip() {
        for linear: Float in [0, 0.25, 0.5, 0.75, 1.0] {
            let gain = VolumeMath.sliderToGain(linear)
            let backToDB = VolumeMath.linearToDecibels(gain)
            let expectedDB = VolumeMath.linearToDecibels(linear)
            XCTAssertEqual(backToDB, expectedDB, accuracy: 0.01, "Round trip failed for \(linear)")
        }
    }

    func testSliderToGainAtZeroIsSilent() {
        XCTAssertEqual(VolumeMath.sliderToGain(0), 0, accuracy: 0.001)
    }

    func testSliderToGainAtFullScaleIsUnity() {
        XCTAssertEqual(VolumeMath.sliderToGain(1.0), 1.0, accuracy: 0.001)
    }

    func testClampSliderValue() {
        XCTAssertEqual(VolumeMath.clampSliderValue(2.5), VolumeMath.maxSliderValue)
        XCTAssertEqual(VolumeMath.clampSliderValue(-1), 0)
        XCTAssertEqual(VolumeMath.clampSliderValue(1.5), 1.5)
    }

    func testSliderFillRatio() {
        XCTAssertEqual(VolumeMath.sliderFillRatio(1.0), 0.5, accuracy: 0.001)
        XCTAssertEqual(VolumeMath.sliderFillRatio(2.0), 1.0, accuracy: 0.001)
    }
}
