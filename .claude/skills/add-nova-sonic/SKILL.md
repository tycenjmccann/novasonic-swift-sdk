---
name: add-nova-sonic
description: Integrate the NovaSonic Swift SDK (Amazon Nova Sonic speech-to-speech) into an iOS/macOS app — add the package dependency, wire a NovaSonicFloatingButton or NovaSonicChatView, register a custom tool, and set the required microphone permission. Use when a user asks to add Nova Sonic voice, add a voice assistant, integrate the NovaSonic SDK, or scaffold a Nova Sonic tool.
---

# Add Nova Sonic to an app

Wire the NovaSonic Swift SDK into a host app. The runnable reference is
`Examples/PackageTester` in this repo — mirror it.

## 0. Decide the shape
Ask only if genuinely ambiguous; otherwise default:
- **Floating button** (overlay on an existing screen) → `NovaSonicFloatingButton`. Default.
- **Full chat screen** (presented sheet / pushed view) → `NovaSonicChatView`.
- **Custom tool?** If the assistant must *do* something in-app (change UI, call an API, read app state), scaffold a `NovaSonicTool`. See step 4.

## 1. Add the package dependency
If the host is a separate repo, add via SPM:
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/tycenjmccann/novasonic-swift-sdk.git", from: "1.3.0")
]
// target deps: "NovaSonicCore", "NovaSonicUI"
```
Xcode app project: File → Add Package Dependencies → the URL above → add **NovaSonicCore** and **NovaSonicUI** to the app target.

If integrating *inside this SDK repo's* example, reference the package locally
(`relativePath = ../..`) — that's how `Examples/PackageTester` is wired.

## 2. Microphone permission (required — voice won't work without it)
Set on the app target (Info.plist / build setting):
- `NSMicrophoneUsageDescription` = a human string, e.g. "Microphone for Voice Chat".
  (Build-setting form: `INFOPLIST_KEY_NSMicrophoneUsageDescription`.)
Nova Sonic is **iOS only** for audio (`#if IOS_AUDIO`); on macOS the audio subsystem is absent.

## 3. Add the SDK region + model reality
- Nova Sonic runs in **us-east-1 / us-west-2 / ap-northeast-1** only.
- Model is a locked enum `NovaSonicModel` (`.novaSonic1`, `.novaSonic2` = default, `.novaSonic25EA`).
  Pass `model:` only to override; **`.novaSonic25EA` requires `region == "us-east-1"`** or `validate()` throws.
  Leave `model` unset for production → ships `.novaSonic2`.

## 4. Scaffold a custom tool (if needed)
Implement `NovaSonicTool` — static `name`/`description`/`schema` + `handle(_:completion:)`.
Template (adapt name/schema/logic; UI side-effects go through a static callback):
```swift
import NovaSonicCore
import SwiftUI

public struct <ToolName>Tool: NovaSonicTool {
    public static let name = "<toolName>"          // camelCase, stable — model calls this
    public static let description = "<what it does, one line the model reads>"
    public static let schema = """
    {
      "type": "object",
      "properties": {
        "<param>": { "type": "string", "description": "<what to pass>" }
      },
      "required": ["<param>"]
    }
    """

    // UI side-effects flow through a callback the View sets in .onAppear
    public static var on<Event>: ((<Payload>) -> Void)?

    public static func handle(_ input: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        guard let value = input["<param>"] as? String, !value.isEmpty else {
            completion(errorResult(message: "<param> is required")); return
        }
        on<Event>?(/* map value */)
        completion(successResult(data: ["message": "done"]))
    }
}
```
Rules:
- Register the tool **before** the session starts — pass it in the `tools:` array on the View (it's serialized into `promptStart`). Do not register mid-session.
- `errorResult` / `successResult` are provided by the protocol.
- For UI mutation, hop to main: `DispatchQueue.main.async { … }` in the callback, and set the callback in the View's `.onAppear`.

## 5. Wire the View
Host owns exactly one `@StateObject NovaSonicStreamManager`; the View calls `.configure` from its init params.

**Floating button** (overlay — put it in a `ZStack` or at the root of a screen):
```swift
import SwiftUI
import NovaSonicCore
import NovaSonicUI

struct MyView: View {
    @StateObject private var streamManager = NovaSonicStreamManager()
    var body: some View {
        NovaSonicFloatingButton(
            streamManager: streamManager,
            voice: .tiffany,                 // .matthew .tiffany .amy .carlos .lupe
            temperature: 0.8, topP: 0.9, maxTokens: 1024,
            systemPrompt: "You are a helpful assistant.",
            inputSampleRate: .rate16kHz, outputSampleRate: .rate24kHz,
            endpointingSensitivity: .low,
            logLevel: .standard,
            tools: [MyTool.self],            // omit if no custom tool
            position: .bottomLeft,
            speakFirst: false,
            onStateChange: { isStreaming in /* react */ }
        )
        .onAppear { MyTool.onEvent = { /* update UI on main */ } }
    }
}
```

**Full chat view** (present as sheet):
```swift
NovaSonicChatView(
    streamManager: chatManager,
    voice: .lupe,
    systemPrompt: "You are a helpful assistant.",
    endpointingSensitivity: .low,
    initialTextPrompt: "Hey, I'm Tycen",
    tools: [MyTool.self],
    showConversationHistory: true,
    speakFirst: false
)
```

Optional DynamoDB history (both Views accept these): `enableDynamoDBHistory: true`,
`dynamoDBTableName:`, `dynamoDBUserId:`, `dynamoDBRegion: "us-east-1"`, and an
`awsCredentialIdentityResolver:` for cross-account/Cognito auth.

## 6. Verify
- `swift build` if it's a package; for an app target, build to a simulator.
- Launch, tap the mic button, confirm connect + first audio. If a tool was added, speak a phrase that triggers it and confirm the side-effect fires.
- Full runnable example to copy from: `Examples/PackageTester` (heart-color tool via `ChangeMyHeartTool`).

## Gotchas
- Tools must be registered before session start — they're baked into `promptStart`.
- `.novaSonic25EA` outside us-east-1 → `validate()` throws.
- No `NSMicrophoneUsageDescription` → the app crashes on mic access.
- macOS build: audio is compiled out (`#if IOS_AUDIO`); the SDK still links.
