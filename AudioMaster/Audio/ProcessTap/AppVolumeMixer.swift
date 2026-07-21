import AudioToolbox
import CoreAudio
import Foundation
import os.lock

/// Abstraction over a per-process volume mixer so the controller can be tested
/// without touching Core Audio. The protocol is intentionally ungated; only the
/// concrete `AppVolumeMixer` requires macOS 14.2.
protocol AppVolumeMixing: AnyObject {
    func setGain(_ gain: Float)
    func updateEqualizer(_ settings: EQBandSettings?)
    func updateNormalization(_ settings: NormalizationSettings)
    func start() throws
    /// Re-point the mixer at the current default output device WITHOUT recreating
    /// the process tap. Recreating the tap re-triggers the audio-capture consent
    /// prompt; the tap captures the target process and is independent of the
    /// output device, so only the wrapping aggregate device needs rebuilding.
    func rebindOutput() throws
    func stop()
}

/// Per-process volume mixer using Core Audio Process Taps (macOS 14.2+).
@available(macOS 14.2, *)
final class AppVolumeMixer: AppVolumeMixing {
    private let targetPID: pid_t
    private let gainLock = OSAllocatedUnfairLock<Float>(initialState: 1.0)
    private let equalizer = EqualizerProcessor()

    private var tapID: AudioObjectID = 0
    private var aggregateID: AudioObjectID = 0
    private var ioProcID: AudioDeviceIOProcID?
    private var started = false
    private var smoothedGain: Float = 1.0
    private var appliesEqualizer = false
    private var appliesNormalization = false

    init(
        targetPID: pid_t,
        gain: Float,
        eqSettings: EQBandSettings? = nil,
        normalizationSettings: NormalizationSettings? = nil
    ) {
        self.targetPID = targetPID
        gainLock.withLock { $0 = gain }
        smoothedGain = gain
        updateEqualizer(eqSettings)
        if let normalizationSettings {
            updateNormalization(normalizationSettings)
        }
    }

    func setGain(_ gain: Float) {
        gainLock.withLock { $0 = max(0, gain) }
    }

    func updateEqualizer(_ settings: EQBandSettings?) {
        if let settings, !settings.isFlat {
            equalizer.update(settings: settings)
            appliesEqualizer = true
        } else {
            appliesEqualizer = false
        }
    }

    func updateNormalization(_ settings: NormalizationSettings) {
        equalizer.updateNormalization(settings: settings)
        appliesNormalization = settings.isEnabled
    }

    func start() throws {
        guard let processObject = try AudioProcessList.audioObjectID(forPID: targetPID) else {
            throw ProcessTapRuntimeError(description: "No audio process for pid \(targetPID)")
        }

        let description = CATapDescription(stereoMixdownOfProcesses: [processObject])
        description.uuid = UUID()
        description.name = "\(AudioMasterDeviceNaming.tapPrefix)\(targetPID)"
        description.isPrivate = true
        description.muteBehavior = .muted

        var tap: AudioObjectID = kAudioObjectUnknown
        try processTapCheck(AudioHardwareCreateProcessTap(description, &tap), "AudioHardwareCreateProcessTap")
        tapID = tap

        try buildAggregateAndStart()
    }

    /// Rebuild the aggregate device + IO proc around the current default output
    /// while keeping the existing process tap alive, so no audio-capture consent
    /// prompt is triggered on an output-device change.
    func rebindOutput() throws {
        guard tapID != 0 else {
            // No tap has been created yet: nothing to preserve, do a full start
            // (this DOES prompt, but only the very first time).
            try start()
            return
        }
        teardownAggregate()
        try buildAggregateAndStart()
    }

    /// Tear down the IO proc + aggregate device but leave `tapID` intact.
    private func teardownAggregate() {
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
        started = false
    }

    /// Build the aggregate device wrapping the current default output + the
    /// existing tap, wire the IO proc, and start rendering. Requires `tapID != 0`.
    private func buildAggregateAndStart() throws {
        let defaultOutput: AudioObjectID = try processTapGet(
            AudioObjectID(kAudioObjectSystemObject),
            kAudioHardwarePropertyDefaultOutputDevice
        )
        let outputUID = try processTapGetString(defaultOutput, kAudioDevicePropertyDeviceUID)
        let tapUID = try processTapGetString(tapID, kAudioTapPropertyUID)

        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "\(AudioMasterDeviceNaming.aggregatePrefix)\(targetPID)",
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
            let appliesProcessing = appliesEqualizer || appliesNormalization
            let passthrough = start == 1.0 && target == 1.0 && !appliesProcessing
            if passthrough {
                memcpy(outputPointer, inputPointer, Int(bytes))
            } else {
                let step = samples > 0 ? (target - start) / Float(samples) : 0
                var gain = start
                for sample in 0..<samples {
                    var value = inputPointer[sample] * gain
                    if appliesProcessing {
                        value = equalizer.process(sample: value)
                    }
                    outputPointer[sample] = value
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
