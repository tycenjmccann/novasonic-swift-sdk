# Error Handling

NovaSonic uses the `NovaSonicError` enum for all errors. Each case carries a `localizedDescription` and a `recoverySuggestion`. Most errors also expose `isRetryable` so you can decide whether to show a retry button.

## Catching Errors

```swift
do {
    try await streamManager.startSession()
} catch NovaSonicError.audioPermissionDenied {
    // Show microphone permission prompt
} catch NovaSonicError.authenticationFailed {
    // Prompt the user to re-authenticate / check AWS credentials
} catch NovaSonicError.networkConnectionFailed {
    // Show offline banner, retry when reachable
} catch NovaSonicError.invalidConfiguration {
    // Check region, temperature, topP, maxTokens values
} catch {
    print("Unexpected error: \(error.localizedDescription)")
}
```

## Handling Errors via Delegate

```swift
class MyDelegate: NovaSonicStreamDelegate {
    func didEncounterError(_ error: NovaSonicError) {
        if error.isRetryable {
            // schedule a retry
        } else {
            // surface the error to the user
            showAlert(message: error.localizedDescription,
                      suggestion: error.recoverySuggestion)
        }
    }
}

streamManager.delegate = MyDelegate()
```

## Observing `lastError` in SwiftUI

```swift
struct ContentView: View {
    @StateObject private var streamManager = NovaSonicStreamManager()

    var body: some View {
        VStack {
            NovaSonicChatView(streamManager: streamManager, voice: .tiffany)

            if let error = streamManager.lastError {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
            }
        }
    }
}
```

## Error Reference

| Case | Retryable | Typical Cause |
|------|-----------|---------------|
| `.audioPermissionDenied` | No | User denied microphone access |
| `.authenticationFailed` | No | Invalid/expired AWS credentials |
| `.invalidConfiguration` | No | Out-of-range model params or unsupported region |
| `.microphoneNotAvailable` | No | Device has no microphone |
| `.networkConnectionFailed` | Yes | No internet / VPN issue |
| `.serviceUnavailable` | Yes | Bedrock service outage |
| `.rateLimitExceeded` | Yes | Too many concurrent requests |
| `.sessionTimeout` | Yes | Idle session expired |
| `.streamingError(_)` | Yes | Generic bidirectional stream failure |
| `.audioSessionError(_)` | Yes | AVAudioSession configuration issue |
