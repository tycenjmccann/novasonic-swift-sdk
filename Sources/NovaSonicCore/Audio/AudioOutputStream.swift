#if IOS_AUDIO
//
//  AudioOutputStream.swift
//  NovaSonic Package
//
//  Audio output stream management for Nova Sonic
//
import AVFAudio

public class AudioOutputStream {

    private var isPlaying = false
    private var isSetup = false
    
    // Queue for scheduling audio playback
    private let playbackQueue = DispatchQueue(label: "com.audio.output.playback", qos: .userInteractive)
    
    // Buffer queue management
    private var bufferQueue: [AVAudioPCMBuffer] = []
    private let bufferQueueLock = NSLock()
    
    // Input format from Nova Sonic (configurable sample rate, mono, 16-bit PCM)
    private let inputFormat: AVAudioFormat
    
    // The format used for connecting to the mixer (determined at runtime)
    private var mixerFormat: AVAudioFormat!
    
    // Audio converter for format conversion
    private var converter: AVAudioConverter?
    
    // Track if we need to reinitialize
    private var needsReinit = false
    
    // Audio engine and player node
    private let engine: AVAudioEngine
    private var playerNode = AVAudioPlayerNode()

    public init(sourceSampleRate: Double = 24000) throws {
        // Create input format with configurable sample rate
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sourceSampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw NovaSonicError.invalidAudioFormat
        }
        
        self.inputFormat = format
        self.engine = SharedAudioEngine.shared.engine
        
        NovaSonicLogger.verbose("Initializing AudioOutputStream for \(sourceSampleRate) Hz...")
        
        // Ensure audio session is active before connecting nodes
        try SharedAudioEngine.shared.activateSession()
        
        // Setup player node
        engine.attach(playerNode)
        
        // Get the mixer node's preferred format instead of forcing our format
        // This is crucial to avoid the format mismatch crash
        mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        NovaSonicLogger.verbose("Mixer format: \(String(describing: mixerFormat))")
        
        // Connect using the mixer's native format
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        
        // Create converter for configured sample rate to mixer format conversion
        if let converter = AVAudioConverter(from: inputFormat, to: mixerFormat) {
            self.converter = converter
            NovaSonicLogger.verbose("Audio converter created successfully (\(sourceSampleRate)Hz → \(mixerFormat.sampleRate)Hz)")
        } else {
            NovaSonicLogger.minimal("Failed to create audio converter, will attempt on-demand conversion")
        }
        
