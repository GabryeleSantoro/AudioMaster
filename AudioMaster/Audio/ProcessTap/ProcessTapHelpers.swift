import CoreAudio
import Foundation

struct ProcessTapError: Error, CustomStringConvertible {
    let status: OSStatus
    let context: String

    var description: String {
        "\(context) failed: OSStatus \(status)"
    }
}

struct ProcessTapRuntimeError: Error, CustomStringConvertible {
    let description: String
}

@discardableResult
func processTapCheck(_ status: OSStatus, _ context: @autoclosure () -> String) throws -> OSStatus {
    if status != noErr {
        throw ProcessTapError(status: status, context: context())
    }
    return status
}

func processTapGet<T>(
    _ object: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
    element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain,
    as _: T.Type = T.self
) throws -> T {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    var size = UInt32(MemoryLayout<T>.size)
    let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    defer { pointer.deallocate() }
    try processTapCheck(
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer),
        "AudioObjectGetPropertyData selector=0x\(String(selector, radix: 16))"
    )
    return pointer.pointee
}

func processTapGetArray(
    _ object: AudioObjectID,
    _ selector: AudioObjectPropertySelector
) throws -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    try processTapCheck(
        AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size),
        "AudioObjectGetPropertyDataSize selector=0x\(String(selector, radix: 16))"
    )
    let count = Int(size) / MemoryLayout<AudioObjectID>.stride
    guard count > 0 else { return [] }
    var ids = [AudioObjectID](repeating: 0, count: count)
    try processTapCheck(
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, &ids),
        "AudioObjectGetPropertyData selector=0x\(String(selector, radix: 16))"
    )
    return ids
}

func processTapGetString(
    _ object: AudioObjectID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
) throws -> String {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    var size = UInt32(MemoryLayout<CFString?>.size)
    var value: Unmanaged<CFString>?
    try processTapCheck(
        AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value),
        "AudioObjectGetPropertyData(CFString) selector=0x\(String(selector, radix: 16))"
    )
    guard let cf = value?.takeRetainedValue() else {
        throw ProcessTapRuntimeError(description: "nil string for selector 0x\(String(selector, radix: 16))")
    }
    return cf as String
}
