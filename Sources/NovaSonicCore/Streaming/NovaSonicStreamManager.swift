//
//  NovaSonicStreamManager.swift
//  NovaSonic Package
//
//  Main stream manager for Nova Sonic bidirectional audio streaming
//
import SwiftUI
import AWSBedrockRuntime
import ClientRuntime
#if IOS_AUDIO
import AVFoundation
#endif
import AWSSDKIdentity
import SmithyIdentity
import AwsCommonRuntimeKit

@MainActor
public class NovaSonicStreamManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isStreaming = false
    @Published public var connectionStatus: ConnectionStatus = .disconnected
    @Published public var messages: [ChatMessage] = []
    @Published public var selectedVoice: NovaSonicVoice = .tiffany
    @Published public var lastError: NovaSonicError?

    /// Latency/turn metrics for the current (or most recent) session. Reset on each session start.
    @Published public private(set) var sessionMetrics: NovaSonicSessionMetrics?
    
    // MARK: - Private Helpers

    private func updateIsStreaming(_ value: Bool) { isStreaming = value }
    private func updateConnectionStatus(_ status: ConnectionStatus) { connectionStatus = status }
    private func addMessage(_ message: ChatMessage) { messages.append(message) }
    private func updateError(_ error: NovaSonicError?) { lastError = error }
    
    // MARK: - Configuration
    private var configuration: NovaSonicConfiguration?
    
    /// Check if the stream manager has been configured
    public var isConfigured: Bool {
        return configuration != nil
    }

    /// The model the manager is currently configured for, if any
    public var configuredModel: NovaSonicModel? {
        return configuration?.model
    }
    
    // MARK: - Delegate
    public weak var delegate: NovaSonicStreamDelegate?
    
    // MARK: - Private Properties
    private var isSpeculativeText = true
    
    // Current streaming message
    private var currentStreamingMessage: ChatMessage?
    
    // Dictionary to track messages by content ID
    private var messagesByContentId: [String: String] = [:]
    
    // Array to track speculative messages in order
    private var speculativeMessageIds: [String] = []
    private var finalMessageCount = 0
    
    // Current content ID being processed
    private var currentContentId: String?
    
    // Target messages binding for resumed conversations
    private var targetMessagesBinding: Binding<[ChatMessage]>?
    
    // Current conversation ID for resumed conversations
    private var currentConversationId: String?
    
    // History management (optional, pluggable like tools)
    private var historyManager: NovaSonicHistoryManager?
    
    // Streaming infrastructure
    private var bedrockClient: BedrockRuntimeClient?
    private var stream: InvokeModelWithBidirectionalStreamOutput?
    private var eventStreamContinuation: AsyncThrowingStream<BedrockRuntimeClientTypes.InvokeModelWithBidirectionalStreamInput, Error>.Continuation?
    
    // Audio management
    #if IOS_AUDIO
    private let audioManager = NovaSonicAudioManager()
    #endif
    
    // Session management
    private var promptName = UUID().uuidString
    private var contentName = UUID().uuidString
    private var audioContentName = UUID().uuidString
    
    // Conversation mode tracking
    private var calledMode: ConversationMode = .newConversation
    
    // Speak first configuration
    private var shouldSpeakFirst = false
    
    // Logging counters
    private var chunkCounter = 0
    private var didReceiveTextOutput = false

    // MARK: - Metrics
    /// Monotonic reference captured at session start; all metric timestamps are relative to it.
    private var metricsEpoch: DispatchTime?

    /// Seconds elapsed since the session's monotonic epoch (0 if metrics not started).
    private func elapsed() -> TimeInterval {
        guard let epoch = metricsEpoch else { return 0 }
        return Double(DispatchTime.now().uptimeNanoseconds - epoch.uptimeNanoseconds) / 1_000_000_000
    }

    /// Mutate the in-progress turn, creating one if none exists yet.
    private func withCurrentTurn(_ body: (inout TurnMetric) -> Void) {
        guard sessionMetrics != nil else { return }
        if sessionMetrics!.turns.isEmpty {
            sessionMetrics!.turns.append(TurnMetric(turnIndex: 0))
        }
        body(&sessionMetrics!.turns[sessionMetrics!.turns.count - 1])
    }

    /// Start a new turn when a user utterance arrives.
    ///
    /// A turn is anchored to a user utterance. We only reuse the last turn if it is
    /// *completely* empty — no user transcript AND no assistant activity yet. That way a
    /// `speakFirst`/`initialTextPrompt` preamble (assistant audio before any user speech)
    /// stays in its own turn 0 instead of being back-filled with a later `userTranscriptAt`,
    /// which would make `timeToFirstAudioSeconds` negative.
    private func beginTurnIfNeeded() {
        guard sessionMetrics != nil else { return }
        if let last = sessionMetrics!.turns.last,
           last.userTranscriptAt == nil,
           last.firstAudioChunkAt == nil,
           last.firstSpeculativeTextAt == nil {
            return // reuse the truly-empty pre-seeded turn
        }
        sessionMetrics!.turns.append(TurnMetric(turnIndex: sessionMetrics!.turns.count))
    }

    /// Stamp the send-time on the most recent pending tool call matching this id.
    private func recordToolResultSent(toolUseId: String) {
        guard sessionMetrics != nil else { return }
        let now = elapsed()
        for t in sessionMetrics!.turns.indices {
            if let c = sessionMetrics!.turns[t].toolCalls.lastIndex(where: { $0.toolUseId == toolUseId && $0.resultSentAt == nil }) {
                sessionMetrics!.turns[t].toolCalls[c].resultSentAt = now
                return
            }
        }
    }
    
    // MARK: - Session Export

    /// A single session's transcript + metrics, written to disk for offline model comparison.
    public struct SessionExport: Codable {
        public let modelId: String
        public let startedAt: Date
        public let messages: [ChatMessage]
        public let metrics: NovaSonicSessionMetrics?
    }

    /// Serialize the current session (transcript + latency metrics) to a JSON file in the
    /// app's Documents directory. Returns the file URL. Used to capture beta-test runs for
    /// diffing across Nova Sonic model versions.
    @discardableResult
    public func exportSession() throws -> URL {
        let export = SessionExport(
            modelId: sessionMetrics?.modelId ?? configuration?.model.id ?? NovaSonicModel.novaSonic2.id,
            startedAt: sessionMetrics?.startedAt ?? Date(),
            messages: messages,
            metrics: sessionMetrics
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stamp = ISO8601DateFormatter().string(from: export.startedAt).replacingOccurrences(of: ":", with: "-")
        let safeModel = export.modelId.replacingOccurrences(of: ":", with: "_").replacingOccurrences(of: "/", with: "_")
        let url = dir.appendingPathComponent("novasonic-session-\(safeModel)-\(stamp).json")
        try data.write(to: url, options: .atomic)
        NovaSonicLogger.standard("📤 Session exported to \(url.lastPathComponent)")
        return url
    }

    // MARK: - Initialization
    public init() {}
    
    // MARK: - Configuration
    public func configure(with config: NovaSonicConfiguration, bedrockClient: BedrockRuntimeClient? = nil) {
        do {
            try config.validate()
        } catch {
            lastError = NovaSonicError.invalidConfiguration
            NovaSonicLogger.error("❌ Invalid configuration: \(error.localizedDescription)")
            return
        }
        let previousRegion = self.configuration?.region
        self.configuration = config
        self.selectedVoice = config.voice

        // Initialize logging with configuration level
        NovaSonicLogger.initialize(level: config.logLevel)

        // Use provided client or create default
        if let providedClient = bedrockClient {
            self.bedrockClient = providedClient
            NovaSonicLogger.standard("🔧 Using provided Bedrock client for authentication")
        } else {
            // A cached default client is pinned to its region's endpoint. If the region
            // changed (e.g. switching models across regions for the beta comparison),
            // drop it so configureClient() rebuilds against the new endpoint — otherwise
            // the new model ID would be sent to the old region and fail at stream open.
            if let previousRegion, previousRegion != config.region {
                self.bedrockClient = nil
                NovaSonicLogger.standard("🔧 Region changed \(previousRegion) → \(config.region); rebuilding Bedrock client")
            } else {
                NovaSonicLogger.standard("🔧 Using default Bedrock client creation")
            }
        }
        
        // Set up history manager - either custom or built-in DynamoDB
        Task {
            do {
                let manager = try await createHistoryManager(from: config)
                await MainActor.run {
                    self.historyManager = manager
                    if manager != nil {
                        NovaSonicLogger.standard("✅ History manager configured successfully")
                    } else {
                        NovaSonicLogger.standard("💡 No history manager configured - conversations won't be saved")
                    }
                }
            } catch {
                await MainActor.run {
                    NovaSonicLogger.error("❌ Failed to configure history manager: \(error)")
                    NovaSonicLogger.standard("💡 Continuing without history - conversations won't be saved")
                    self.historyManager = nil
                }
            }
        }
        
        configureClient()
    }
    
    /// Create the appropriate history manager based on configuration
    /// Uses the same credentials as the Bedrock client for DynamoDB access
    private func createHistoryManager(from config: NovaSonicConfiguration) async throws -> NovaSonicHistoryManager? {
        // If custom history manager is provided, use it
        if let customHistoryManager = config.historyManager {
            return customHistoryManager
        }
        
        // If DynamoDB history is enabled, create built-in manager
        if config.enableDynamoDBHistory {
            let userId = config.dynamoDBUserId ?? "default-user"
            NovaSonicLogger.verbose("🔧 Creating DynamoDB history manager with userId: \(userId)")
            
            // Use credentials from configuration
            let credentialsProvider = config.awsCredentialIdentityResolver
            if credentialsProvider != nil {
                NovaSonicLogger.verbose("🔐 Using provided credentials for DynamoDB")
            } else {
                NovaSonicLogger.verbose("🔐 Using default credentials for DynamoDB")
            }
            
            return try await DynamoDBHistoryManager(
                region: config.dynamoDBRegion,
                tableName: config.dynamoDBTableName,
                userId: userId,
                credentialsProvider: credentialsProvider
            )
        }
        
        // No history manager
        return nil
    }
    
    /// Configure whether Nova Sonic should speak first by sending an initial audio prompt
    /// - Parameter speakFirst: If true, sends a minimal audio prompt to trigger Nova Sonic to respond immediately
    public func setSpeakFirst(_ speakFirst: Bool) {
        self.shouldSpeakFirst = speakFirst
        NovaSonicLogger.standard("🎙️ Speak first configured: \(speakFirst)")
    }
    
    // MARK: - Public Interface
    
    /// Start a new streaming session using registered tools
    public func startSession() async throws {
        NovaSonicLogger.standard("🔵 Starting Nova Sonic session")
        guard configuration != nil else {
            NovaSonicLogger.error("❌ Configuration is nil!")
            throw NovaSonicError.invalidConfiguration
        }
        
        // Get tool specs from registry for session start
        let tools = NovaSonicToolRegistry.shared.getToolSpecs()
        NovaSonicLogger.standard("🔧 Starting session with \(tools.count) registered tools")
        
        updateConnectionStatus(.connecting)  // Thread-safe update
        delegate?.didStartStreaming()
        
        await startStreaming(mode: .newConversation)
    }
    
    /// End the current streaming session
    public func endSession() async {
        await stopStreaming()
        updateConnectionStatus(.disconnected)  // Thread-safe update
        delegate?.didStopStreaming()
    }
    
    /// Send text message during active session (Nova 2.0)
    /// - Parameter text: The text message to send
    public func sendTextMessage(_ text: String) async throws {
        guard isStreaming else {
            throw NovaSonicError.streamingError("Cannot send text - session not active")
        }
        
        guard let continuation = eventStreamContinuation else {
            throw NovaSonicError.streamingError("Event stream not available")
        }
        
        let contentName = UUID().uuidString
        
        // Send text input sequence
        let textEvents: [(String, String)] = [
            (BedrockEvents.textContentStartEvent(promptName: promptName, contentName: contentName), "textContentStart"),
            (BedrockEvents.historyTextInputEvent(promptName: promptName, contentName: contentName, content: text, role: "USER"), "textInput"),
            (BedrockEvents.contentEndEvent(promptName: promptName, contentName: contentName), "contentEnd")
        ]
        
        for (eventJson, eventType) in textEvents {
            NovaSonicLogger.verbose("Sending \(eventType) event")
            continuation.yield(
                .chunk(
                    .init(bytes: Data(eventJson.utf8))
                )
            )
        }
        
        NovaSonicLogger.standard("Sent text message: \(text)")
    }

    /// Send a session update event mid-session to change pronunciation replacements, language hint, or keyterms.
    public func sendSessionUpdate(
        pronunciationReplacements: [String: String]? = nil,
        languageHint: String? = nil,
        keyterms: [String]? = nil
    ) async throws {
        guard isStreaming else {
            throw NovaSonicError.streamingError("Cannot send session update - session not active")
        }

        // Validate languageHint
        if let hint = languageHint {
            guard !hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw NovaSonicError.invalidConfiguration
            }
            let bareCodesRequiringRegion = ["es", "pt"]
            if bareCodesRequiringRegion.contains(hint.lowercased()) {
                throw NovaSonicError.invalidConfiguration
            }
        }

        // Validate keyterms
        if let terms = keyterms {
            guard terms.count <= 100 else {
                throw NovaSonicError.invalidConfiguration
            }
            for term in terms {
                guard term.count <= 50 else {
                    throw NovaSonicError.invalidConfiguration
                }
            }
        }

        guard let eventJson = BedrockEvents.sessionUpdateEvent(
            pronunciationReplacements: pronunciationReplacements,
            languageHint: languageHint,
            keyterms: keyterms
        ) else {
            return
        }

        try await sendEvent(eventJson, label: "sessionUpdate")
        NovaSonicLogger.standard("📝 Sent session update event")
    }

    // MARK: - History Management
    
    /// Set the history manager for conversation persistence
    /// - Parameter manager: The history manager to use, or nil to disable history
    public func setHistoryManager(_ manager: NovaSonicHistoryManager?) {
        self.historyManager = manager
    }
    
    /// Load conversation history and resume the conversation
    /// - Parameter conversationId: The ID of the conversation to load
    public func loadConversationHistory(_ conversationId: String) async throws {
        guard let historyManager = historyManager else {
            NovaSonicLogger.verbose("⚠️ No history manager configured")
            return
        }
        
        NovaSonicLogger.verbose("📚 Loading conversation history for ID: \(conversationId)")
        
        do {
            let historicalMessages = try await historyManager.loadConversation(conversationId: conversationId)
            
            // Debug logging removed - was too verbose
            
            // Update messages on main thread
            await MainActor.run {
                self.messages = historicalMessages
                self.currentConversationId = conversationId
            }
            
        } catch {
            NovaSonicLogger.error("❌ Failed to load conversation history: \(error)")
            throw error
        }
    }
    
    /// Get the current conversation ID
    public func getCurrentConversationId() -> String? {
        return currentConversationId
    }
    
    /// Set the current conversation ID (useful for new conversations)
    public func setCurrentConversationId(_ conversationId: String) {
        self.currentConversationId = conversationId
    }
    
    /// Get the current history manager (for UI components)
    public func getCurrentHistoryManager() -> NovaSonicHistoryManager? {
        return historyManager
    }
    
    // MARK: - Streaming Control
    public func startStreaming(mode: ConversationMode) async {
        self.calledMode = mode
        guard let client = bedrockClient else {
        NovaSonicLogger.error("❌ Bedrock client is not initialized.")
            return
        }
        NovaSonicLogger.standard("🔵 Bedrock client is available, setting up streaming session...")
        do {
            try await setupStreamingSession(client: client)
            NovaSonicLogger.standard("🔵 Streaming session setup completed successfully!")
        } catch {
            let novaSonicError = NovaSonicError.from(awsError: error)
            NovaSonicLogger.error("❌ Stream failed to open: \(novaSonicError.localizedDescription)")
            lastError = novaSonicError
            connectionStatus = .error(novaSonicError)
            delegate?.didEncounterError(novaSonicError)
            await stopStreaming()
        }
    }
    
    private func setupStreamingSession(client: BedrockRuntimeClient) async throws {
        updateIsStreaming(true)  // Thread-safe update
        didReceiveTextOutput = false
        updateConnectionStatus(.connecting)  // Thread-safe update

        // Reset tracking variables
        speculativeMessageIds = []
        finalMessageCount = 0

        // Start a fresh metrics session on a monotonic clock.
        metricsEpoch = DispatchTime.now()
        let modelId = configuration?.model.id ?? NovaSonicModel.novaSonic2.id
        sessionMetrics = NovaSonicSessionMetrics(modelId: modelId, startedAt: Date())
        
        let eventStream = createEventStream()
        
        let request = createStreamRequest(eventStream: eventStream)
        
        var result: InvokeModelWithBidirectionalStreamOutput
        
        do {
            result = try await client.invokeModelWithBidirectionalStream(input: request)
            NovaSonicLogger.standard("🔵 Bedrock stream invoked successfully!")
            self.stream = result
            
            sessionMetrics?.connectionReadyAt = elapsed()

            // Delay showing connected status by 2.0 seconds to align with actual Nova Sonic readiness
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                self.connectionStatus = .connected
            }
        } catch {
            NovaSonicLogger.error("❌ Failed to invoke Nova Sonic stream: \(error)")
            connectionStatus = .error(NovaSonicError.from(awsError: error))
            throw error
        }
        
        if let responseStream = result.body {
            Task {
                await processResponses(responseStream: responseStream)
            }
        } else {
            NovaSonicLogger.error("❌ No response body returned from Nova Sonic")
            connectionStatus = .error(NovaSonicError.serviceUnavailable)
        }
    }
    
    // MARK: - Event Stream Management (WORKING PATTERN)
    private func createEventStream() -> AsyncThrowingStream<BedrockRuntimeClientTypes.InvokeModelWithBidirectionalStreamInput, Error> {
        return AsyncThrowingStream { continuation in
            self.eventStreamContinuation = continuation
            
            Task {
                // Helper function to yield events.
                func yieldEvent(_ json: String, label: String) {
                    continuation.yield(
                        .chunk(
                            .init(bytes: Data(json.utf8))
                        )
                    )
                }
                
                // Send text initialization events for NEW CHATS.
                var textInitEvents: [(String, String)] = [
                    // Nova Sonic 1 rejects endpointing sensitivity config — omit it there.
                    (BedrockEvents.sessionStartEvent(temperature: configuration!.temperature, topP: configuration!.topP, maxTokens: configuration!.maxTokens, endpointingSensitivity: configuration!.model == .novaSonic1 ? nil : configuration!.endpointingSensitivity.rawValue), "sessionStart"),
                ]

                // Send sessionUpdate after sessionStart if any session-update fields are configured
                if let sessionUpdateJson = BedrockEvents.sessionUpdateEvent(
                    pronunciationReplacements: configuration!.pronunciationReplacements,
                    languageHint: configuration!.languageHint,
                    keyterms: configuration!.keyterms
                ) {
                    textInitEvents.append((sessionUpdateJson, "sessionUpdate"))
                }

                textInitEvents += [
                    (BedrockEvents.promptStartEvent(promptName: promptName, voiceId: selectedVoice.rawValue, outputSampleRate: configuration!.outputSampleRate.hertz), "promptStart"),
                    (BedrockEvents.systemTextContentStartEvent(promptName: promptName, contentName: contentName), "systemTextContentStart"),
                    (BedrockEvents.textInputEvent(promptName: promptName, contentName: contentName, content: configuration!.systemPrompt), "textInput"),
                    (BedrockEvents.contentEndEvent(promptName: promptName, contentName: contentName), "contentEnd")
                ]
                
                // Add paralinguistic detection prompt if enabled (Nova 2.0)
                if configuration?.enableParalinguisticDetection == true {
                    NovaSonicLogger.standard("🎭 Enabling paralinguistic detection (sentiment tags)")
                    let paraContentName = UUID().uuidString
                    textInitEvents.append((BedrockEvents.paralinguisticContentStartEvent(promptName: promptName, contentName: paraContentName), "paralinguisticContentStart"))
                    textInitEvents.append((BedrockEvents.paralinguisticTextInputEvent(promptName: promptName, contentName: paraContentName), "paralinguisticTextInput"))
                    textInitEvents.append((BedrockEvents.contentEndEvent(promptName: promptName, contentName: paraContentName), "paralinguisticContentEnd"))
                }
                
                // Send text initialization events for RESUMING CHATS from chat history
                if case .resume(let previousTurns) = calledMode {
                    NovaSonicLogger.verbose("🔄 Resuming conversation with \(previousTurns.count) previous turns")
                    
                    // Add previous conversation turns after system prompt but before audio starts
                    for (index, (content, role)) in previousTurns.enumerated() {
                        let turnContentName = "\(contentName)-history-\(index)"
                        let upperRole = role.uppercased()
                        
                        let contentStartEvent = BedrockEvents.textContentStartEvent(promptName: promptName, contentName: turnContentName, role: upperRole)
                        let textInputEvent = BedrockEvents.historyTextInputEvent(promptName: promptName, contentName: turnContentName, content: content, role: upperRole)
                        let contentEndEvent = BedrockEvents.contentEndEvent(promptName: promptName, contentName: turnContentName)
                        
                        // Add events to the queue
                        textInitEvents.append((contentStartEvent, "historyContentStart-\(index)"))
                        textInitEvents.append((textInputEvent, "historyTextInput-\(index)"))
                        textInitEvents.append((contentEndEvent, "historyContentEnd-\(index)"))
                    }
                }
                
                // Add initial text prompt if provided (Nova 2.0)
                if shouldSpeakFirst, let textPrompt = configuration?.initialTextPrompt {
                    NovaSonicLogger.standard("🎙️ Adding initial text prompt to initialization: \(textPrompt)")
                    let textContentName = UUID().uuidString
                    textInitEvents.append((BedrockEvents.textContentStartEvent(promptName: promptName, contentName: textContentName), "initialTextContentStart"))
                    textInitEvents.append((BedrockEvents.historyTextInputEvent(promptName: promptName, contentName: textContentName, content: textPrompt, role: "USER"), "initialTextInput"))
                    textInitEvents.append((BedrockEvents.contentEndEvent(promptName: promptName, contentName: textContentName), "initialTextContentEnd"))
                }
                
                for (evtJson, label) in textInitEvents {
                    yieldEvent(evtJson, label: label)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                
                // Send the audio initialization event.
                let audioInitEvent = BedrockEvents.audioContentStartEvent(promptName: promptName, audioContentName: audioContentName, inputSampleRate: configuration!.inputSampleRate.hertz)
                yieldEvent(audioInitEvent, label: "audioContentStart")
                try? await Task.sleep(nanoseconds: 100_000_000)
                
                // Send initial prompt if speakFirst is enabled (audio fallback for legacy)
                NovaSonicLogger.verbose("Checking shouldSpeakFirst = \(shouldSpeakFirst)")
                if shouldSpeakFirst && configuration?.initialTextPrompt == nil {
                    // Legacy: Send audio file only if no text prompt provided
                    NovaSonicLogger.standard("🎙️ Starting initial audio prompt sequence")
                    NovaSonicLogger.standard("🎙️ Sending initial audio prompt to make Nova Sonic speak first")
                    
                    if let initialAudioData = self.getInitialAudioData() {
                        NovaSonicLogger.standard("🎙️ Got initial audio data, size: \(initialAudioData.count) bytes")
                        let audioInputEvent = BedrockEvents.audioInputEvent(
                            audioData: initialAudioData,
                            promptName: promptName,
                            audioContentName: audioContentName
                        )
                        NovaSonicLogger.standard("🎙️ Created audioInputEvent, sending to Nova Sonic...")
                        yieldEvent(audioInputEvent, label: "initialAudioPrompt")
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        NovaSonicLogger.standard("🎙️ Initial audio prompt sent successfully")
                    } else {
                        NovaSonicLogger.error("No audio data available - skipping speakFirst feature")
                        NovaSonicLogger.standard("❌ speakFirst skipped - no hello.wav file found")
                    }
                }
                
                // Setup the audio streams.
                try? await setupAudioStreams()
                
                #if IOS_AUDIO
                do {
                    try await audioManager.startRecording { [weak self] chunkData in
                        // Log audio chunk processing (but not too frequently)
                        guard let strongSelf = self else { return }
                        strongSelf.chunkCounter += 1
                        if strongSelf.chunkCounter % 25 == 0 { // Log every 25th chunk
                    // Remove very verbose audio chunk logging
                        }
                        
                        // Build the JSON payload
                        let promptName = strongSelf.promptName
                        let audioContentName = strongSelf.audioContentName
                        
                        let json = BedrockEvents.audioInputEvent(
                            audioData: chunkData,
                            promptName: promptName,
                            audioContentName: audioContentName
                        )
                        
                        // Send the audio chunk to the stream
                        continuation.yield(
                            .chunk(
                                .init(bytes: Data(json.utf8))
                            )
                        )
                    }
                    NovaSonicLogger.verbose("🎙️ Audio recording started successfully!")
                } catch {
                    NovaSonicLogger.error("❌ Failed to start audio recording: \(error)")
                }
                #else
                NovaSonicLogger.verbose("Audio recording not available on this platform")
                #endif
            }
        }
    }
    
    private func createStreamRequest(eventStream: AsyncThrowingStream<BedrockRuntimeClientTypes.InvokeModelWithBidirectionalStreamInput, Error>) -> InvokeModelWithBidirectionalStreamInput {
        return InvokeModelWithBidirectionalStreamInput(
            body: eventStream,
            modelId: configuration?.model.id ?? NovaSonicModel.novaSonic2.id
        )
    }
    
    // MARK: - Audio Management
    private func setupAudioStreams() async throws {
        
        #if IOS_AUDIO
        do {
            // Configure the audio manager with the same configuration
            if let config = configuration {
                audioManager.configure(with: config)
            }
            
            // Ensure we have microphone permission
            if !audioManager.hasAudioPermission {
                let granted = await audioManager.requestMicrophonePermission()
                if !granted {
                    throw NovaSonicError.audioPermissionDenied
                }
            }
            
            // Start the audio session
            try await audioManager.startAudioSession()
            
            // Set up audio streams
            _ = try await audioManager.setupAudioStreams()
            NovaSonicLogger.standard("🔵 Audio streams setup completed successfully!")
        } catch {
            let novaSonicError = NovaSonicError.from(audioError: error)
            NovaSonicLogger.error("❌ Failed to set up audio streams: \(novaSonicError.localizedDescription)")
            lastError = novaSonicError
            delegate?.didEncounterError(novaSonicError)
            throw novaSonicError
        }
        #else
        NovaSonicLogger.verbose("Audio streams not available on this platform")
        #endif
    }
    
    private func cleanup() async {
        
        #if IOS_AUDIO
        // Use audio manager's cleanup method silently
        await audioManager.cleanup()
        #endif
        
        // Cleanup completed silently
    }
    
    // MARK: - Response Processing
    private func processResponses(
        responseStream: AsyncThrowingStream<
            BedrockRuntimeClientTypes.InvokeModelWithBidirectionalStreamOutput,
            Error
        >
    ) async {
        NovaSonicLogger.verbose("🔵 Starting to process responses from Nova Sonic...")
        var responseCount = 0
        
        do {
            for try await output in responseStream {
                responseCount += 1
                if responseCount % 10 == 0 { // Log every 10th response
                    // Remove verbose response counting
                }
                
                if !isStreaming {
                    break
                }
                
                // Extract the raw bytes from output using the reference pattern
                let eventBytes: Data?
                switch output {
                case .chunk(let payloadPart):
                    eventBytes = payloadPart.bytes
                case .sdkUnknown(let unknownString):
                    eventBytes = Data(unknownString.utf8)
                }
                
                guard let bytes = eventBytes, !bytes.isEmpty else {
                    // Skip empty responses silently
                    continue
                }
                
                // Log first few responses to see what we're getting
                if responseCount <= 5 {
                    let _ = String(decoding: bytes, as: UTF8.self)
                    // Process response silently - JSON dumps are too noisy
                }
                
                // Convert bytes to string for parsing
                let jsonString = String(decoding: bytes, as: UTF8.self)
                
                // Parse the JSON structure
                guard
                    let jsonData = jsonString.data(using: .utf8),
                    let topLevel = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                    let event = topLevel["event"] as? [String: Any]
                else {
                    NovaSonicLogger.error("❌ Failed to parse Nova Sonic response")
                    continue
                }
                
                await handleEvent(event)
            }
        } catch {
            NovaSonicLogger.error("❌ Error processing responses: \(error)")
            let novaSonicError = NovaSonicError.from(awsError: error)
            lastError = novaSonicError
            delegate?.didEncounterError(novaSonicError)
        }
        
    }
    
    private func handleEvent(_ event: [String: Any]) async {
        // Handle different event types
        if let contentStart = event["contentStart"] as? [String: Any] {
            if let contentId = contentStart["contentId"] as? String {
                // Process content silently - internal IDs are not useful for debugging
                currentContentId = contentId
            }
            
            // Check for speculative vs final content
            if let additionalFields = contentStart["additionalModelFields"] as? String,
               let additionalData = additionalFields.data(using: .utf8),
               let additionalJson = try? JSONSerialization.jsonObject(with: additionalData) as? [String: Any],
               let generationStage = additionalJson["generationStage"] as? String {
                
                if generationStage == "SPECULATIVE" {
                    isSpeculativeText = true
                    withCurrentTurn { if $0.firstSpeculativeTextAt == nil { $0.firstSpeculativeTextAt = elapsed() } }
                    // Process speculative text silently
                } else if generationStage == "FINAL" {
                    isSpeculativeText = false
                    // Process final text silently
                }
            }
        }
        
        if let textOutput = event["textOutput"] as? [String: Any],
           let content = textOutput["content"] as? String {
            
            let role = textOutput["role"] as? String ?? "UNKNOWN"
            didReceiveTextOutput = true
            
            // Extract contentId from textOutput if available
            let _ = textOutput["contentId"] as? String ?? currentContentId
            // Process text output silently - internal details not needed
            
            if content.contains("{ \"interrupted\" : true }") {
                NovaSonicLogger.standard("🚨 BARGE-IN DETECTED - User interrupted the assistant!")
                NovaSonicLogger.verbose("🚨 Original content: \(content)")
                withCurrentTurn { $0.bargeIn = true }
                
                // Handle interruption by flushing audio queue
                #if IOS_AUDIO
                Task {
                    await audioManager.flushAudio()
                }
                #endif
                
                // Notify delegate about the interruption (for any external handling)
                delegate?.didReceiveTextResponse("Barge-in detected")
                
                NovaSonicLogger.standard("🚨 User interrupted - barge-in detected")
                // Return early to avoid processing this as a normal message
                return
            }
            
            if role.uppercased() == "USER" {
                beginTurnIfNeeded()
                withCurrentTurn { if $0.userTranscriptAt == nil { $0.userTranscriptAt = elapsed() } }
                appendMessage(content, role: role, isSpeculative: false)
                delegate?.didReceiveTranscription(content, isFinal: true)
            } else if role.uppercased() == "ASSISTANT" {
                if isSpeculativeText {
                    // For speculative text, always show and track in order
                    // Add speculative message silently
                    appendMessage(content, role: role, isSpeculative: true)
                    delegate?.didReceiveTextResponse(content)
                } else {
                    // For final text, update speculative messages in order
                    // Update speculative message silently
                    updateSpeculativeMessage(content, finalMessageCount)
                    finalMessageCount += 1
                    delegate?.didReceiveTextResponse(content)
                }
            }
        }
        
        if let toolUse = event["toolUse"] as? [String: Any],
           let toolName = toolUse["toolName"] as? String,
           let toolUseId = toolUse["toolUseId"] as? String {
            
            NovaSonicLogger.standard("🔧 Tool use requested: \(toolName)")
            
            // Extract parameters
            var capturedParameters: [String: Any] = [:]
            if let content = toolUse["content"] as? String,
               let contentData = content.data(using: .utf8),
               let contentJson = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                capturedParameters = contentJson
            }
            
            // Notify delegate about tool call
            delegate?.didReceiveToolCall(toolName, parameters: capturedParameters, toolUseId: toolUseId)

            withCurrentTurn { $0.toolCalls.append(ToolCallMetric(toolName: toolName, toolUseId: toolUseId, requestedAt: elapsed())) }

            // Execute tool using the registry
            Task {
                let result = await NovaSonicToolRegistry.shared.executeToolCall(toolName, parameters: capturedParameters, toolUseId: toolUseId)
                do {
                    try await self.sendToolResultBack(toolUseId: toolUseId, resultJSON: result)
                    self.recordToolResultSent(toolUseId: toolUseId)
                } catch {
                    NovaSonicLogger.error("❌ Failed to send tool result: \(error)")
                }
            }
        }
        
        if let audioOutput = event["audioOutput"] as? [String: Any],
           let content = audioOutput["content"] as? String,
           let audioData = Data(base64Encoded: content) {
            
            if !isStreaming {
                return
            }

            // Stamp only the FIRST audio chunk of the turn. Guarding here avoids mutating
            // the @Published sessionMetrics on every packet (dozens/sec), which would
            // redraw the whole voice UI throughout the assistant's response.
            if sessionMetrics?.turns.last?.firstAudioChunkAt == nil {
                withCurrentTurn { if $0.firstAudioChunkAt == nil { $0.firstAudioChunkAt = elapsed() } }
            }

            #if IOS_AUDIO
            Task {
                try await audioManager.playAudio(audioData)
            }
            #endif
        }
    }
    
    // MARK: - Message Management
    private func appendMessage(_ text: String, role: String, isSpeculative: Bool) {
        let isUser = role.uppercased() == "USER"
        let messageType: ChatMessage.MessageType = isUser ? .user : (isSpeculative ? .speculative : .assistant)
        
        let msg = ChatMessage(
            text: text,
            isUser: isUser,
            messageType: messageType
        )
        
        // If this is a speculative assistant message, track it in order for later replacement
        if isSpeculative && !isUser && messageType == .speculative {
            speculativeMessageIds.append(msg.id)
        }
        
        // Target binding used to display Resuming Chats in Chat History
        if let targetBinding = targetMessagesBinding {
            handleMessageAppendWithBinding(msg: msg, messages: targetBinding)
        } else {
            handleMessageAppendDirect(msg: msg)
        }
        
        // Save message to DynamoDB (only save final messages)
        NovaSonicLogger.verbose("💾 appendMessage - isSpeculative: \(isSpeculative), role: \(role), text: \(text.prefix(30))...")
        if !isSpeculative {
            saveToDynamoDB(text: text, role: role)
        } else {
            // Skip saving speculative messages silently
        }
    }
    
    // Helper to update a speculative message with final text
    func updateSpeculativeMessage(_ finalText: String, _ index: Int) {
        if index < speculativeMessageIds.count {
            let messageId = speculativeMessageIds[index]
            // Update speculative message silently
            
            // Update in the main messages array
            if let msgIndex = messages.firstIndex(where: { $0.id == messageId }) {
                messages[msgIndex].text = finalText
                messages[msgIndex].messageType = .assistant
            }
            
            // Update in the target binding if available
            if let targetBinding = targetMessagesBinding,
               let msgIndex = targetBinding.wrappedValue.firstIndex(where: { $0.id == messageId }) {
                targetBinding.wrappedValue[msgIndex].text = finalText
                targetBinding.wrappedValue[msgIndex].messageType = .assistant
            }
            
            // 🔧 FIX: Save the final assistant message to database
            // Save final message silently
            saveToDynamoDB(text: finalText, role: "ASSISTANT")
            
        } else {
            NovaSonicLogger.error("❌ Index \(index) out of bounds for speculative messages array (count: \(speculativeMessageIds.count))")
        }
    }
    
    private func handleMessageAppendWithBinding(msg: ChatMessage, messages: Binding<[ChatMessage]>) {
        messages.wrappedValue.append(msg)
    }
    
    private func handleMessageAppendDirect(msg: ChatMessage) {
        addMessage(msg)  // Use thread-safe method
    }
    
    public func stopStreaming() async {
        NovaSonicLogger.standard("🛑 Stopping Nova Sonic streaming session")
        
        // Set streaming state to false first to prevent processing more audio data
        updateIsStreaming(false)  // Thread-safe update
        
        // Reset tracking variables
        speculativeMessageIds = []
        finalMessageCount = 0
        
        #if IOS_AUDIO
        // Stop recording and playback with error handling
        do {
            await audioManager.stopRecording()
            await audioManager.stopPlayback()
            NovaSonicLogger.verbose("✅ Audio streams stopped successfully")
        } catch {
            NovaSonicLogger.error("⚠️ Error stopping audio streams: \(error)")
            // Continue cleanup even if audio stop fails
        }
        #endif
        
        // Send end-of-stream events with a short delay between each
        let endEvents = [
            BedrockEvents.audioContentEndEvent(promptName: promptName, audioContentName: audioContentName),
            BedrockEvents.promptEndEvent(promptName: promptName),
            BedrockEvents.sessionEndEvent()
        ]
        
        for event in endEvents {
            do {
                try await sendEvent(event)
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
            } catch {
                NovaSonicLogger.verbose("⚠️ Error sending end event: \(error)")
                // Continue with other events even if one fails
            }
        }
        
        // Clean up audio resources
        await cleanup()
        
        // Finish the event stream and clean up
        eventStreamContinuation?.finish()
        stream = nil
        
        // Update status and notify delegate
        connectionStatus = .disconnected
        delegate?.didStopStreaming()
        
        NovaSonicLogger.standard("✅ Nova Sonic streaming session stopped")
    }
    
    // MARK: - Utility Methods
    
    func sendEvent(_ jsonString: String, label: String = "event") async throws {
        guard let continuation = eventStreamContinuation else {
            NovaSonicLogger.error("❌ sendEvent called before stream open!")
            return
        }
        
        continuation.yield(
            .chunk(
                .init(bytes: Data(jsonString.utf8))
            )
        )
    }
    
    // MARK: - Client Configuration
    func configureClient() {
        // Only create client if none was provided
        guard bedrockClient == nil else {
            NovaSonicLogger.standard("✅ Using provided Bedrock client, skipping default client creation")
            return
        }
        
        // Create default client only if needed
        do {
            let region = configuration?.region ?? "us-east-1"
            
            // Create base configuration
            var config = try BedrockRuntimeClient.BedrockRuntimeClientConfiguration(region: region)
            
            // Apply credentials if provided (this mutates config, despite compiler warning)
            if let credentialsProvider = configuration?.awsCredentialIdentityResolver {
                config.awsCredentialIdentityResolver = credentialsProvider
                NovaSonicLogger.verbose("🔐 Using provided credentials for Bedrock client")
            }
            
            self.bedrockClient = BedrockRuntimeClient(config: config)
            NovaSonicLogger.standard("🔧 Created default Bedrock client")
        } catch {
            let novaSonicError = NovaSonicError.from(awsError: error)
            NovaSonicLogger.error("❌ Failed to initialize Bedrock client: \(novaSonicError.localizedDescription)")
            lastError = novaSonicError
            self.bedrockClient = nil
        }
    }
    
    // MARK: - Conversation Management
    
    // Set the target messages binding for resumed conversations
    internal func setTargetMessages(_ binding: Binding<[ChatMessage]>?) {
        self.targetMessagesBinding = binding
    }
    
    // Set the current conversation ID for resumed conversations
    public func setCurrentConversationId(_ id: String?) {
        self.currentConversationId = id
    }
    
    // Clear all messages from the main messages array
    public func clearMessages() {
        messages.removeAll()
        currentStreamingMessage = nil
    }
    
    /// Start a new conversation session (clears messages and generates new session ID)
    public func startNewConversation() {
        clearMessages()
        promptName = UUID().uuidString
        currentConversationId = nil
    }
    
    func sendToolResultBack(toolUseId: String, resultJSON: [String: Any]) async throws {
        let contentName = UUID().uuidString
        
        // Convert result to JSON string
        let jsonData = try JSONSerialization.data(withJSONObject: resultJSON)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        // Send tool result silently
        
        // open the TOOL result block
        let contentStartEvent = BedrockEvents.makeContentStart(promptName, contentName, toolUseId)
        // Send tool content start silently
        try await sendEvent(contentStartEvent, label: "TOOL contentStart")
        
        // send the TOOL result
        let toolResultEvent = BedrockEvents.makeToolResult(promptName, contentName, jsonString)
        NovaSonicLogger.standard("Sending TOOL result: \(toolResultEvent)")
        try await sendEvent(toolResultEvent, label: "TOOL result")
        
        // close the TOOL block
        try await sendEvent(
            BedrockEvents.makeContentEnd(promptName,
                                         contentName),
            label: "TOOL contentEnd")
    }
    
    // MARK: - History Integration
    private func saveToDynamoDB(text: String, role: String) {
        NovaSonicLogger.verbose("💾 saveToDynamoDB called - role: \(role), text: \(text.prefix(50))...")
        
        // Use history manager if available
        guard let historyManager = historyManager else {
            NovaSonicLogger.verbose("❌ No history manager configured - message not saved")
            return
        }
        
        NovaSonicLogger.verbose("✅ History manager available, saving message...")
        
        // Use current conversation ID or create a new one
        let conversationId = currentConversationId ?? promptName
        NovaSonicLogger.standard("Using conversation ID: \(conversationId)")
        
        // Save message asynchronously
        Task {
            do {
                try await historyManager.saveMessage(
                    conversationId: conversationId,
                    content: text,
                    role: role.lowercased(),
                    messageType: "normal"
                )
                NovaSonicLogger.verbose("✅ Successfully saved message to history: \(role) - \(text.prefix(50))...")
            } catch {
                NovaSonicLogger.error("❌ Failed to save message to history: \(error)")
            }
        }
    }
    
    // MARK: - Initial Audio Prompt (Private)

    /// Returns hello.wav audio data for the speakFirst feature.
    /// Priority: package bundle (HelloAudio) → host app main bundle → all other bundles.
    private func getInitialAudioData() -> Data? {
        // 1. Package-bundled resource (preferred — no host-app setup required)
        if let data = HelloAudio.data() {
            NovaSonicLogger.standard("✅ Using package-bundled hello.wav (\(data.count) bytes)")
            return data
        }

        // 2. Host app bundle override (allows app to supply a custom greeting)
        if let url = Bundle.main.url(forResource: "hello", withExtension: "wav"),
           let data = try? Data(contentsOf: url) {
            NovaSonicLogger.standard("✅ Using host app hello.wav (\(data.count) bytes)")
            return data
        }

        NovaSonicLogger.error("hello.wav not found in package or app bundle — speakFirst will be skipped")
        return nil
    }
}

