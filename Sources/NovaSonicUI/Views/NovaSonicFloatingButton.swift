//
//  NovaSonicFloatingButton.swift
//  NovaSonic Package
//
//  Simple floating button for voice interactions
//

import SwiftUI
import NovaSonicCore
import SmithyIdentity

/// Position options for the floating button
public enum NovaSonicFloatingPosition {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

/// Simple floating button for Nova Sonic voice interactions
public struct NovaSonicFloatingButton: View {
    
    // MARK: - Properties
    
    /// Stream manager for handling Nova Sonic interactions
    @ObservedObject public var streamManager: NovaSonicStreamManager
    
    // Direct configuration properties
    public let voice: NovaSonicVoice
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
    
    /// Position of the floating button
    public let position: NovaSonicFloatingPosition
    
    /// Optional callback for state changes
    public let onStateChange: ((Bool) -> Void)?
    
    /// Whether Nova Sonic should speak first (send initial audio prompt)
    public let speakFirst: Bool
    
    // MARK: - State
    
    @State private var glowScale: CGFloat = 0.0
    @State private var loadingRotation: Double = 0.0
    
    // MARK: - Initialization
    
    public init(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
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
        position: NovaSonicFloatingPosition = .bottomRight,
        speakFirst: Bool = false,
        onStateChange: ((Bool) -> Void)? = nil
    ) {
        self.streamManager = streamManager
        self.voice = voice
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
        self.position = position
        self.speakFirst = speakFirst
        self.onStateChange = onStateChange
    }
    
    // MARK: - Convenience Initializers
    
    /// Creative configuration with higher temperature and topP
    public static func creative(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        position: NovaSonicFloatingPosition = .bottomRight,
        speakFirst: Bool = false,
        onStateChange: ((Bool) -> Void)? = nil
    ) -> NovaSonicFloatingButton {
        return NovaSonicFloatingButton(
            streamManager: streamManager,
            voice: voice,
            temperature: 0.9,
            topP: 0.95,
            systemPrompt: systemPrompt,
            tools: tools,
            position: position,
            speakFirst: speakFirst,
            onStateChange: onStateChange
        )
    }
    
    /// Maximum quality configuration with 24kHz audio
    public static func maxQuality(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        position: NovaSonicFloatingPosition = .bottomRight,
        speakFirst: Bool = false,
        onStateChange: ((Bool) -> Void)? = nil
    ) -> NovaSonicFloatingButton {
        return NovaSonicFloatingButton(
            streamManager: streamManager,
            voice: voice,
            systemPrompt: systemPrompt,
            inputSampleRate: NovaSonicSampleRate.rate24kHz,
            outputSampleRate: NovaSonicSampleRate.rate24kHz,
            tools: tools,
            position: position,
            speakFirst: speakFirst,
            onStateChange: onStateChange
        )
    }
    
    /// Low bandwidth configuration with 8kHz audio
    public static func lowBandwidth(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        position: NovaSonicFloatingPosition = .bottomRight,
        speakFirst: Bool = false,
        onStateChange: ((Bool) -> Void)? = nil
    ) -> NovaSonicFloatingButton {
        return NovaSonicFloatingButton(
            streamManager: streamManager,
            voice: voice,
            systemPrompt: systemPrompt,
            inputSampleRate: NovaSonicSampleRate.rate8kHz,
            outputSampleRate: NovaSonicSampleRate.rate8kHz,
            tools: tools,
            position: position,
            speakFirst: speakFirst,
            onStateChange: onStateChange
        )
    }
    
