import AudioToolbox
import CoreAudio
import Foundation
import MicrokitCore

/// Listens to everything the Mac is playing through a Core Audio process tap (macOS 14.2+),
/// and turns it into `AudioFeatures` about 40 times a second.
///
/// The tap is private and unmuted: nothing changes for what the user hears. macOS asks once
/// for "System Audio Recording Only" permission. Audio is analyzed in memory and dropped.
@available(macOS 14.2, *)
final class SystemAudioCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case coreAudio(step: String, status: OSStatus)

        var errorDescription: String? {
            switch self {
            case .coreAudio(let step, let status):
                "Could not \(step) (Core Audio error \(status))."
            }
        }
    }

    let features: AsyncStream<AudioFeatures>
    private let continuation: AsyncStream<AudioFeatures>.Continuation
    private let queue = DispatchQueue(label: "in.pooya.microkit.audio", qos: .userInteractive)

    // Set up and torn down on the main actor while the IO proc is stopped; read by the IO proc.
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var analyzer: SpectrumAnalyzer?
    private var isNonInterleaved = false
    private var channelCount = 2
    private var mono: [Float] = []
    private var lastPublish: TimeInterval = 0
    private var pendingBeat = false

    private static let publishInterval: TimeInterval = 1.0 / 40

    init() {
        (features, continuation) = AsyncStream.makeStream(of: AudioFeatures.self, bufferingPolicy: .bufferingNewest(1))
    }

    func start() throws {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "Microkit music mode"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        try check(AudioHardwareCreateProcessTap(description, &tapID), "start listening to system audio")

        let format = try tapFormat()
        isNonInterleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        channelCount = max(1, Int(format.mChannelsPerFrame))
        analyzer = SpectrumAnalyzer(sampleRate: format.mSampleRate > 0 ? format.mSampleRate : 48_000)

        let outputUID = try defaultOutputUID()
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Microkit Listener",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create the listening device")
        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { [weak self] _, input, _, _, _ in
            self?.process(input)
        }, "attach to the listening device")
        try check(AudioDeviceStart(aggregateID, procID), "start the listening device")
    }

    func stop() {
        if let procID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        continuation.yield(.silence)
    }

    deinit {
        stop()
        continuation.finish()
    }

    // MARK: IO proc (audio queue)

    private func process(_ input: UnsafePointer<AudioBufferList>) {
        guard let analyzer else { return }
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = buffers.first, let firstData = first.mData else { return }

        if isNonInterleaved {
            let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size
            if mono.count != frames { mono = [Float](repeating: 0, count: frames) }
            for i in 0..<frames { mono[i] = 0 }
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let samples = data.assumingMemoryBound(to: Float.self)
                for i in 0..<min(frames, Int(buffer.mDataByteSize) / MemoryLayout<Float>.size) { mono[i] += samples[i] }
            }
            let scale = 1 / Float(buffers.count)
            for i in 0..<frames { mono[i] *= scale }
        } else {
            let samples = firstData.assumingMemoryBound(to: Float.self)
            let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size / channelCount
            if mono.count != frames { mono = [Float](repeating: 0, count: frames) }
            for frame in 0..<frames {
                var sum: Float = 0
                for channel in 0..<channelCount { sum += samples[frame * channelCount + channel] }
                mono[frame] = sum / Float(channelCount)
            }
        }
        guard !mono.isEmpty else { return }
        analyzer.append(mono)

        let now = ProcessInfo.processInfo.systemUptime
        var features = analyzer.analyze(time: now)
        pendingBeat = pendingBeat || features.isBeat
        guard now - lastPublish >= Self.publishInterval else { return }
        features.isBeat = pendingBeat
        pendingBeat = false
        lastPublish = now
        continuation.yield(features)
    }

    // MARK: Core Audio helpers

    private func tapFormat() throws -> AudioStreamBasicDescription {
        var address = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try check(AudioObjectGetPropertyData(tapID, &address, 0, nil, &size, &format), "read the audio format")
        return format
    }

    private func defaultOutputUID() throws -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device), "find the sound output")

        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        try check(AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid), "identify the sound output")
        guard let uid else { throw CaptureError.coreAudio(step: "identify the sound output", status: -1) }
        return uid.takeRetainedValue() as String
    }

    private func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw CaptureError.coreAudio(step: step, status: status) }
    }
}
