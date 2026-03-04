#if IOS_AUDIO
// SharedAudioEngine.swift
import AVFAudio

// Singleton that manages a persistent AVAudioEngine
// and does all AVAudioSession configuration up front.
public final class SharedAudioEngine {

    public static let shared = SharedAudioEngine()
    private var _engine: AVAudioEngine?
    var engine: AVAudioEngine {
        if _engine == nil {
            _engine = AVAudioEngine()
        }
        return _engine!
    }

    private var isSessionActive = false
    
    // MARK: - Configuration
    
    private var inputSampleRate: Double = 16000
    private var outputSampleRate: Double = 24000
    
    /// Configure audio sample rates
    public func configure(inputSampleRate: Double, outputSampleRate: Double) {
        self.inputSampleRate = inputSampleRate
        self.outputSampleRate = outputSampleRate
        // Remove verbose config log - not needed for normal debugging
    }

    private init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }

        switch type {
        case .began:
            NovaSonicLogger.standard("🔊 Audio interruption began")
        case .ended:
            NovaSonicLogger.standard("🔊 Audio interruption ended")
            if let opts = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: opts).contains(.shouldResume) {
                try? activateSession()
            }
        @unknown default: break
        }
    }

    // Must be called before starting the engine.
    // Configures category, sample rate, and buffer duration.
    func activateSession() throws {
        if isSessionActive { return }
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(.playAndRecord,
                                mode: .videoChat,
                                options: [.defaultToSpeaker, .allowBluetooth])

        // Configure audio session with dynamic sample rate
        try session.setPreferredSampleRate(inputSampleRate)
        let preferredBufDur = Double(256) / inputSampleRate  // Buffer duration based on sample rate
        try session.setPreferredIOBufferDuration(preferredBufDur)

        try session.setActive(true, options: [])
        isSessionActive = true
    }

    // Starts (or no-ops if already running)
    func startEngine() throws {
        let eng = engine
        guard !eng.isRunning else { return }
        _ = eng.inputNode      // force node creation
        eng.prepare()
        try eng.start()
        NovaSonicLogger.standard("✅ Audio engine started")
    }

    func pauseAudio() {
        engine.inputNode.removeTap(onBus: 0)
    }

    func resetAudioState() throws {
        let eng = engine
        eng.inputNode.removeTap(onBus: 0)
        if eng.isRunning { eng.stop() }
        eng.reset()
        _engine = AVAudioEngine()
        try activateSession()
        // Remove verbose reset log - not needed
    }

    func stop() {
        let eng = engine
        eng.inputNode.removeTap(onBus: 0)
        if eng.isRunning { eng.stop() }
    }

    func handleBackgroundTransition() {
        let eng = engine
        eng.inputNode.removeTap(onBus: 0)
        if eng.isRunning { eng.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
        isSessionActive = false
    }

    func handleForegroundTransition() {
        try? activateSession()
    }
    
    // Additional methods for compatibility with existing code
    func checkForAudioConflicts() {
        let session = AVAudioSession.sharedInstance()
        // Remove verbose audio conflict checking - too detailed for normal use
    }
}

#endif
