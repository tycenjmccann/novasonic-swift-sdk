//
//  NovaSonicChatView.swift
//  NovaSonic Package
//
//  Simplified chat interface for Nova Sonic voice conversations
//

import SwiftUI
import NovaSonicCore
import SmithyIdentity

/// Complete chat interface for Nova Sonic voice conversations
public struct NovaSonicChatView: View {
    
    // MARK: - Properties
    
    /// Stream manager for handling Nova Sonic interactions
    @ObservedObject public var streamManager: NovaSonicStreamManager
    
    // Direct configuration properties
    public let voice: NovaSonicVoice
    public let region: String
    public let temperature: Double
    public let topP: Double
    public let maxTokens: Int
    public let systemPrompt: String
    public let inputSampleRate: NovaSonicSampleRate
    public let outputSampleRate: NovaSonicSampleRate
    public let endpointingSensitivity: EndpointingSensitivity  // Nova 2.0
    public let enableParalinguisticDetection: Bool  // Nova 2.0
    public let initialTextPrompt: String?  // Nova 2.0
    public let enableDynamoDBHistory: Bool
    public let dynamoDBTableName: String
    public let dynamoDBUserId: String?
    public let dynamoDBRegion: String
    public let awsCredentialIdentityResolver: (any SmithyIdentity.AWSCredentialIdentityResolver)?
    public let logLevel: NovaSonicLogLevel
    
    /// Tools to register with the system
    public let tools: [NovaSonicTool.Type]
    
    /// Whether to show the voice selector below the microphone button
    public let showVoiceSelector: Bool
    
    /// Whether to show conversation history button
    public let showConversationHistory: Bool
    
    /// Whether Nova Sonic should speak first (send initial audio prompt)
    public let speakFirst: Bool
    
    // MARK: - State
    
    @State private var glowScale: CGFloat = 0.0
    @State private var loadingRotation: Double = 0.0
    @State private var selectedVoice: NovaSonicVoice
    @State private var showVoiceChangeAlert = false
    @State private var showingConversationList = false
    
    // MARK: - Initialization
    
    public init(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        region: String = "us-east-1",
        temperature: Double = 0.7,
        topP: Double = 0.9,
        maxTokens: Int = 1024,
        systemPrompt: String = "You are a helpful assistant.",
        inputSampleRate: NovaSonicSampleRate = .rate16kHz,
        outputSampleRate: NovaSonicSampleRate = .rate24kHz,
        endpointingSensitivity: EndpointingSensitivity = .high,
        enableParalinguisticDetection: Bool = false,
        initialTextPrompt: String? = nil,
        enableDynamoDBHistory: Bool = false,
        dynamoDBTableName: String = "nova_sonic_chat_history",
        dynamoDBUserId: String? = nil,
        dynamoDBRegion: String = "us-east-1",
        awsCredentialIdentityResolver: (any SmithyIdentity.AWSCredentialIdentityResolver)? = nil,
        logLevel: NovaSonicLogLevel = .standard,
        tools: [NovaSonicTool.Type] = [],
        showVoiceSelector: Bool = false,
        showConversationHistory: Bool = false,
        speakFirst: Bool = false
    ) {
        self.streamManager = streamManager
        self.voice = voice
        self.region = region
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.inputSampleRate = inputSampleRate
        self.outputSampleRate = outputSampleRate
        self.endpointingSensitivity = endpointingSensitivity
        self.enableParalinguisticDetection = enableParalinguisticDetection
        self.initialTextPrompt = initialTextPrompt
        self.enableDynamoDBHistory = enableDynamoDBHistory
        self.dynamoDBTableName = dynamoDBTableName
        self.dynamoDBUserId = dynamoDBUserId
        self.dynamoDBRegion = dynamoDBRegion
        self.awsCredentialIdentityResolver = awsCredentialIdentityResolver
        self.logLevel = logLevel
        self.tools = tools
        self.showVoiceSelector = showVoiceSelector
        self.showConversationHistory = showConversationHistory
        self.speakFirst = speakFirst
        self._selectedVoice = State(initialValue: voice)
    }
    
    // MARK: - Convenience Initializers
    
    /// Creative configuration with higher temperature and topP
    public static func creative(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        showVoiceSelector: Bool = false,
        showConversationHistory: Bool = false,
        speakFirst: Bool = false
    ) -> NovaSonicChatView {
        return NovaSonicChatView(
            streamManager: streamManager,
            voice: voice,
            temperature: 0.9,
            topP: 0.95,
            systemPrompt: systemPrompt,
            tools: tools,
            showVoiceSelector: showVoiceSelector,
            showConversationHistory: showConversationHistory,
            speakFirst: speakFirst
        )
    }
    
