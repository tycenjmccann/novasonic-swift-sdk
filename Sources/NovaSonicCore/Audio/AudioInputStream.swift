#if IOS_AUDIO
// AudioInputStream.swift
import AVFAudio

public class AudioInputStream {
    private let engine: AVAudioEngine
    private let inputNode: AVAudioInputNode
    private let bufferSize: AVAudioFrameCount = 256
    private var isRecording = false

    private var cachedConverter: AVAudioConverter?
    private let desiredFormat: AVAudioFormat

    public init(targetSampleRate: Double = 16000) throws {
        self.engine = SharedAudioEngine.shared.engine
        self.inputNode = engine.inputNode

        guard let fmt = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                      sampleRate: targetSampleRate,
                                      channels: 1,
                                      interleaved: true) else {
            fatalError("Failed to build desiredFormat for sample rate: \(targetSampleRate)")
        }
        self.desiredFormat = fmt
        // Remove verbose config log - not needed
        // NovaSonicLogger.verbose("🎤 AudioInputStream configured for \(targetSampleRate) Hz")
    }

    /// Starts recording. Calls back onAudioChunk on a background queue.
    public func startRecording(onAudioChunk: @escaping (Data) -> Void) throws {
        NovaSonicLogger.standard("🎙️ Starting audio recording…")

        // 1) Ensure session + engine are configured & running
        try engine.inputNode.setVoiceProcessingEnabled(true)
        try SharedAudioEngine.shared.activateSession()
        try SharedAudioEngine.shared.startEngine()

        // 2) Prepare converter if needed
        let inputFormat = inputNode.outputFormat(forBus: 0)
        if cachedConverter == nil {
            guard let conv = AVAudioConverter(from: inputFormat, to: desiredFormat) else {
                throw NovaSonicError.converterCreationFailed
            }
            cachedConverter = conv
        }

        // 3) Install the tap
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0,
                             bufferSize: bufferSize,
                             format: inputFormat) { [weak self] buffer, _ in
            guard let self = self,
                  let srcChannels = buffer.floatChannelData else { return }

            // Quickly copy into a new buffer on RT thread
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

            // Dispatch heavy conversion & Data work off the real-time thread
            DispatchQueue.global(qos: .userInitiated).async {
                guard let converter = self.cachedConverter else { return }

                // Estimate output capacity
                let ratio = self.desiredFormat.sampleRate / inputFormat.sampleRate
                let expCap = AVAudioFrameCount(Double(frameLen) * ratio)
                guard let outBuf = AVAudioPCMBuffer(pcmFormat: self.desiredFormat,
                                                    frameCapacity: expCap) else {
                    NovaSonicLogger.error("❌ Failed to allocate outBuf")
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
        // Remove stopping log - not needed, developers can infer this
        inputNode.removeTap(onBus: 0)
        isRecording = false
    }
    
    // MARK: - Cleanup
    
    deinit {
        NovaSonicLogger.verbose("🧹 AudioInputStream: deinit - cleaning up resources")
        
        // Stop recording if still active
        if isRecording {
            inputNode.removeTap(onBus: 0)
            isRecording = false
        }
        
        NovaSonicLogger.verbose("🧹 AudioInputStream: deinit complete")
    }
}

#endif
