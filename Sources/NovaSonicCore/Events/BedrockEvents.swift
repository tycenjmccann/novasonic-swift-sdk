//
//  BedrockEvents.swift
//  NovaSonic Package
//
//  Event builders for Amazon Bedrock Nova Sonic streaming
//
import Foundation

public struct BedrockEvents {
    //MARK: - Initialization Events
    // SessionStart
        public static func sessionStartEvent(temperature: Double = 0.7, topP: Double = 0.9, maxTokens: Int = 1024, endpointingSensitivity: String? = nil) -> String {
        return SessionStartEvent(maxTokens: maxTokens, topP: topP, temperature: temperature, endpointingSensitivity: endpointingSensitivity).buildEvent()
    }
    
    // PromptStart -- With Tools
    public static func promptStartEvent(promptName: String, voiceId: String, outputSampleRate: Int = 24000) -> String {
        
        // Get tool specifications from the registry
        let toolSpecs = NovaSonicToolRegistry.shared.getToolSpecs()
        
        // Convert tool specs to the format expected by Nova Sonic
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
                        "encoding": "base64",
                        "audioType": "SPEECH"
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

        // Convert final event to JSON string
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }

    // For conversation history text input
    public static func historyTextInputEvent(promptName: String, contentName: String, content: String, role: String) -> String {
        let event: [String: Any] = [
            "event": [
                "textInput": [
                    "promptName": promptName,
                    "contentName": contentName,
                    "content": content,
                    "role": role  // Include role here
                ]
            ]
        ]
        
        // Convert final event to JSON string
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }
    
    // For conversation history
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
        
        // Convert final event to JSON string
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }
    
    // For system prompt
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
        
        // Convert final event to JSON string
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }
    
    //TextInput - prompt for the model behavior
    public static func textInputEvent(promptName: String, contentName: String) -> String {
        """
        {
            "event": {
                "textInput": {
                    "promptName": "\(promptName)",
                    "contentName": "\(contentName)",
                    "content": "You are Nova Sonic, a helpful voice assistant. You can answer questions, provide information, and have natural conversations. Keep your responses concise and conversational. You have access to tools that you can use when appropriate. When a user asks for information that might benefit from using a tool, consider using the available tools to provide more accurate and helpful responses.",
                    "role":"SYSTEM"
                }
            }
        }
        """
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
        
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }
    
    public static func paralinguisticTextInputEvent(promptName: String, contentName: String) -> String {
        // IMPORTANT: Do not modify this content - it must be exactly as specified by Nova 2.0
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
        
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }

    //ContentEnd
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
    
    //MARK: - Audio Streaming Events
    //AudioContentStart
    public static func audioContentStartEvent(promptName: String, audioContentName: String, inputSampleRate: Int = 16000) -> String {
        """
        {
            "event": {
                "contentStart": {
                    "promptName": "\(promptName)",
                    "contentName": "\(audioContentName)",
                    "type": "AUDIO",
                    "interactive": true,
                    "role": "USER",
                    "audioInputConfiguration": {
                        "mediaType": "audio/lpcm",
                        "sampleRateHertz": \(inputSampleRate),
                        "sampleSizeBits": 16,
                        "channelCount": 1,
                        "audioType": "SPEECH",
                        "encoding": "base64"
                    }
                }
            }
        }
        """
    }
    
    //AudioInput Chunks
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
    
    //Audio End Event
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
    
    //MARK: - Tool Events
    
    //Tool Content Start
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
    
    //Tool Result
    public static func makeToolResult(_ promptName: String, _ contentName: String, _ jsonString: String) -> String {
        // Properly escape the JSON string to avoid parsing issues
        let escapedJson = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        NovaSonicLogger.verbose("Original JSON string: \(jsonString)")
        NovaSonicLogger.verbose("Escaped JSON string: \(escapedJson)")
        
        return """
        {
            "event": {
                "textInput": {
                    "promptName": "\(promptName)",
                    "contentName": "\(contentName)",
                    "content": "\(escapedJson)"
                }
            }
        }
        """
    }
    
    //Tool End
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

    //MARK: - Session Closing Events
    
    //Close Out Prompt
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
    
    //Close Out Session
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
