#if IOS_AUDIO
import Foundation
import AVFoundation

/// Unified audio manager for Nova Sonic that coordinates all audio operations
@MainActor
public class NovaSonicAudioManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isAudioSessionActive: Bool = false
    @Published public var hasAudioPermission: Bool = false
    @Published public var isRecording: Bool = false
    @Published public var isPlaying: Bool = false
    
    // MARK: - Private Properties
    private let sharedEngine = SharedAudioEngine.shared
    private let streamHolder = AudioStreamHolder()
    private var configuration: NovaSonicConfiguration?
    
    // MARK: - Initialization
    
    public init() {
        checkAudioPermission()
    }
    
    // MARK: - Public API
    
    /// Configure the audio manager with Nova Sonic settings
    public func configure(with configuration: NovaSonicConfiguration) {
        self.configuration = configuration
    }
    
    /// Request microphone permission from the user
    public func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                self.hasAudioPermission = granted
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Start the audio session for Nova Sonic
    public func startAudioSession() throws {
        guard let config = configuration else {
            throw NovaSonicError.invalidConfiguration
        }
    }
    
    /// Stop the audio session
    public func stopAudioSession() {
        guard let config = configuration else { return }
        isRecording = false
        isPlaying = false
    }
    
    /// Set up audio streams for bidirectional communication
    public func setupAudioStreams() async throws -> (AudioInputStream, AudioOutputStream) {
        guard hasAudioPermission else {
            throw NovaSonicError.audioPermissionDenied
        }
        
        // Get sample rates from configuration
        let inputSampleRate = Double(configuration?.inputSampleRate.hertz ?? 16000)
        let outputSampleRate = Double(configuration?.outputSampleRate.hertz ?? 24000)
        
        // Configure the shared audio engine with the sample rates
        SharedAudioEngine.shared.configure(inputSampleRate: inputSampleRate, outputSampleRate: outputSampleRate)
        
        // CRITICAL: Activate audio session before creating streams
        try SharedAudioEngine.shared.activateSession()
        
        do {
            let inputStream = try AudioInputStream(targetSampleRate: inputSampleRate)
            let outputStream = try AudioOutputStream(sourceSampleRate: outputSampleRate)
            
            // Store streams in the holder for coordination
            await streamHolder.setStreams(input: inputStream, output: outputStream)
            
            return (inputStream, outputStream)
        } catch {
            throw NovaSonicError.from(audioError: error)
        }
    }
    
    /// Get the current audio streams
    public func getAudioStreams() async -> (AudioInputStream?, AudioOutputStream?) {
        let inputStream = await streamHolder.getInputStream()
        let outputStream = await streamHolder.getOutputStream()
        return (inputStream, outputStream)
    }
    
    /// Start audio recording with callback for audio chunks
    public func startRecording(onAudioChunk: @escaping (Data) -> Void) async throws {
        guard let inputStream = await streamHolder.getInputStream() else {
            throw NovaSonicError.audioSessionError("No input stream available")
        }
        
        do {
            try inputStream.startRecording(onAudioChunk: onAudioChunk)
            isRecording = true
        } catch {
            throw NovaSonicError.from(audioError: error)
        }
    }
    
    /// Stop audio recording
    public func stopRecording() async {
        guard let inputStream = await streamHolder.getInputStream() else { return }
        
        inputStream.stopRecording()
        isRecording = false
    }
    
    /// Play audio data
    public func playAudio(_ audioData: Data) async throws {
        guard let outputStream = await streamHolder.getOutputStream() else {
            throw NovaSonicError.audioSessionError("No output stream available")
        }
        
        do {
            try outputStream.playAudio(audioData)
            isPlaying = true
        } catch {
            throw NovaSonicError.from(audioError: error)
        }
    }
    
    /// Stop audio playback
    public func stopPlayback() async {
        guard let outputStream = await streamHolder.getOutputStream() else { return }
        
        outputStream.stopPlaying()
        isPlaying = false
    }
    
    /// Flush audio queue for barge-in scenarios
    /// This immediately stops playback and clears all queued audio
    public func flushAudio() async {
        guard let outputStream = await streamHolder.getOutputStream() else { 
            NovaSonicLogger.minimal("NovaSonicAudioManager: No output stream available for flush")
            return 
        }
        
        NovaSonicLogger.standard("NovaSonicAudioManager: BARGE-IN - Flushing audio queue")
        outputStream.flush()
        isPlaying = false
        NovaSonicLogger.verbose("NovaSonicAudioManager: Audio flush complete - ready for new audio")
    }
    
    /// Clean up all audio resources
    public func cleanup() async {
        await stopRecording()
        await stopPlayback()
        stopAudioSession()
        
        // CRITICAL: Reset the SharedAudioEngine to create fresh engine for next session
        do {
            try sharedEngine.resetAudioState()
            NovaSonicLogger.verbose("SharedAudioEngine reset successfully")
        } catch {
            NovaSonicLogger.error("Failed to reset SharedAudioEngine: \(error)")
        }
        
        await streamHolder.cleanup()
    }
    
    // MARK: - Private Methods
    
    private func checkAudioPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            hasAudioPermission = true
        case .denied, .undetermined:
            hasAudioPermission = false
        @unknown default:
            hasAudioPermission = false
        }
    }
}

// MARK: - Audio Configuration Extensions

public extension NovaSonicAudioManager {
    
    /// Get current audio session configuration
    var audioSessionInfo: AudioSessionInfo {
        let session = AVAudioSession.sharedInstance()
        return AudioSessionInfo(
            category: session.category,
            options: session.categoryOptions,
            sampleRate: session.sampleRate,
            inputGain: session.inputGain,
            outputVolume: session.outputVolume
        )
    }
    
    /// Check if audio session is properly configured for Nova Sonic
    var isProperlyConfigured: Bool {
        let session = AVAudioSession.sharedInstance()
        return session.category == .playAndRecord &&
               session.categoryOptions.contains(.defaultToSpeaker) &&
               hasAudioPermission &&
               isAudioSessionActive
    }
}

// MARK: - Supporting Types

public struct AudioSessionInfo {
    public let category: AVAudioSession.Category
    public let options: AVAudioSession.CategoryOptions
    public let sampleRate: Double
    public let inputGain: Float
    public let outputVolume: Float
}

// MARK: - Audio Stream Holder Extension

extension AudioStreamHolder {
    
    /// Clean up all streams
    func cleanup() async {
        if let inputStream = await getInputStream() {
            inputStream.stopRecording()
        }
        
        if let outputStream = await getOutputStream() {
            outputStream.stopPlaying()
        }
        
        await setStreams(input: nil, output: nil)
    }
}

#endif
