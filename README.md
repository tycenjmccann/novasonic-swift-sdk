# NovaSonic Swift Package

A comprehensive Swift Package for real-time speech-to-speech conversations using Amazon Bedrock's Nova Sonic model with bidirectional streaming, tool integration, chat persistence, and configurable audio quality.

## Overview

NovaSonic Swift Package provides a clean, reusable interface for integrating Amazon Nova Sonic's speech-to-speech capabilities into iOS applications. The package handles all the complexity of bidirectional audio streaming, format conversion, session management, tool integration, and chat persistence while providing a simple API for host applications.

## Quick Start

### Installation

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/tycenjmccann/NovaSonicPackage.git", from: "1.3.0")
]
```

### Basic Setup

```swift
import SwiftUI
import NovaSonicCore
import NovaSonicUI

struct ContentView: View {
    @StateObject private var streamManager = NovaSonicStreamManager()
    
    var body: some View {
        NovaSonicFloatingButton(
            streamManager: streamManager,
            voice: .tiffany,
            systemPrompt: "You are a helpful assistant.",
            position: .bottomRight
        )
    }
}
```

## Two Integration Approaches

### Option 1: Floating Button (Recommended for Existing Apps)

Add voice capabilities to your existing app with just a floating button overlay:

```swift
struct ContentView: View {
    @StateObject private var streamManager = NovaSonicStreamManager()
    
    var body: some View {
        ZStack {
            // Your existing app content
            YourMainAppView()
            
            // Add floating voice button
            NovaSonicFloatingButton(
                streamManager: streamManager,
                voice: .tiffany,
                systemPrompt: "You are a helpful assistant.",
                enableDynamoDBHistory: true,
                dynamoDBTableName: "my_chat_history",
                position: .bottomRight
            )
        }
    }
}
```

### Option 2: Full Chat Interface

Complete chat experience with conversation history:

```swift
struct ContentView: View {
    @StateObject private var streamManager = NovaSonicStreamManager()
    
    var body: some View {
        NovaSonicChatView(
            streamManager: streamManager,
            voice: .matthew,
            temperature: 0.7,
            systemPrompt: "You are a helpful assistant.",
            tools: [MyCustomTool.self],
            showConversationHistory: true
        )
    }
}
```

## Configuration Options

### Voice Selection

```swift
// US English
.matthew    // Masculine, professional
.tiffany    // Feminine, warm (default)

// UK English  
.amy        // Feminine, British accent

// Spanish
.lupe       // Feminine
.carlos     // Masculine
```

### Audio Quality

```swift
// Maximum quality (24kHz input/output)
NovaSonicFloatingButton(
    streamManager: streamManager,
    voice: .tiffany,
    inputSampleRate: .rate24kHz,
    outputSampleRate: .rate24kHz
)

// Low bandwidth (8kHz input/output)
NovaSonicChatView(
    streamManager: streamManager,
    voice: .tiffany,
    inputSampleRate: .rate8kHz,
    outputSampleRate: .rate8kHz
)

// Preset configurations
NovaSonicFloatingButton.default(...)        // Balanced quality/performance
NovaSonicChatView.maxQuality(...)           // Best audio quality
NovaSonicFloatingButton.creative(...)       // Higher temperature/topP
NovaSonicChatView.focused(...)              // Lower temperature/topP
```

### Model Parameters

```swift
NovaSonicChatView(
    streamManager: streamManager,
    voice: .tiffany,
    temperature: 0.9,        // Creativity (0.1-1.0)
    topP: 0.95,              // Response diversity (0.5-1.0)
    maxTokens: 2048,         // Max response length (1-4096)
    systemPrompt: "You are a helpful cooking assistant."
)
```

## Chat Persistence

### One-Line DynamoDB Setup

```swift
NovaSonicFloatingButton(
    streamManager: streamManager,
    voice: .tiffany,
    enableDynamoDBHistory: true,
    dynamoDBTableName: "my_app_history",
    dynamoDBUserId: "user123"  // Required for multi-user apps
)
```

### Custom Storage Backend

```swift
struct MyHistoryManager: NovaSonicHistoryManager {
    func saveMessage(conversationId: String, content: String, role: String, messageType: String) async throws {
        // Save to Core Data, SQLite, Firebase, etc.
    }
    
    func loadConversation(conversationId: String) async throws -> [ChatMessage] {
        // Load from your storage
    }
    
    func listConversations() async throws -> [ConversationSummary] {
        // List conversations
    }
}

