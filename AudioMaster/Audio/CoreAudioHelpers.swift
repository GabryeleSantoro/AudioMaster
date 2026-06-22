import CoreAudio
import Foundation

enum CoreAudioError: Error, LocalizedError {
    case propertyError(OSStatus, String)
    case invalidDevice
    case noDevicesFound

    var errorDescription: String? {
        switch self {
        case .propertyError(let status, let context):
            return String(format: String(localized: "Core Audio error %lld in %@"), status, context)
        case .invalidDevice:
            return String(localized: "Invalid audio device")
        case .noDevicesFound:
            return String(localized: "No audio devices found")
        }
    }
}

enum AudioDeviceScope {
    case input
    case output

    var coreAudioScope: AudioObjectPropertyScope {
        switch self {
        case .input: return kAudioObjectPropertyScopeInput
        case .output: return kAudioObjectPropertyScopeOutput
        }
    }
}

enum CoreAudioHelpers {
    private static let systemObjectID = AudioObjectID(kAudioObjectSystemObject)

    // MARK: - Device Enumeration

    static func getAllDeviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(systemObjectID, &address, 0, nil, &dataSize)
        guard status == noErr else {
            throw CoreAudioError.propertyError(status, "getAllDeviceIDs size")
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &deviceIDs)
        guard status == noErr else {
            throw CoreAudioError.propertyError(status, "getAllDeviceIDs data")
        }
        return deviceIDs
    }

    static func getDeviceName(id: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &name)
        guard status == noErr else { return String(localized: "Unknown Device") }
        return name as String
    }

    static func getDeviceUID(id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &uid)
        guard status == noErr else { return nil }
        return uid as String
    }

    static func getTransportType(id: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &transportType)
        guard status == noErr else { return 0 }
        return transportType
    }

    static func getManufacturer(id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceManufacturerCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var manufacturer: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &manufacturer)
        guard status == noErr else { return nil }
        let value = manufacturer as String
        return value.isEmpty ? nil : value
    }

    static func hasStreams(id: AudioDeviceID, scope: AudioDeviceScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope.coreAudioScope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }

    static func getChannelCount(id: AudioDeviceID, scope: AudioDeviceScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope.coreAudioScope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return 0 }

        let rawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { rawPointer.deallocate() }

        status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, rawPointer)
        guard status == noErr else { return 0 }

        let bufferListPointer = rawPointer.assumingMemoryBound(to: AudioBufferList.self)
        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func getSampleRate(id: AudioDeviceID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRate: Float64 = 0
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &sampleRate)
        guard status == noErr else { return 44100 }
        return sampleRate
    }

    static func isAggregateDevice(id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyClass,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var classID: AudioClassID = 0
        var dataSize = UInt32(MemoryLayout<AudioClassID>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &classID)
        guard status == noErr else { return false }
        return classID == kAudioAggregateDeviceClassID
    }

    // MARK: - Default Device

    static func getDefaultDevice(scope: AudioDeviceScope) throws -> AudioDeviceID {
        let selector: AudioObjectPropertySelector
        switch scope {
        case .input:
            selector = kAudioHardwarePropertyDefaultInputDevice
        case .output:
            selector = kAudioHardwarePropertyDefaultOutputDevice
        }

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &deviceID)
        guard status == noErr, deviceID != 0 else {
            throw CoreAudioError.propertyError(status, "getDefaultDevice")
        }
        return deviceID
    }

    static func setDefaultDevice(id: AudioDeviceID, scope: AudioDeviceScope) throws {
        let selector: AudioObjectPropertySelector
        switch scope {
        case .input:
            selector = kAudioHardwarePropertyDefaultInputDevice
        case .output:
            selector = kAudioHardwarePropertyDefaultOutputDevice
        }

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutableID = id
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(systemObjectID, &address, 0, nil, dataSize, &mutableID)
        guard status == noErr else {
            throw CoreAudioError.propertyError(status, "setDefaultDevice")
        }
    }

    // MARK: - Device Type Inference

    static func inferDeviceType(
        name: String,
        transportType: UInt32,
        isAggregate: Bool
    ) -> DeviceType {
        if isAggregate { return .aggregate }

        let lowerName = name.lowercased()
        if lowerName.contains("airpods") { return .airpods }

        switch transportType {
        case kAudioDeviceTransportTypeUSB:
            return .usb
        case kAudioDeviceTransportTypeHDMI,
             kAudioDeviceTransportTypeDisplayPort,
             kAudioDeviceTransportTypeFireWire:
            return .hdmi
        case kAudioDeviceTransportTypeBluetooth,
             kAudioDeviceTransportTypeBluetoothLE:
            return lowerName.contains("airpods") ? .airpods : .bluetooth
        case kAudioDeviceTransportTypeBuiltIn:
            if lowerName.contains("headphone") || lowerName.contains("headset") {
                return .headphones
            }
            return .speaker
        case kAudioDeviceTransportTypeAggregate:
            return .aggregate
        default:
            if lowerName.contains("headphone") || lowerName.contains("headset") {
                return .headphones
            }
            if lowerName.contains("speaker") || lowerName.contains("macbook") {
                return .speaker
            }
            return .unknown
        }
    }

    // MARK: - System Volume

    static func getOutputVolume() throws -> Float {
        let deviceID = try getDefaultDevice(scope: .output)
        guard hasVolumeControl(deviceID: deviceID) else {
            throw CoreAudioError.propertyError(-1, "getOutputVolume - no volume control")
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume: Float32 = 0
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &volume)
        guard status == noErr else {
            throw CoreAudioError.propertyError(status, "getOutputVolume")
        }
        return volume
    }

    static func setOutputVolume(_ scalar: Float) throws {
        let deviceID = try getDefaultDevice(scope: .output)
        guard hasVolumeControl(deviceID: deviceID) else {
            throw CoreAudioError.propertyError(-1, "setOutputVolume - no volume control")
        }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume = max(0, min(1, scalar))
        let dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, dataSize, &volume)
        guard status == noErr else {
            throw CoreAudioError.propertyError(status, "setOutputVolume")
        }
    }

    private static func hasVolumeControl(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectHasProperty(deviceID, &address)
    }

    // MARK: - Build AudioDevice Model

    static func buildAudioDevice(
        id: AudioDeviceID,
        defaultInputID: AudioDeviceID?,
        defaultOutputID: AudioDeviceID?
    ) -> AudioDevice? {
        let isInput = hasStreams(id: id, scope: .input)
        let isOutput = hasStreams(id: id, scope: .output)
        guard isInput || isOutput else { return nil }

        let name = getDeviceName(id: id)
        let uid = getDeviceUID(id: id)
        let transportType = getTransportType(id: id)
        let isAggregate = isAggregateDevice(id: id)
        let deviceType = inferDeviceType(name: name, transportType: transportType, isAggregate: isAggregate)

        let inputChannels = isInput ? getChannelCount(id: id, scope: .input) : 0
        let outputChannels = isOutput ? getChannelCount(id: id, scope: .output) : 0
        let channels = max(inputChannels, outputChannels)

        let isDefaultInput = defaultInputID.map { $0 == id } ?? false
        let isDefaultOutput = defaultOutputID.map { $0 == id } ?? false

        return AudioDevice(
            id: AudioDevice.stableID(for: uid),
            coreAudioID: id,
            name: name,
            type: deviceType,
            isInput: isInput,
            isOutput: isOutput,
            channels: channels,
            sampleRate: getSampleRate(id: id),
            manufacturer: getManufacturer(id: id),
            isSystemDefault: isDefaultInput || isDefaultOutput,
            isConnected: true,
            deviceUID: uid
        )
    }

    // MARK: - Property Listeners

    typealias PropertyListenerCallback = () -> Void

    final class ListenerContext {
        let callback: PropertyListenerCallback
        init(callback: @escaping PropertyListenerCallback) {
            self.callback = callback
        }
    }

    static func addPropertyListener(
        selector: AudioObjectPropertySelector,
        callback: @escaping PropertyListenerCallback
    ) throws -> ListenerContext {
        let context = ListenerContext(callback: callback)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let contextPointer = Unmanaged.passRetained(context).toOpaque()
        let status = AudioObjectAddPropertyListener(
            systemObjectID,
            &address,
            propertyListenerProc,
            contextPointer
        )
        guard status == noErr else {
            Unmanaged<ListenerContext>.fromOpaque(contextPointer).release()
            throw CoreAudioError.propertyError(status, "addPropertyListener")
        }
        return context
    }

    static func removePropertyListener(
        selector: AudioObjectPropertySelector,
        context: ListenerContext
    ) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let contextPointer = Unmanaged.passUnretained(context).toOpaque()
        AudioObjectRemovePropertyListener(systemObjectID, &address, propertyListenerProc, contextPointer)
    }

    private static let propertyListenerProc: AudioObjectPropertyListenerProc = { _, _, _, clientData in
        guard let clientData else { return noErr }
        let context = Unmanaged<ListenerContext>.fromOpaque(clientData).takeUnretainedValue()
        context.callback()
        return noErr
    }
}
