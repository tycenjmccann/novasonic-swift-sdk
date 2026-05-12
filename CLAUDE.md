# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the package
swift build

# Build for release
swift build -c release

# Run tests (no tests exist yet)
swift test

# Build a specific target
swift build --target NovaSonicCore
swift build --target NovaSonicUI
```

The package requires Swift 5.7+, iOS 16+ or macOS 12+, and Xcode 14+. Swift is not available in the CI environment for this repository — all builds must be done in Xcode or on a machine with the Swift toolchain.

## Architecture Overview

This is a Swift Package with two library targets:

- **`NovaSonicCore`** — All business logic: streaming, audio, tools, history, configuration, events
- **`NovaSonicUI`** — SwiftUI views (`NovaSonicFloatingButton`, `NovaSonicChatView`, `ConversationListView`) that depend on Core

### Central Coordinator: `NovaSonicStreamManager`

`NovaSonicStreamManager` (`Sources/NovaSonicCore/Streaming/NovaSonicStreamManager.swift`) is the main entry point. It is `@MainActor` and `ObservableObject`. Host apps create one instance with `@StateObject` and pass it to the UI components. It manages:

- The AWS Bedrock bidirectional stream (`InvokeModelWithBidirectionalStream`)
- Audio recording/playback lifecycle via `NovaSonicAudioManager`
- Speculative vs. final text message tracking
- Tool dispatch and result routing back to the stream
- History persistence delegation

**Configuration is separate from initialization**: after creating `NovaSonicStreamManager()`, call `.configure(with: NovaSonicConfiguration(...))` before `startSession()`. The UI components call `configure` internally based on their init parameters.

### Event Lifecycle

The Bedrock stream is driven by a JSON event protocol. `BedrockEvents` (`Sources/NovaSonicCore/Events/BedrockEvents.swift`) is a static factory for all outgoing JSON payloads. The mandatory initialization sequence is:

1. `sessionStart` — model parameters (temperature, topP, maxTokens, endpointingSensitivity)
2. `promptStart` — voice selection, audio output config, tool definitions
3. `systemTextContentStart` + `textInput` + `contentEnd` — system prompt
4. *(optional)* paralinguistic detection block — **exact content is Nova 2.0 spec; do not modify**
5. *(optional)* history turns (for `ConversationMode.resume`) — one triplet per prior turn
6. *(optional)* initial text prompt block — for `speakFirst` via text
7. `audioContentStart` — begins the live audio stream
8. Continuous `audioInput` chunks — base64-encoded LPCM audio from the microphone
9. `audioContentEnd` + `promptEnd` + `sessionEnd` — teardown

Incoming events are parsed in `handleEvent(_:)` as raw JSON dictionaries (not the `EventModels.swift` Codable types — those exist for documentation but are not used in the main response path).

### Speculative Text Pattern

Nova Sonic sends `SPECULATIVE` text immediately, then replaces each segment with `FINAL` text. `NovaSonicStreamManager` tracks speculative message IDs in insertion order (`speculativeMessageIds`) and a `finalMessageCount` index. When a FINAL text arrives, it replaces the Nth speculative message by ID lookup. Speculative messages are **not** persisted to history; only FINAL messages are saved.

### Tool System

Tools follow a static protocol pattern:

1. Implement `NovaSonicTool` (static `name`, `description`, `schema`, `handle(_:completion:)`)
2. Register via `NovaSonicToolRegistry.shared.register(MyTool.self)` or via the `tools:` param on UI components
3. Tool specs are injected into `promptStartEvent` automatically at session start
4. When Bedrock sends a `toolUse` event, the registry executes the tool and `sendToolResultBack` sends a `contentStart` (type TOOL) + `textInput` + `contentEnd` triplet back into the stream

Tools must be registered **before** the session starts, since they are serialized into the `promptStart` event.

### History / Persistence

History uses a protocol (`NovaSonicHistoryManager`) so hosts can plug in any backend. The built-in implementation is `DynamoDBHistoryManager`. Conversation resume works by loading prior messages as `(content, role)` pairs and passing them as `ConversationMode.resume(previousTurns)` to `startStreaming(mode:)`, which injects them as history events before audio begins.

### Audio (iOS only)

Audio code is conditionally compiled under `#if IOS_AUDIO` (defined only for iOS/tvOS/watchOS targets). On macOS the audio subsystem is absent. The audio stack is:

- `SharedAudioEngine` — singleton `AVAudioEngine`, reset between sessions via `resetAudioState()`
- `AudioInputStream` — taps the input node, captures LPCM chunks, calls back into `NovaSonicStreamManager` to send `audioInput` events
- `AudioOutputStream` — schedules decoded LPCM buffers for playback; `flush()` is called on barge-in detection
- `AudioStreamHolder` — actor that owns the input/output stream references
- `NovaSonicAudioManager` — coordinates the above; `cleanup()` must be called between sessions to reset engine state

Barge-in is detected when the `textOutput` content contains `{ "interrupted" : true }`. This triggers `audioManager.flushAudio()` to clear the playback queue immediately.

### `speakFirst` Feature

When `speakFirst: true`, either:
- A `hello.wav` file is loaded from the app bundle and sent as the first `audioInput` event (legacy), or
- `initialTextPrompt` from config is injected as a text turn before the audio stream begins (preferred Nova 2.0 approach)

The host app must include `hello.wav` in its bundle for the audio fallback path.

### Key Conventions

- **AWS region**: Nova Sonic only supports `us-east-1`, `us-west-2`, `ap-northeast-1`. Validated in `NovaSonicConfiguration.validate()`.
- **`@MainActor` threading**: `NovaSonicStreamManager` is `@MainActor`. The private `updateIsStreaming`, `updateConnectionStatus`, `addMessage`, `updateError` helpers handle off-main-thread dispatching safely.
- **No umbrella imports**: `Package.swift` imports only specific AWS products (`AWSBedrockRuntime`, `AWSSDKIdentity`, `AWSBedrockAgentRuntime`, `AWSDynamoDB`), not the full `AWSSDK` umbrella.
- **AWS SDK minimum version**: `from: "1.2.59"` — using a range is required for a distributed library (an `exact:` pin causes SPM resolution failures for any consumer that uses the AWS SDK elsewhere). If the bidirectional streaming API breaks in a newer SDK release, bump the lower bound after verifying compatibility.
- **Conversation IDs**: If no `currentConversationId` is set, `promptName` (a UUID generated at init) is used as the conversation ID for persistence.
- **Log levels**: `NovaSonicLogLevel` has `.off`, `.minimal`, `.standard` (default), `.verbose`. Set in `NovaSonicConfiguration(logLevel:)`. Use `NovaSonicLogger.verbose()` for debug-only output.