// Configure stream manager with custom history manager
streamManager.configure(with: NovaSonicConfiguration(
    historyManager: MyHistoryManager()
))
```

## Tool Integration

### Custom Tool Implementation

```swift
import NovaSonicCore

struct WeatherTool: NovaSonicTool {
    static let name = "getWeather"
    static let description = "Get current weather for a location"
    static let schema = """
    {
      "type": "object",
      "properties": {
        "location": {"type": "string", "description": "City name"}
      },
      "required": ["location"]
    }
    """
    
    static func handle(_ input: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        guard let location = input["location"] as? String else {
            completion(["error": "Missing location parameter"])
            return
        }
        
        // Your weather API logic here
        completion([
            "temperature": "72°F",
            "condition": "Sunny",
            "location": location
        ])
    }
}
```

### Tool Registration

```swift
// Register tools at app startup
let tools: [NovaSonicTool.Type] = [
    WeatherTool.self,
    CalendarTool.self,
    KnowledgeBaseTool.self
]

NovaSonicChatView(
    streamManager: streamManager,
    voice: .matthew,
    systemPrompt: "You are a helpful assistant.",
    tools: tools
)
```

## AWS Setup

### Prerequisites

- iOS 16.0+ and Xcode 14.0+
- AWS Account with Bedrock access
- Nova Sonic model access in `us-east-1` region

### Environment Variables

```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_REGION=us-east-1
```

### Cross-Region Authentication (Amplify)

For apps using Amplify in other regions:

```swift
NovaSonicFloatingButton(
    streamManager: streamManager,
    voice: .tiffany,
    dynamoDBRegion: "us-east-1",
    awsCredentialIdentityResolver: yourAmplifyCredentials
)
```

## UI Components

### NovaSonicFloatingButton

```swift
NovaSonicFloatingButton(
    streamManager: streamManager,
    voice: .tiffany,
    systemPrompt: "You are a helpful assistant.",
    position: .bottomRight,  // .topLeft, .topRight, .bottomLeft, .bottomRight
    onStateChange: { isStreaming in
        print("Voice interaction: \(isStreaming ? "Started" : "Stopped")")
    }
)
```

### NovaSonicChatView

```swift
NovaSonicChatView(
    streamManager: streamManager,
    voice: .matthew,
    systemPrompt: "You are a helpful assistant.",
    tools: [MyTool.self],
    showConversationHistory: true,
    speakFirst: false
)
```

### ConversationListView

```swift
ConversationListView(
    streamManager: streamManager,
    onConversationSelected: { conversation in
        // Resume conversation
    }
)
```

## Factory Methods

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

## Error Handling

```swift
do {
    try await streamManager.startSession()
} catch NovaSonicError.audioPermissionDenied {
    // Show microphone permission dialog
} catch NovaSonicError.networkConnectionFailed {
    // Show network error message
} catch {
    print("Error: \(error.localizedDescription)")
}
```

## Complete Configuration Example

```swift
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
    logLevel: .standard,            // Options: .verbose, .standard, .minimal, .none
    
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

## Features

### 🎙️ **Audio & Streaming**
- Real-time bidirectional audio streaming with Amazon Nova Sonic
- Configurable audio quality (8kHz, 16kHz, 24kHz)
- Automatic format conversion and session management
- Barge-in support for natural conversation interruptions

### 🔧 **Configuration & Voices**
- 5 voice options (Matthew, Tiffany, Amy, Lupe, Carlos)
- Model parameter control (Temperature, TopP, MaxTokens)
- Preset configurations for common use cases
- Performance testing framework

### 🛠️ **Tool Integration**
- Protocol-based tool system for custom business logic
- Simple tool registry with async execution
- Example tools for weather, knowledge base integration

### 💾 **Chat Persistence**
- Protocol-based history management for flexible storage
- One-line DynamoDB setup for production use
- Conversation resume and graceful degradation

### 🎨 **SwiftUI Components**
- Complete chat interface with history
- Streamlined floating button overlay
- Conversation list and voice selection components
- Real-time audio visualization

### 🔒 **Reliability**
- Comprehensive error handling with user-friendly messages
- Thread-safe operations and resource management
- Configuration validation and automatic reconnection

## Requirements

- iOS 16.0+
- Swift 5.7+
- Xcode 14.0+
- AWS Account with Bedrock Nova Sonic access

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the error handling examples above
2. Review the configuration options
3. Test with different sample rates for performance
4. Open an issue with detailed information about your use case

---

**Built for Amazon Nova Sonic** - Real-time speech-to-speech AI conversations with configurable quality, multiple voices, custom tool integration, and comprehensive chat persistence. 🎙️✨
