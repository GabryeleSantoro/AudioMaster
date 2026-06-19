import AudioToolbox
import CoreAudio
import Foundation
import os.lock

/// Per-process volume mixer using Core Audio Process Taps (macOS 14.2+).
@available(macOS 14.2, *)
final class AppVolumeMixer {
    private let targetPID: pid_t
    private let gainLock = OSAllocatedUnfairLock<Float>(initialState: 1.0)

    private var tapID: AudioObjectID = 0
    private var aggregateID: AudioObjectID = 0
    private var ioProcID: AudioDeviceIOProcID?
    private var started = false
    private var smoothedGain: Float = 1.0

    init(targetPID: pid_t, gain: Float) {
        self.targetPID = targetPID
        gainLock.withLock { $0 = gain }
        smoothedGain = gain
    }

    func setGain(_ gain: Float) {
        gainLock.withLock { $0 = max(0, gain) }
    }

    func start() throws {
        guard let processObject = try AudioProcessList.audioObjectID(forPID: targetPID) else {
            throw ProcessTapRuntimeError(description: "No audio process for pid \(targetPID)")
        }

        let description = CATapDescription(stereoMixdownOfProcesses: [processObject])
        description.uuid = UUID()
        description.name = "AudioMaster-tap-\(targetPID)"
        description.isPrivate = true
        description.muteBehavior = .muted

        var tap: AudioObjectID = kAudioObjectUnknown
        try processTapCheck(AudioHardwareCreateProcessTap(description, &tap), "AudioHardwareCreateProcessTap")
        tapID = tap

        let defaultOutput: AudioObjectID = try processTapGet(
            AudioObjectID(kAudioObjectSystemObject),
            kAudioHardwarePropertyDefaultOutputDevice
        )
        let outputUID = try processTapGetString(defaultOutput, kAudioDevicePropertyDeviceUID)
        let tapUID = try processTapGetString(tap, kAudioTapPropertyUID)

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "AudioMaster-\(targetPID)",
            kAudioAggregateDeviceUIDKey as String: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey as String: outputUID,
            kAudioAggregateDeviceIsPrivateKey as String: true,
            kAudioAggregateDeviceIsStackedKey as String: false,
            kAudioAggregateDeviceTapAutoStartKey as String: true,
            kAudioAggregateDeviceSubDeviceListKey as String: [
                [kAudioSubDeviceUIDKey as String: outputUID]
            ],
            kAudioAggregateDeviceTapListKey as String: [
                [
                    kAudioSubTapUIDKey as String: tapUID,
                    kAudioSubTapDriftCompensationKey as String: true
                ]
            ]
        ]

        var aggregate: AudioObjectID = kAudioObjectUnknown
        try processTapCheck(
            AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregate),
            "AudioHardwareCreateAggregateDevice"
        )
        aggregateID = aggregate

        let unownedSelf = Unmanaged.passUnretained(self)
        var procID: AudioDeviceIOProcID?
        try processTapCheck(
            AudioDeviceCreateIOProcIDWithBlock(
                &procID,
                aggregate,
                nil,
                { _, inputData, _, outputData, _ in
                    unownedSelf.takeUnretainedValue().render(input: inputData, output: outputData)
                }
            ),
            "AudioDeviceCreateIOProcIDWithBlock"
        )
        guard let procID else {
            throw ProcessTapRuntimeError(description: "AudioDeviceCreateIOProcIDWithBlock returned nil procID")
        }
        ioProcID = procID

        try processTapCheck(AudioDeviceStart(aggregate, procID), "AudioDeviceStart")
        started = true
    }

    private func render(
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>
    ) {
        let target = gainLock.withLock { $0 }
        let start = smoothedGain

        let inputList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outputList = UnsafeMutableAudioBufferListPointer(output)

        let pairs = min(inputList.count, outputList.count)
        for index in 0..<pairs {
            let inputBuffer = inputList[index]
            let outputBuffer = outputList[index]
            guard
                let inputPointer = inputBuffer.mData?.assumingMemoryBound(to: Float.self),
                let outputPointer = outputBuffer.mData?.assumingMemoryBound(to: Float.self)
            else {
                if let out = outputBuffer.mData {
                    memset(out, 0, Int(outputBuffer.mDataByteSize))
                }
                continue
            }

            let bytes = min(inputBuffer.mDataByteSize, outputBuffer.mDataByteSize)
            let samples = Int(bytes) / MemoryLayout<Float>.size
            if start == 1.0 && target == 1.0 {
                memcpy(outputPointer, inputPointer, Int(bytes))
            } else {
                let step = samples > 0 ? (target - start) / Float(samples) : 0
                var gain = start
                for sample in 0..<samples {
                    outputPointer[sample] = inputPointer[sample] * gain
                    gain += step
                }
            }

            if outputBuffer.mDataByteSize > bytes {
                let extra = Int(outputBuffer.mDataByteSize - bytes)
                memset(outputPointer.advanced(by: samples), 0, extra)
            }
        }

        for index in pairs..<outputList.count {
            if let pointer = outputList[index].mData {
                memset(pointer, 0, Int(outputList[index].mDataByteSize))
            }
        }

        smoothedGain = target
    }

    func stop() {
        if let procID = ioProcID, aggregateID != 0 {
            if started {
                AudioDeviceStop(aggregateID, procID)
            }
            AudioDeviceDestroyIOProcID(aggregateID, procID)
            ioProcID = nil
        }
        if aggregateID != 0 {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = 0
        }
        if tapID != 0 {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = 0
        }
        started = false
    }

    deinit {
        stop()
    }
}