// MARK: - Supporting Types

public enum ConversationMode: Equatable {
    case newConversation
    case resume([(String, String)]) // (content, role) pairs
    
    // Custom Equatable implementation since we have associated values
    public static func == (lhs: ConversationMode, rhs: ConversationMode) -> Bool {
        switch (lhs, rhs) {
        case (.newConversation, .newConversation):
            return true
        case (.resume(let lhsTurns), .resume(let rhsTurns)):
            return lhsTurns.count == rhsTurns.count &&
                   zip(lhsTurns, rhsTurns).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        default:
            return false
        }
    }
}

public enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(NovaSonicError)
    
    public static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Delegate Protocol
public protocol NovaSonicStreamDelegate: AnyObject {
    func didStartStreaming()
    func didStopStreaming()
    func didReceiveTranscription(_ text: String, isFinal: Bool)
    func didReceiveTextResponse(_ text: String)
    func didReceiveToolCall(_ toolName: String, parameters: [String: Any], toolUseId: String)
    func didEncounterError(_ error: NovaSonicError)
}

// Default implementations
public extension NovaSonicStreamDelegate {
    func didStartStreaming() {}
    func didStopStreaming() {}
    func didReceiveTranscription(_ text: String, isFinal: Bool) {}
    func didReceiveTextResponse(_ text: String) {}
    func didReceiveToolCall(_ toolName: String, parameters: [String: Any], toolUseId: String) {}
    func didEncounterError(_ error: NovaSonicError) {}
}
