import XCTest
@testable import AudioMaster

@MainActor
final class NormalizationControllerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.normalization.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaults() {
        let controller = NormalizationController(defaults: defaults)
        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.strength, 0.75, accuracy: 0.0001)
    }

    func testEnabledPersistsAcrossInstances() {
        let controller = NormalizationController(defaults: defaults)
        controller.isEnabled = true

        let reloaded = NormalizationController(defaults: defaults)
        XCTAssertTrue(reloaded.isEnabled)
    }

    func testStrengthPersistsAcrossInstances() {
        let controller = NormalizationController(defaults: defaults)
        controller.strength = 0.4

        let reloaded = NormalizationController(defaults: defaults)
        XCTAssertEqual(reloaded.strength, 0.4, accuracy: 0.0001)
    }

    func testStrengthClampedToUnitRange() {
        let controller = NormalizationController(defaults: defaults)
        controller.strength = 1.5
        XCTAssertEqual(controller.strength, 1.0, accuracy: 0.0001)
        controller.strength = -0.5
        XCTAssertEqual(controller.strength, 0.0, accuracy: 0.0001)
    }

    func testSettingsReflectsState() {
        let controller = NormalizationController(defaults: defaults)
        controller.isEnabled = true
        controller.strength = 0.6

        XCTAssertEqual(controller.settings, NormalizationSettings(isEnabled: true, strength: 0.6))
    }
}