        isSetup = true
        needsReinit = false
        NovaSonicLogger.verbose("AudioOutputStream initialized successfully for \(sourceSampleRate) Hz")
    }
    
    // Method to reinitialize the player node if needed
    func ensureValidState() throws {
        if needsReinit {
            NovaSonicLogger.verbose("Reinitializing audio output stream...")
            
            // Stop the player node if it's playing
            if playerNode.isPlaying {
                playerNode.stop()
            }
            
            // Clear any scheduled buffers
            bufferQueueLock.lock()
            bufferQueue.removeAll()
            bufferQueueLock.unlock()
            
            // Detach and reattach the player node
            engine.detach(playerNode)
            
            // Create a new player node
            let newPlayerNode = AVAudioPlayerNode()
            self.playerNode = newPlayerNode
            
            // Reattach and reconnect
            engine.attach(newPlayerNode)
            
            // Refresh the mixer format in case it changed
            mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
            NovaSonicLogger.verbose("Updated mixer format: \(String(describing: mixerFormat))")
            
            // Connect using the mixer's native format
            engine.connect(newPlayerNode, to: engine.mainMixerNode, format: nil)
            
            // Recreate the converter with the updated format
            converter = AVAudioConverter(from: inputFormat, to: mixerFormat)
            
            needsReinit = false
            NovaSonicLogger.verbose("Audio output stream reinitialized successfully")
        }
    }
    
    public func playAudio(_ audioData: Data) throws {
        // Skip if we're in the process of reinitializing
        if needsReinit {
            NovaSonicLogger.minimal("AudioOutputStream: Skipping audio playback - stream is being reinitialized")
            return
        }
        
        // Ensure the engine is running
        if !engine.isRunning {
            try SharedAudioEngine.shared.startEngine()
        }
        
        // Convert the raw audio data into a PCM buffer with Nova Sonic's format (24kHz)
        guard let sourceBuffer = audioData.toPCMBuffer(format: inputFormat) else {
            NovaSonicLogger.error("Audio Error: Conversion to source PCM buffer failed")
            throw NovaSonicError.conversionFailed
        }
        
        // Convert from 24kHz to the mixer's format
        let outputBuffer = try convertBufferToMixerFormat(sourceBuffer)
        
        // Verify format compatibility before scheduling
        guard outputBuffer.format.channelCount == mixerFormat.channelCount else {
            NovaSonicLogger.error("Channel count mismatch: buffer=\(outputBuffer.format.channelCount), mixer=\(mixerFormat.channelCount)")
            needsReinit = true
            throw NovaSonicError.invalidFormat
        }
        
        // Safely enqueue the converted buffer
        bufferQueueLock.lock()
        bufferQueue.append(outputBuffer)
        bufferQueueLock.unlock()
        
        playbackQueue.async { [weak self] in
            self?.scheduleNextBuffer()
        }
    }
    
    private func convertBufferToMixerFormat(_ sourceBuffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        // Calculate output buffer capacity based on sample rate ratio
        let sampleRateRatio = mixerFormat.sampleRate / inputFormat.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * sampleRateRatio)
        
        // Create output buffer with mixer format
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: mixerFormat, frameCapacity: frameCapacity) else {
            NovaSonicLogger.error("Failed to create output buffer")
            throw NovaSonicError.bufferCreationFailed
        }
        
        // Use the cached converter or create a new one
        let audioConverter = converter ?? AVAudioConverter(from: inputFormat, to: mixerFormat)
        
        guard let converter = audioConverter else {
            NovaSonicLogger.error("Failed to create audio converter")
            throw NovaSonicError.converterCreationFailed
        }
        
        // Perform the conversion
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }
        
        if status == .error {
            NovaSonicLogger.error("Conversion error: \(String(describing: error))")
            throw NovaSonicError.conversionFailed
        }
        
        return outputBuffer
    }
    
    private func scheduleNextBuffer() {
        bufferQueueLock.lock()
        defer { bufferQueueLock.unlock() }
        
        guard let nextBuffer = bufferQueue.first else { return }
        bufferQueue.removeFirst()
        
        // Safety check to prevent channel count mismatch crash
        do {
            // Verify format compatibility before scheduling
            if nextBuffer.format.channelCount != mixerFormat.channelCount {
                NovaSonicLogger.minimal("Format mismatch detected in scheduleNextBuffer. Marking for reinitialization.")
                needsReinit = true
                return
            }
            
            if !playerNode.isPlaying {
                playerNode.play()
                isPlaying = true
            }
            
            // Schedule the buffer with error handling
            playerNode.scheduleBuffer(nextBuffer) { [weak self] in
                self?.playbackQueue.async {
                    self?.scheduleNextBuffer()
                }
            }
        }
    }
    
    // Flushes audio stream to handle Barge-In scenarios
    public func flush() {
        NovaSonicLogger.standard("AudioOutputStream: flush() called - BARGE-IN DETECTED")
        
        // Stop immediately
        playerNode.stop()
        NovaSonicLogger.verbose("AudioOutputStream: Player node stopped")
        
        // Clear scheduled buffers
        bufferQueueLock.lock()
        let queuedBuffers = bufferQueue.count
        bufferQueue.removeAll()
        bufferQueueLock.unlock()
        NovaSonicLogger.verbose("AudioOutputStream: Cleared \(queuedBuffers) queued audio buffers")
        
        // Reset state
        isPlaying = false
        
        // For barge-in, we don't mark for reinitialization
        // as we want to continue using the same audio setup
        
        NovaSonicLogger.standard("AudioOutputStream: Audio flushed successfully - ready for new audio")
    }
    
    // Stops any scheduled or in-progress audio playback
    // This is called when completely stopping the stream
    public func stopPlaying() {
        NovaSonicLogger.verbose("AudioOutputStream: stopPlaying called")
        
        // Stop immediately
        playerNode.stop()
        
        // Clear scheduled buffers
        bufferQueueLock.lock()
        bufferQueue.removeAll()
        bufferQueueLock.unlock()
        
        // Reset state
        isPlaying = false
        
        // Mark for reinitialization on next use
        // This ensures we get a fresh setup when starting a new stream
        needsReinit = true
        
        NovaSonicLogger.verbose("AudioOutputStream: Playback stopped and marked for reinitialization.")
    }
    
    // MARK: - Cleanup
    
    deinit {
        NovaSonicLogger.verbose("🧹 AudioOutputStream: deinit - cleaning up resources")
        
        // Stop playback immediately
        if isPlaying {
            playerNode.stop()
        }
        
        // Clear all buffers
        bufferQueueLock.lock()
        bufferQueue.removeAll()
        bufferQueueLock.unlock()
        
        // Reset state
        isPlaying = false
        isSetup = false
        
        NovaSonicLogger.verbose("🧹 AudioOutputStream: deinit complete")
    }
}

#endif
