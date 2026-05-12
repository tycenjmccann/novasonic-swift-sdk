#if IOS_AUDIO
// AudioInputStream.swift
import AVFAudio

public class AudioInputStream {
    private let engine: AVAudioEngine
    private let inputNode: AVAudioInputNode
    private let bufferSize: AVAudioFrameCount = 256
    private var isRecording = false

    private let desiredFormat: AVAudioFormat

    public init(targetSampleRate: Double = 16000) throws {
        self.engine = SharedAudioEngine.shared.engine
        self.inputNode = engine.inputNode

        guard let fmt = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                      sampleRate: targetSampleRate,
                                      channels: 1,
                                      interleaved: true) else {
            throw NovaSonicError.invalidAudioFormat
        }
        self.desiredFormat = fmt
    }

    /// Starts recording. Calls back onAudioChunk on a background queue.
    public func startRecording(onAudioChunk: @escaping (Data) -> Void) throws {
        NovaSonicLogger.standard("🎙️ Starting audio recording…")

        try engine.inputNode.setVoiceProcessingEnabled(true)
        try SharedAudioEngine.shared.activateSession()
        try SharedAudioEngine.shared.startEngine()

        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Build and validate the converter before installing the tap so the
        // tap closure captures an immutable local — no shared-state data race.
        guard let converter = AVAudioConverter(from: inputFormat, to: desiredFormat) else {
            throw NovaSonicError.converterCreationFailed
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0,
                             bufferSize: bufferSize,
                             format: inputFormat) { [desiredFormat] buffer, _ in
            guard let srcChannels = buffer.floatChannelData else { return }

            // Copy on the real-time thread; convert on a worker thread.
            let frameLen = buffer.frameLength
            let fmt      = buffer.format
            guard let copyBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameLen) else { return }
            copyBuf.frameLength = frameLen

            let chCount = Int(fmt.channelCount)
            let bytesPerFrame = MemoryLayout<Float>.size
            for ch in 0..<chCount {
                memcpy(copyBuf.floatChannelData![ch],
                       srcChannels[ch],
                       Int(frameLen) * bytesPerFrame)
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let ratio = desiredFormat.sampleRate / inputFormat.sampleRate
                let expCap = AVAudioFrameCount(Double(frameLen) * ratio)
                guard let outBuf = AVAudioPCMBuffer(pcmFormat: desiredFormat,
                                                    frameCapacity: expCap) else {
                    NovaSonicLogger.error("❌ Failed to allocate output buffer")
                    return
                }

                var err: NSError?
                converter.convert(to: outBuf, error: &err) { _, outStatus in
                    outStatus.pointee = .haveData
                    return copyBuf
                }
                if let err = err {
                    NovaSonicLogger.error("❌ Conversion error: \(err)")
                    return
                }

                guard let data = Data(pcmBuffer: outBuf) else { return }
                onAudioChunk(data)
            }
        }

        isRecording = true
        NovaSonicLogger.standard("🎙️ Audio recording started")
    }

    public func stopRecording() {
        inputNode.removeTap(onBus: 0)
        isRecording = false
    }

    deinit {
        if isRecording {
            inputNode.removeTap(onBus: 0)
        }
    }
}

#endif