    /// Maximum quality configuration with 24kHz audio
    public static func maxQuality(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        showVoiceSelector: Bool = false,
        showConversationHistory: Bool = false,
        speakFirst: Bool = false
    ) -> NovaSonicChatView {
        return NovaSonicChatView(
            streamManager: streamManager,
            voice: voice,
            systemPrompt: systemPrompt,
            inputSampleRate: NovaSonicSampleRate.rate24kHz,
            outputSampleRate: NovaSonicSampleRate.rate24kHz,
            tools: tools,
            showVoiceSelector: showVoiceSelector,
            showConversationHistory: showConversationHistory,
            speakFirst: speakFirst
        )
    }
    
    /// Low bandwidth configuration with 8kHz audio
    public static func lowBandwidth(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        showVoiceSelector: Bool = false,
        showConversationHistory: Bool = false,
        speakFirst: Bool = false
    ) -> NovaSonicChatView {
        return NovaSonicChatView(
            streamManager: streamManager,
            voice: voice,
            systemPrompt: systemPrompt,
            inputSampleRate: NovaSonicSampleRate.rate8kHz,
            outputSampleRate: NovaSonicSampleRate.rate8kHz,
            tools: tools,
            showVoiceSelector: showVoiceSelector,
            showConversationHistory: showConversationHistory,
            speakFirst: speakFirst
        )
    }
    
    /// Focused configuration with lower temperature for more precise responses
    public static func focused(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        showVoiceSelector: Bool = false,
        showConversationHistory: Bool = false,
        speakFirst: Bool = false
    ) -> NovaSonicChatView {
        return NovaSonicChatView(
            streamManager: streamManager,
            voice: voice,
            temperature: 0.3,
            topP: 0.7,
            systemPrompt: systemPrompt,
            tools: tools,
            showVoiceSelector: showVoiceSelector,
            showConversationHistory: showConversationHistory,
            speakFirst: speakFirst
        )
    }
    
