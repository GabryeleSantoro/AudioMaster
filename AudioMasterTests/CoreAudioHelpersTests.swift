import CoreAudio
import XCTest
@testable import AudioMaster

final class CoreAudioHelpersTests: XCTestCase {
    // MARK: - Device Type Inference

    func testInferDeviceTypeAirPods() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "Gabriele's AirPods Pro",
            transportType: kAudioDeviceTransportTypeBluetooth,
            isAggregate: false
        )
        XCTAssertEqual(type, .airpods)
    }

    func testInferDeviceTypeUSB() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "Scarlett 2i2",
            transportType: kAudioDeviceTransportTypeUSB,
            isAggregate: false
        )
        XCTAssertEqual(type, .usb)
    }

    func testInferDeviceTypeHDMI() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "LG TV",
            transportType: kAudioDeviceTransportTypeHDMI,
            isAggregate: false
        )
        XCTAssertEqual(type, .hdmi)
    }

    func testInferDeviceTypeAggregate() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "Multi-Output",
            transportType: 0,
            isAggregate: true
        )
        XCTAssertEqual(type, .aggregate)
    }

    func testInferDeviceTypeBuiltInSpeaker() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "MacBook Pro Speakers",
            transportType: kAudioDeviceTransportTypeBuiltIn,
            isAggregate: false
        )
        XCTAssertEqual(type, .speaker)
    }

    func testInferDeviceTypeBuiltInHeadphones() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "MacBook Pro Headphones",
            transportType: kAudioDeviceTransportTypeBuiltIn,
            isAggregate: false
        )
        XCTAssertEqual(type, .headphones)
    }

    func testInferDeviceTypeBluetoothHeadset() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "Sony WH-1000XM5",
            transportType: kAudioDeviceTransportTypeBluetooth,
            isAggregate: false
        )
        XCTAssertEqual(type, .bluetooth)
    }

    func testInferDeviceTypeUnknownFallback() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "Mystery Interface",
            transportType: 0,
            isAggregate: false
        )
        XCTAssertEqual(type, .unknown)
    }

    func testInferDeviceTypeNameBasedHeadset() {
        let type = CoreAudioHelpers.inferDeviceType(
            name: "USB Headset",
            transportType: 0,
            isAggregate: false
        )
        XCTAssertEqual(type, .headphones)
    }

    // MARK: - Core Audio Integration

    func testGetAllDeviceIDsReturnsDevices() throws {
        let ids = try CoreAudioHelpers.getAllDeviceIDs()
        XCTAssertFalse(ids.isEmpty)
    }

    func testGetDefaultOutputDevice() throws {
        let deviceID = try CoreAudioHelpers.getDefaultDevice(scope: .output)
        XCTAssertGreaterThan(deviceID, 0)
    }

    func testGetDefaultInputDevice() throws {
        let deviceID = try CoreAudioHelpers.getDefaultDevice(scope: .input)
        XCTAssertGreaterThan(deviceID, 0)
    }

    func testBuildAudioDeviceForDefaultOutput() throws {
        let defaultOutputID = try CoreAudioHelpers.getDefaultDevice(scope: .output)
        let device = CoreAudioHelpers.buildAudioDevice(
            id: defaultOutputID,
            defaultInputID: try? CoreAudioHelpers.getDefaultDevice(scope: .input),
            defaultOutputID: defaultOutputID
        )

        XCTAssertNotNil(device)
        XCTAssertTrue(device?.isOutput ?? false)
        XCTAssertTrue(device?.isSystemDefault ?? false)
        XCTAssertFalse(device?.name.isEmpty ?? true)
    }

    // MARK: - Errors

    func testCoreAudioErrorDescriptions() {
        let propertyError = CoreAudioError.propertyError(-50, "testContext")
        XCTAssertTrue(propertyError.errorDescription?.contains("testContext") ?? false)

        XCTAssertEqual(CoreAudioError.invalidDevice.errorDescription, String(localized: "Invalid audio device"))
        XCTAssertEqual(CoreAudioError.noDevicesFound.errorDescription, String(localized: "No audio devices found"))
    }

    func testAudioDeviceScopeMapsToCoreAudioScopes() {
        XCTAssertEqual(AudioDeviceScope.input.coreAudioScope, kAudioObjectPropertyScopeInput)
        XCTAssertEqual(AudioDeviceScope.output.coreAudioScope, kAudioObjectPropertyScopeOutput)
    }
}