    /// Focused configuration with lower temperature for more precise responses
    public static func focused(
        streamManager: NovaSonicStreamManager,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant.",
        tools: [NovaSonicTool.Type] = [],
        position: NovaSonicFloatingPosition = .bottomRight,
        speakFirst: Bool = false,
        onStateChange: ((Bool) -> Void)? = nil
    ) -> NovaSonicFloatingButton {
        return NovaSonicFloatingButton(
            streamManager: streamManager,
            voice: voice,
            temperature: 0.3,
            topP: 0.7,
            systemPrompt: systemPrompt,
            tools: tools,
            position: position,
            speakFirst: speakFirst,
            onStateChange: onStateChange
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
        position: NovaSonicFloatingPosition = .bottomRight,
        speakFirst: Bool = false,
        onStateChange: ((Bool) -> Void)? = nil
    ) -> NovaSonicFloatingButton {
        return NovaSonicFloatingButton(
            streamManager: streamManager,
            voice: voice,
            systemPrompt: systemPrompt,
            enableDynamoDBHistory: true,
            dynamoDBTableName: tableName,
            dynamoDBUserId: userId,
            tools: tools,
            position: position,
            speakFirst: speakFirst,
            onStateChange: onStateChange
        )
    }
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Glow circle (only visible when connected and streaming)
                if streamManager.connectionStatus == .connected && streamManager.isStreaming && glowScale > 0 {
                    Circle()
                        .fill(Color.green.opacity(0.7))
                        .frame(width: 75, height: 75)
                        .scaleEffect(glowScale)
                }
                
                // Main button circle with state-based colors
                Circle()
                    .fill(buttonColor)
                    .frame(width: 60, height: 60)
                
                // Button content based on connection state
                buttonContent
            }
            .frame(width: 75, height: 75)
            .background(Color.clear)
            .contentShape(Circle())
            .onTapGesture {
                NovaSonicLogger.standard("Floating button tapped - connectionStatus: \(streamManager.connectionStatus), isStreaming: \(streamManager.isStreaming)")
                handleButtonTap()
            }
            .onAppear {
                setupNovaSonic()
                updateAnimations()
            }
            .onDisappear {
                // Critical: Stop streaming to prevent crashes when navigating away
                if streamManager.isStreaming {
                    NovaSonicLogger.standard("🚨 FloatingButton: View disappearing during active session - stopping stream")
                    Task {
                        await streamManager.stopStreaming()
                    }
                }
            }
            .onChange(of: streamManager.connectionStatus) { _ in
                updateAnimations()
            }
            .onChange(of: streamManager.isStreaming) { isStreaming in
                // Notify callback of state change
                onStateChange?(isStreaming)
                updateAnimations()
            }
            .position(buttonPosition(in: geometry))
        }
        .ignoresSafeArea()
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
                .font(.system(size: 24))
                .foregroundColor(.white)
                
        case .connecting:
            // Loading spinner
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 24, height: 24)
                .rotationEffect(Angle(degrees: loadingRotation))
                
        case .connected:
            Image(systemName: streamManager.isStreaming ? "waveform" : "message.badge.waveform")
                .font(.system(size: 24))
                .foregroundColor(.white)
                
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Private Methods
    
    /// Calculate button position based on configuration
    private func buttonPosition(in geometry: GeometryProxy) -> CGPoint {
        let padding: CGFloat = 50 // Distance from edges
        let size = geometry.size
        
        switch position {
        case .topLeft:
            return CGPoint(x: padding, y: padding)
        case .topRight:
            return CGPoint(x: size.width - padding, y: padding)
        case .bottomLeft:
            return CGPoint(x: padding, y: size.height - padding)
        case .bottomRight:
            return CGPoint(x: size.width - padding, y: size.height - padding)
        }
    }
    
    /// Handle button tap
    private func handleButtonTap() {
        Task {
            if streamManager.isStreaming {
                await streamManager.stopStreaming()
            } else {
                // Start new conversation
                streamManager.startNewConversation()
                await streamManager.startStreaming(mode: .newConversation)
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
    
    /// Start the glow animation for the button
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
    
    /// Set up Nova Sonic configuration and tools
    private func setupNovaSonic() {
        // Only configure if not already configured (to avoid overriding existing setup)
        if !streamManager.isConfigured {
            NovaSonicLogger.standard("NovaSonicFloatingButton: Configuring stream manager")
            
            // Create configuration from individual parameters
            let configuration = NovaSonicConfiguration(
                region: dynamoDBRegion,
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
            NovaSonicLogger.verbose("NovaSonicFloatingButton: Stream manager already configured, skipping")
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

struct NovaSonicFloatingButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1)
                .ignoresSafeArea()
            
            VStack {
                Text("Floating Button Positions")
                    .font(.title2)
                    .padding()
                
                Spacer()
            }
            
            // Top Left
            NovaSonicFloatingButton(
                streamManager: NovaSonicStreamManager(),
                voice: NovaSonicVoice.tiffany,
                systemPrompt: "You are a helpful assistant.",
                position: NovaSonicFloatingPosition.topLeft,
                onStateChange: { isStreaming in
                    NovaSonicLogger.verbose("Top Left - Streaming: \(isStreaming)")
                }
            )
            
            // Top Right
            NovaSonicFloatingButton(
                streamManager: NovaSonicStreamManager(),
                voice: NovaSonicVoice.matthew,
                systemPrompt: "You are a helpful assistant.",
                position: .topRight,
                onStateChange: { isStreaming in
                    NovaSonicLogger.verbose("Top Right - Streaming: \(isStreaming)")
                }
            )
            
            // Bottom Left
            NovaSonicFloatingButton(
                streamManager: NovaSonicStreamManager(),
                voice: .amy,
                systemPrompt: "You are a helpful assistant.",
                position: .bottomLeft
            )
            
            // Bottom Right (default)
            NovaSonicFloatingButton(
                streamManager: NovaSonicStreamManager(),
                voice: .carlos,
                systemPrompt: "You are a helpful assistant.",
                position: .bottomRight
            )
            
            // Creative configuration
            NovaSonicFloatingButton.creative(
                streamManager: NovaSonicStreamManager(),
                voice: .lupe,
                position: .bottomRight
            )
        }
        .previewDisplayName("All Positions")
    }
}