    /// Simple DynamoDB history setup
    public static func withDynamoDBHistory(
        streamManager: NovaSonicStreamManager,
        userId: String,
        tableName: String = "nova_sonic_chat_history",
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        showVoiceSelector: Bool = false,
        showConversationHistory: Bool = true,
        speakFirst: Bool = false
    ) -> NovaSonicChatView {
        return NovaSonicChatView(
            streamManager: streamManager,
            voice: voice,
            systemPrompt: systemPrompt,
            enableDynamoDBHistory: true,
            dynamoDBTableName: tableName,
            dynamoDBUserId: userId,
            tools: tools,
            showVoiceSelector: showVoiceSelector,
            showConversationHistory: showConversationHistory,
            speakFirst: speakFirst
        )
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 20) {
            // Conversation history button (if enabled)
            if showConversationHistory {
                conversationHistoryButton
                    .padding(.top, 10)
            }
            
            // Chat messages area
            chatMessagesView
            
            // Microphone button (integrated)
            microphoneButton
            
            // Voice selector (if enabled)
            if showVoiceSelector {
                voiceSelector
                    .padding(.top, 10)
            }
        }
        .padding(.bottom, 20)
        .onAppear {
            setupNovaSonic()
        }
        .onDisappear {
            // Safety: Stop streaming if view disappears during active session
            if streamManager.isStreaming {
                NovaSonicLogger.standard("🚨 ChatView: View disappearing during active session - stopping stream")
                Task {
                    await streamManager.stopStreaming()
                }
            }
        }
        .alert("Voice Change Not Available", isPresented: $showVoiceChangeAlert) {
            Button("OK") { }
        } message: {
            Text("Voice can only be changed before starting a chat session. Please stop the current conversation to select a different voice.")
        }
        .sheet(isPresented: $showingConversationList) {
            ConversationListView(streamManager: streamManager)
        }
    }
    
    // MARK: - Chat Messages View
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(streamManager.messages) { message in
                        messageRow(for: message)
                            .id(message.id) // Ensure each message has an ID for scrolling
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: streamManager.messages.count) { _ in
                // Auto-scroll to the latest message when new messages are added
                if let lastMessage = streamManager.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                // Scroll to bottom when view appears (for loaded conversations)
                if let lastMessage = streamManager.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private func messageRow(for message: ChatMessage) -> some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.text)
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity * 0.8, alignment: .trailing)
            } else {
                Text(message.text)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity * 0.8, alignment: .leading)
                Spacer()
            }
        }
    }
    
    // MARK: - Conversation History Button
    
    private var conversationHistoryButton: some View {
        HStack {
            Button(action: {
                showingConversationList = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Conversations")
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // New chat button (only show if we have messages)
            if !streamManager.messages.isEmpty {
                Button(action: {
                    NovaSonicLogger.standard("Manually starting new conversation")
                    streamManager.startNewConversation()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("New Chat")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Microphone Button
    
    private var microphoneButton: some View {
        ZStack {
            // Glow circle (only visible when connected and streaming)
            if streamManager.connectionStatus == .connected && streamManager.isStreaming && glowScale > 0 {
                Circle()
                    .fill(Color.green.opacity(0.7))
                    .frame(width: 95, height: 95)
                    .scaleEffect(glowScale)
            }
            
            // Main button circle with state-based colors
            Circle()
                .fill(buttonColor)
                .frame(width: 75, height: 75)
            
            // Button content based on connection state
            buttonContent
        }
        .frame(width: 95, height: 95)
        .background(Color.clear)
        .contentShape(Circle())
        .accessibilityIdentifier("novaSonicMicButton")
        .onTapGesture {
            NovaSonicLogger.standard("Mic button tapped - connectionStatus: \(streamManager.connectionStatus), isStreaming: \(streamManager.isStreaming)")
            handleMicrophoneTap()
        }
        .onAppear {
            updateAnimations()
        }
        .onChange(of: streamManager.connectionStatus) { _ in
            updateAnimations()
        }
        .onChange(of: streamManager.isStreaming) { _ in
            updateAnimations()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Button color based on connection state
    private var buttonColor: Color {
        switch streamManager.connectionStatus {
        case .disconnected:
            return .blue
        case .connecting:
            return .orange
        case .connected:
            return streamManager.isStreaming ? .green : .blue
        case .error:
            return .red
        }
    }
    
    /// Button content based on connection state
    @ViewBuilder
    private var buttonContent: some View {
        switch streamManager.connectionStatus {
        case .disconnected:
            Image(systemName: "message.badge.waveform")
                .font(.system(size: 30))
                .foregroundColor(.white)
                
        case .connecting:
            // Loading spinner
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 30, height: 30)
                .rotationEffect(Angle(degrees: loadingRotation))
                
        case .connected:
            Image(systemName: streamManager.isStreaming ? "waveform" : "message.badge.waveform")
                .font(.system(size: 30))
                .foregroundColor(.white)
                
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Voice Selector
    
    private var voiceSelector: some View {
        VStack(spacing: 8) {
            Text("Voice")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(NovaSonicVoice.allCases, id: \.self) { voice in
                    voiceButton(for: voice)
                }
            }
        }
    }
    
    private func voiceButton(for voice: NovaSonicVoice) -> some View {
        Button(action: {
            if streamManager.isStreaming {
                // Show alert if trying to change voice during streaming
                showVoiceChangeAlert = true
            } else {
                // Allow voice change when not streaming
                selectedVoice = voice
                updateVoiceConfiguration()
            }
        }) {
            VStack(spacing: 4) {
                Text(voice.displayName)
                    .font(.caption2)
                    .fontWeight(selectedVoice == voice ? .semibold : .regular)
                
                Text(voice.region)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedVoice == voice ? Color.blue.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedVoice == voice ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Private Methods
    
    /// Handle microphone button tap
    private func handleMicrophoneTap() {
        Task {
            if streamManager.isStreaming {
                await streamManager.stopStreaming()
            } else {
                // Check if we have an existing conversation to continue
                if streamManager.getCurrentConversationId() != nil && !streamManager.messages.isEmpty {
                    // Continue existing conversation - convert messages to resume format
                    NovaSonicLogger.standard("Continuing existing conversation with \(streamManager.messages.count) messages")
                    let conversationHistory = streamManager.messages.map { message in
                        (message.text, message.isUser ? "user" : "assistant")
                    }
                    
                    // Auto-scroll to the latest message when new messages are added
                    if let first = conversationHistory.first {
                        NovaSonicLogger.verbose("First message in history: \(first.1) - \(first.0.prefix(50))...")
                    }
                    if let last = conversationHistory.last {
                        NovaSonicLogger.verbose("Last message in history: \(last.1) - \(last.0.prefix(50))...")
                    }
                    
                    await streamManager.startStreaming(mode: .resume(conversationHistory))
                } else {
                    // Start new conversation
                    NovaSonicLogger.standard("Starting new conversation")
                    streamManager.startNewConversation()
                    await streamManager.startStreaming(mode: .newConversation)
                }
            }
        }
    }
    
    /// Update animations based on current state
    private func updateAnimations() {
        switch streamManager.connectionStatus {
        case .connecting:
            startLoadingAnimation()
            stopGlowAnimation()
            
        case .connected:
            stopLoadingAnimation()
            if streamManager.isStreaming {
                startGlowAnimation()
            } else {
                stopGlowAnimation()
            }
            
        default:
            stopLoadingAnimation()
            stopGlowAnimation()
        }
    }
    
    /// Start the loading spinner animation
    private func startLoadingAnimation() {
        withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
            loadingRotation = 360
        }
    }
    
    /// Stop the loading spinner animation
    private func stopLoadingAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            loadingRotation = 0
        }
    }
    
    /// Start the glow animation for the microphone button
    private func startGlowAnimation() {
        // Start the pulsing animation from a visible state
        withAnimation(.easeInOut(duration: 0.2)) {
            glowScale = 0.85
        }
        
        // Then start the repeating pulse animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                glowScale = 1.0
            }
        }
    }
    
    /// Stop the glow animation
    private func stopGlowAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            glowScale = 0.0
        }
    }
    
    /// Update voice configuration when voice selection changes
    private func updateVoiceConfiguration() {
        // Create new configuration with updated voice
        let newConfig = NovaSonicConfiguration(
            region: region,
            voice: selectedVoice,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            systemPrompt: systemPrompt,
            endpointingSensitivity: endpointingSensitivity,
            enableParalinguisticDetection: enableParalinguisticDetection,
            initialTextPrompt: initialTextPrompt,
            inputSampleRate: inputSampleRate,
            outputSampleRate: outputSampleRate,
            enableDynamoDBHistory: enableDynamoDBHistory,
            dynamoDBTableName: dynamoDBTableName,
            dynamoDBUserId: dynamoDBUserId,
            dynamoDBRegion: dynamoDBRegion,
            awsCredentialIdentityResolver: awsCredentialIdentityResolver,
            logLevel: logLevel
        )
        
        // Apply the updated configuration
        streamManager.configure(with: newConfig)
        NovaSonicLogger.standard("Voice changed to: \(selectedVoice.displayName)")
    }
    
    /// Set up Nova Sonic configuration and tools
    private func setupNovaSonic() {
        // Only configure if not already configured (to avoid overriding existing setup)
        if !streamManager.isConfigured {
            NovaSonicLogger.standard("NovaSonicChatView: Configuring stream manager")
            
            // Create configuration from individual parameters
            let configuration = NovaSonicConfiguration(
                region: region,
                voice: voice,
                temperature: temperature,
                topP: topP,
                maxTokens: maxTokens,
                systemPrompt: systemPrompt,
                endpointingSensitivity: endpointingSensitivity,
                enableParalinguisticDetection: enableParalinguisticDetection,
                initialTextPrompt: initialTextPrompt,
                inputSampleRate: inputSampleRate,
                outputSampleRate: outputSampleRate,
                enableDynamoDBHistory: enableDynamoDBHistory,
                dynamoDBTableName: dynamoDBTableName,
                dynamoDBUserId: dynamoDBUserId,
                dynamoDBRegion: dynamoDBRegion,
                awsCredentialIdentityResolver: awsCredentialIdentityResolver,
                logLevel: logLevel
            )
            
            streamManager.configure(with: configuration)
        } else {
            NovaSonicLogger.verbose("NovaSonicChatView: Stream manager already configured, skipping")
        }
        
        // Configure speak first option
        streamManager.setSpeakFirst(speakFirst)
        
        // Register provided tools with the global registry
        for tool in tools {
            NovaSonicToolRegistry.shared.register(tool)
        }
    }
}

// MARK: - Preview

struct NovaSonicChatView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Basic usage
            NovaSonicChatView(
                streamManager: NovaSonicStreamManager(),
                voice: NovaSonicVoice.tiffany,
                systemPrompt: "You are a helpful assistant.",
                showVoiceSelector: false
            )
            .previewDisplayName("Basic Usage")
            
            // With voice selector
            NovaSonicChatView(
                streamManager: NovaSonicStreamManager(),
                voice: .matthew,
                systemPrompt: "You are a helpful assistant.",
                showVoiceSelector: true
            )
            .previewDisplayName("With Voice Selector")
            
            // Creative configuration
            NovaSonicChatView.creative(
                streamManager: NovaSonicStreamManager(),
                voice: .amy,
                systemPrompt: "You are a creative writing assistant.",
                showVoiceSelector: true
            )
            .previewDisplayName("Creative Configuration")
            
            // With DynamoDB history
            NovaSonicChatView.withDynamoDBHistory(
                streamManager: NovaSonicStreamManager(),
                userId: "user123",
                voice: .carlos,
                showConversationHistory: true
            )
            .previewDisplayName("With DynamoDB History")
        }
    }
}
