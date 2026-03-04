# API Reference

Quick reference for key APIs in the NovaSonic Swift Package.

## NovaSonicUI Components

### NovaSonicFloatingButton

```swift
// Basic usage
NovaSonicFloatingButton(
    streamManager: streamManager,
    voice: .tiffany,
    systemPrompt: "You are a helpful assistant.",
    position: .bottomRight
)

// Full configuration with EXACT parameter order
NovaSonicFloatingButton(
    // Required
    streamManager: streamManager,
    
    // Voice & Content
    voice: .tiffany,                // Options: .matthew, .tiffany, .amy, .carlos, .lupe
    temperature: 0.7,               // Controls creativity (0.1-1.0)
    topP: 0.9,                      // Controls diversity (0.5-1.0)
    maxTokens: 1024,                // Max response length
    systemPrompt: "You are a helpful cooking assistant.",
    
    // Audio Quality
    inputSampleRate: .rate16kHz,    // Options: .rate8kHz, .rate16kHz, .rate24kHz
    outputSampleRate: .rate24kHz,   // Options: .rate8kHz, .rate16kHz, .rate24kHz
    
    // Chat Persistence
    enableDynamoDBHistory: true,
    dynamoDBTableName: "my_chat_history",
    dynamoDBUserId: "user123",
    dynamoDBRegion: "us-east-1",
    
    // Authentication
    awsCredentialIdentityResolver: myCredentialResolver,
    
    // Logging
    logLevel: .standard,            // Options: .verbose, .standard, .minimal, .off
    
    // Tool Integration
    tools: [MyCustomTool.self],     // Custom tools to register
    
    // UI Positioning
    position: .bottomRight,         // Options: .topLeft, .topRight, .bottomLeft, .bottomRight
    
    // Behavior
    speakFirst: false,              // Whether Nova Sonic speaks first
    
    // Event Handling
    onStateChange: { isStreaming in
        // Handle streaming state changes
    }
)
```

### NovaSonicChatView

```swift
// Basic usage
NovaSonicChatView(
    streamManager: streamManager,
    voice: .matthew,
    systemPrompt: "You are a helpful assistant."
)

// Full configuration with EXACT parameter order
NovaSonicChatView(
    // Required
    streamManager: streamManager,
    
    // Voice & Content
    voice: .matthew,
    temperature: 0.7,
    topP: 0.9,
    maxTokens: 1024,
    systemPrompt: "You are a helpful assistant.",
    
    // Audio Quality
    inputSampleRate: .rate16kHz,
    outputSampleRate: .rate24kHz,
    
    // Chat Persistence
    enableDynamoDBHistory: true,
    dynamoDBTableName: "my_chat_history",
    dynamoDBUserId: "user123",
    dynamoDBRegion: "us-east-1",
    
    // Authentication
    awsCredentialIdentityResolver: myCredentialResolver,
    
    // Logging
    logLevel: .standard,
    
    // Tool Integration
    tools: [MyTool.self],
    
    // UI Options
    showVoiceSelector: true,
    showConversationHistory: true,
    
    // Behavior
    speakFirst: false
)
```

### Factory Methods

```swift
// Creative configuration with higher temperature and topP
NovaSonicFloatingButton.creative(
    streamManager: streamManager,
    voice: .tiffany,
    systemPrompt: "You are a creative assistant."
)

// Maximum quality configuration with 24kHz audio
NovaSonicChatView.maxQuality(
    streamManager: streamManager,
    voice: .matthew
)

// Low bandwidth configuration with 8kHz audio
NovaSonicFloatingButton.lowBandwidth(
    streamManager: streamManager,
    voice: .amy
)

// Focused configuration with lower temperature for more precise responses
NovaSonicChatView.focused(
    streamManager: streamManager,
    voice: .carlos
)

// Simple DynamoDB history setup
NovaSonicFloatingButton.withDynamoDBHistory(
    streamManager: streamManager,
    userId: "user123",
    tableName: "nova_sonic_chat_history"
)
```

## NovaSonicVoice

Available voices:

| Voice | Language | Gender | Description |
|-------|----------|--------|-------------|
| `.matthew` | US English | Masculine | Clear, professional |
| `.tiffany` | US English | Feminine | Warm, friendly (default) |
| `.amy` | UK English | Feminine | British accent |
| `.lupe` | Spanish | Feminine | Spanish language |
| `.carlos` | Spanish | Masculine | Spanish language |

## NovaSonicStreamManager

Main streaming manager with published properties:

```swift
@Published var isStreaming: Bool
@Published var isConnected: Bool
@Published var currentError: NovaSonicError?
@Published var audioLevel: Float
```

Key methods:
```swift
func configure(with configuration: NovaSonicConfiguration, bedrockClient: BedrockRuntimeClient? = nil)
func startSession() async throws
func stopSession() async
func setSpeakFirst(_ speakFirst: Bool)  // Make AI speak first
```

## Tool Protocol

```swift
protocol NovaSonicTool {
    static var name: String { get }
    static var description: String { get }
    static var schema: String { get }
    static func handle(_ input: [String: Any], completion: @escaping ([String: Any]) -> Void)
}
```

## History Management

```swift
protocol NovaSonicHistoryManager {
    func saveMessage(conversationId: String, content: String, role: String, messageType: String) async throws
    func loadConversation(conversationId: String) async throws -> [ChatMessage]
    func listConversations() async throws -> [ConversationSummary]
}
```

## Error Types

```swift
enum NovaSonicError: Error {
    case audioPermissionDenied
    case networkConnectionFailed
    case configurationInvalid(String)
    case streamingFailed(String)
    case toolExecutionFailed(String)
}
```

## Sample Rates

| Rate | Value | Quality | Use Case |
|------|-------|---------|----------|
| `.rate8kHz` | 8000 | Basic | Poor network |
| `.rate16kHz` | 16000 | Standard | Default input |
| `.rate24kHz` | 24000 | High | Best output quality |
