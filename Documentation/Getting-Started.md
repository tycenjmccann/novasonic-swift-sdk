# Getting Started

Step-by-step guide to integrate Nova Sonic into your iOS app.

## Prerequisites

- iOS 16.0+ and Xcode 14.0+
- AWS Account with Bedrock access
- Nova Sonic model access in `us-east-1` region

## Step 1: Installation

Add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/your-org/NovaSonicPackage.git", from: "1.0.0")
]
```

## Step 2: AWS Setup

### Environment Variables (Development)
```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_REGION=us-east-1
```

### Cross-Region with Amplify (Production)
```swift
// For apps using Amplify in other regions
NovaSonicFloatingButton(
    streamManager: streamManager,
    voice: .tiffany,
    dynamoDBRegion: "us-east-1",
    awsCredentialIdentityResolver: yourAmplifyCredentials
)
```

## Step 3: Basic Integration

### Option A: Floating Button (Recommended)
```swift
import SwiftUI
import NovaSonicCore
import NovaSonicUI

struct ContentView: View {
    @StateObject private var streamManager = NovaSonicStreamManager()
    
    var body: some View {
        ZStack {
            YourExistingApp()
            
            NovaSonicFloatingButton(
                streamManager: streamManager,
                voice: .tiffany,
                systemPrompt: "You are a helpful assistant.",
                position: .bottomRight
            )
        }
    }
}
```

### Option B: Full Chat Interface
```swift
struct ContentView: View {
    @StateObject private var streamManager = NovaSonicStreamManager()
    
    var body: some View {
        NovaSonicChatView(
            streamManager: streamManager,
            voice: .matthew,
            systemPrompt: "You are a helpful assistant."
        )
    }
}
```

## Step 4: Add Chat Persistence (Optional)

```swift
NovaSonicFloatingButton(
    streamManager: streamManager,
    voice: .tiffany,
    enableDynamoDBHistory: true,
    dynamoDBTableName: "my_chat_history",
    dynamoDBUserId: "current_user_id"
)
```

## Step 5: Test Your Integration

1. **Build and run** your app
2. **Grant microphone permission** when prompted
3. **Tap the voice button** to start conversation
4. **Speak naturally** - Nova Sonic will respond with voice

## Common Issues

### Microphone Permission
```swift
// Handle permission in your app
import AVFoundation

AVAudioSession.sharedInstance().requestRecordPermission { granted in
    if !granted {
        // Show permission dialog
    }
}
```

### Network Connectivity
```swift
// Handle network errors
do {
    try await streamManager.startSession()
} catch NovaSonicError.networkConnectionFailed {
    // Show network error message
}
```

### AWS Credentials
- Ensure credentials have Bedrock permissions
- Verify Nova Sonic model access in us-east-1
- Check IAM policies for required actions

## Next Steps

- Add custom tools for your app's functionality
- Configure voice and audio quality settings
- Implement conversation history
- Test with different network conditions
