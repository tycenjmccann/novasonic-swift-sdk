//
//  BedrockEvents.swift
//  NovaSonic Package
//
//  Event builders for Amazon Bedrock Nova Sonic streaming
//
import Foundation

public struct BedrockEvents {

    // MARK: - Private JSON Helper

    /// Safely serializes a Foundation object to a JSON string.
    /// Uses assertionFailure in debug builds to surface programming errors early,
    /// and returns a no-op empty object in production rather than crashing.
    private static func encodeJSON(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            assertionFailure("NovaSonic: Failed to serialize JSON event — this is a programming error")
            return "{}"
        }
        return string
    }

    // MARK: - Initialization Events

    public static func sessionStartEvent(temperature: Double = 0.7, topP: Double = 0.9, maxTokens: Int = 1024, endpointingSensitivity: String? = nil) -> String {
        return SessionStartEvent(maxTokens: maxTokens, topP: topP, temperature: temperature, endpointingSensitivity: endpointingSensitivity).buildEvent()
    }

    public static func promptStartEvent(promptName: String, voiceId: String, outputSampleRate: Int = 24000, outputTransport: AudioTransportMode = .json) -> String {
        let toolSpecs = NovaSonicToolRegistry.shared.getToolSpecs()

        let toolsArray = toolSpecs.map { spec in
            [
                "toolSpec": [
                    "name": spec.name,
                    "description": spec.description,
                    "inputSchema": [
                        "json": spec.schema
                    ]
                ]
            ]
        }

        let encoding: String = outputTransport == .json ? "base64" : "raw"

        let event: [String: Any] = [
            "event": [
                "promptStart": [
                    "promptName": promptName,
                    "textOutputConfiguration": [
                        "mediaType": "text/plain"
                    ],
                    "audioOutputConfiguration": [
                        "mediaType": "audio/lpcm",
                        "sampleRateHertz": outputSampleRate,
                        "sampleSizeBits": 16,
                        "channelCount": 1,
                        "voiceId": voiceId,
                        "encoding": encoding,
                        "audioType": "SPEECH",
                        "transport": outputTransport.rawValue
                    ],
                    "toolUseOutputConfiguration": [
                        "mediaType": "application/json"
                    ],
                    "toolConfiguration": [
                        "toolChoice": [
                            "auto": [:]
                        ],
                        "tools": toolsArray
                    ]
                ]
            ]
        ]

        return encodeJSON(event)
    }

    public static func historyTextInputEvent(promptName: String, contentName: String, content: String, role: String) -> String {
        let event: [String: Any] = [
            "event": [
                "textInput": [
                    "promptName": promptName,
                    "contentName": contentName,
                    "content": content,
                    "role": role
                ]
            ]
        ]
        return encodeJSON(event)
    }

    public static func textContentStartEvent(promptName: String, contentName: String, role: String = "USER") -> String {
        let event: [String: Any] = [
            "event": [
                "contentStart": [
                    "promptName": promptName,
                    "contentName": contentName,
                    "role": role.uppercased(),
                    "type": "TEXT",
                    "interactive": true,
                    "textInputConfiguration": [
                        "mediaType": "text/plain"
                    ]
                ]
            ]
        ]
        return encodeJSON(event)
    }

    public static func systemTextContentStartEvent(promptName: String, contentName: String) -> String {
        let event: [String: Any] = [
            "event": [
                "contentStart": [
                    "promptName": promptName,
                    "contentName": contentName,
                    "type": "TEXT",
                    "interactive": true,
                    "role": "SYSTEM",
                    "textInputConfiguration": [
                        "mediaType": "text/plain"
                    ]
                ]
            ]
        ]
        return encodeJSON(event)
    }

    /// System prompt content. `content` defaults to the generic assistant prompt so
    /// existing callers are unchanged; pass configuration.systemPrompt to use the app's
    /// own prompt — otherwise the caller's persona/guardrails are silently dropped.
    public static func textInputEvent(promptName: String, contentName: String, content: String? = nil) -> String {
        let systemPrompt = content ?? "You are Nova Sonic, a helpful voice assistant. You can answer questions, provide information, and have natural conversations. Keep your responses concise and conversational. You have access to tools that you can use when appropriate. When a user asks for information that might benefit from using a tool, consider using the available tools to provide more accurate and helpful responses."
        let event: [String: Any] = [
            "event": [
                "textInput": [
                    "promptName": promptName,
                    "contentName": contentName,
                    "content": systemPrompt,
                    "role": "SYSTEM"
                ]
            ]
        ]
        return encodeJSON(event)
    }

    // MARK: - Paralinguistic Detection (Nova 2.0)

    public static func paralinguisticContentStartEvent(promptName: String, contentName: String) -> String {
        let event: [String: Any] = [
            "event": [
                "contentStart": [
                    "promptName": promptName,
                    "contentName": contentName,
                    "type": "TEXT",
                    "interactive": false,
                    "role": "SYSTEM_SPEECH",
                    "textInputConfiguration": [
                        "mediaType": "text/plain"
                    ]
                ]
            ]
        ]
        return encodeJSON(event)
    }

    public static func paralinguisticTextInputEvent(promptName: String, contentName: String) -> String {
        // IMPORTANT: Do not modify this content — exact Nova 2.0 spec requirement.
        let content = "Convert streaming speech to text, call an external model for text responses, emit turn taking events, and convert the text to speech. The transcription and response should be in spoken form with no capitalization and punctuations. Add per turn user emotion to the output."

        let event: [String: Any] = [
            "event": [
                "textInput": [
                    "promptName": promptName,
                    "contentName": contentName,
                    "content": content
                ]
            ]
        ]
        return encodeJSON(event)
    }

    public static func contentEndEvent(promptName: String, contentName: String) -> String {
        """
        {
            "event": {
                "contentEnd": {
                    "promptName": "\(promptName)",
                    "contentName": "\(contentName)"
                }
            }
        }
        """
    }

    // MARK: - Audio Streaming Events

    public static func audioContentStartEvent(promptName: String, audioContentName: String, inputSampleRate: Int = 16000, inputTransport: AudioTransportMode = .json) -> String {
        let encoding: String = inputTransport == .json ? "base64" : "raw"

        let event: [String: Any] = [
            "event": [
                "contentStart": [
                    "promptName": promptName,
                    "contentName": audioContentName,
                    "type": "AUDIO",
                    "interactive": true,
                    "role": "USER",
                    "audioInputConfiguration": [
                        "mediaType": "audio/lpcm",
                        "sampleRateHertz": inputSampleRate,
                        "sampleSizeBits": 16,
                        "channelCount": 1,
                        "audioType": "SPEECH",
                        "encoding": encoding,
                        "transport": inputTransport.rawValue
                    ]
                ]
            ]
        ]

        return encodeJSON(event)
    }

    public static func audioInputEvent(audioData: Data, promptName: String, audioContentName: String) -> String {
        let base64Audio = audioData.base64EncodedString()
        return """
        {
            "event": {
                "audioInput": {
                    "promptName": "\(promptName)",
                    "contentName": "\(audioContentName)",
                    "content": "\(base64Audio)"
                }
            }
        }
        """
    }

    /// Returns raw audio Data for binary transport mode (no JSON wrapping)
    public static func binaryAudioInputData(audioData: Data) -> Data {
        return audioData
    }

    public static func audioContentEndEvent(promptName: String, audioContentName: String) -> String {
        """
        {
            "event": {
                "contentEnd": {
                    "promptName": "\(promptName)",
                    "contentName": "\(audioContentName)"
                }
            }
        }
        """
    }

    // MARK: - Tool Events

    public static func makeContentStart(_ promptName: String, _ contentName: String, _ toolUseId: String) -> String {
        return """
        {
            "event": {
                "contentStart": {
                    "promptName": "\(promptName)",
                    "contentName": "\(contentName)",
                    "type": "TOOL",
                    "role": "TOOL",
                    "toolResultInputConfiguration": {
                        "toolUseId": "\(toolUseId)",
                        "type": "TEXT",
                        "textInputConfiguration": {
                            "mediaType": "text/plain"
                        }
                    }
                }
            }
        }
        """
    }

    public static func makeToolResult(_ promptName: String, _ contentName: String, _ jsonString: String) -> String {
        let event: [String: Any] = [
            "event": [
                "textInput": [
                    "promptName": promptName,
                    "contentName": contentName,
                    "content": jsonString
                ]
            ]
        ]
        return encodeJSON(event)
    }

    public static func makeContentEnd(_ promptName: String, _ contentName: String) -> String {
        return """
        {
            "event": {
                "contentEnd": {
                    "promptName": "\(promptName)",
                    "contentName": "\(contentName)"
                }
            }
        }
        """
    }

    // MARK: - Session Update Events (Nova 2.0)

    /// Build a `session.update` event from explicit parameters.
    public static func sessionUpdateEvent(replace: [String: String]? = nil, languageHint: String? = nil, keyterms: [String]? = nil) -> String {
        return SessionUpdateEvent(replace: replace, languageHint: languageHint, keyterms: keyterms).buildEvent()
    }

    /// Build a `session.update` event from a `NovaSonicConfiguration`.
    public static func sessionUpdateEvent(configuration: NovaSonicConfiguration) -> String {
        return SessionUpdateEvent(replace: configuration.replace, languageHint: configuration.languageHint, keyterms: configuration.keyterms).buildEvent()
    }

    // MARK: - Session Closing Events

    public static func promptEndEvent(promptName: String) -> String {
        """
        {
            "event": {
                "promptEnd": {
                    "promptName": "\(promptName)"
                }
            }
        }
        """
    }

    public static func sessionEndEvent() -> String {
        """
        {
            "event": {
                "sessionEnd": {}
            }
        }
        """
    }
}
