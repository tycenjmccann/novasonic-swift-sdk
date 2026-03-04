import Foundation

// MARK: - Event Builder Protocol

public protocol EventBuilder {
    static func buildEvent() -> String
}

// MARK: - Session Events

public struct SessionStartEvent: EventBuilder {
    public let maxTokens: Int
    public let topP: Double
    public let temperature: Double
    public let endpointingSensitivity: String?  // Nova 2.0
    
    public init(maxTokens: Int = 1024, topP: Double = 0.9, temperature: Double = 0.7, endpointingSensitivity: String? = nil) {
        self.maxTokens = maxTokens
        self.topP = topP
        self.temperature = temperature
        self.endpointingSensitivity = endpointingSensitivity
    }
    
    public static func buildEvent() -> String {
        SessionStartEvent().buildEvent()
    }
    
    public func buildEvent() -> String {
        var json = """
        {
            "event": {
                "sessionStart": {
                    "inferenceConfiguration": {
                        "maxTokens": \(maxTokens),
                        "topP": \(topP),
                        "temperature": \(temperature)
                    }
        """
        
        // Add turn detection configuration if provided (Nova 2.0)
        if let sensitivity = endpointingSensitivity {
            json += """
            ,
                    "turnDetectionConfiguration": {
                        "endpointingSensitivity": "\(sensitivity)"
                    }
            """
        }
        
        json += """
        
                }
            }
        }
        """
        
        return json
    }
}

public struct SessionEndEvent: EventBuilder {
    public static func buildEvent() -> String {
        """
        {
            "event": {
                "sessionEnd": {}
            }
        }
        """
    }
}

// MARK: - Prompt Events

public struct PromptStartEvent: EventBuilder {
    public let promptName: String
    public let voiceId: String
    public let tools: [NovaSonicToolSpec]
    public let outputSampleRate: Int
    
    public init(promptName: String, voiceId: String, tools: [NovaSonicToolSpec] = [], outputSampleRate: Int = 24000) {
        self.promptName = promptName
        self.voiceId = voiceId
        self.tools = tools
        self.outputSampleRate = outputSampleRate
    }
    
    public static func buildEvent() -> String {
        PromptStartEvent(promptName: "", voiceId: "tiffany").buildEvent()
    }
    
    public func buildEvent() -> String {
        let toolSpecs = tools.map { tool in
            [
                "toolSpec": [
                    "name": tool.name,
                    "description": tool.description,
                    "inputSchema": [
                        "json": tool.schema
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
                        "tools": toolSpecs
                    ]
                ]
            ]
        ]
        
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }
}

public struct PromptEndEvent: EventBuilder {
    public let promptName: String
    
    public init(promptName: String) {
        self.promptName = promptName
    }
    
    public static func buildEvent() -> String {
        PromptEndEvent(promptName: "").buildEvent()
    }
    
    public func buildEvent() -> String {
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
}

// MARK: - Content Events

public struct ContentStartEvent: EventBuilder {
    public let promptName: String
    public let contentName: String
    public let contentType: ContentType
    public let role: ContentRole?
    public let interactive: Bool
    public let inputSampleRate: Int?
    
    public init(promptName: String, contentName: String, contentType: ContentType, role: ContentRole? = nil, interactive: Bool = false, inputSampleRate: Int? = nil) {
        self.promptName = promptName
        self.contentName = contentName
        self.contentType = contentType
        self.role = role
        self.interactive = interactive
        self.inputSampleRate = inputSampleRate
    }
    
    public enum ContentType: String {
        case text = "TEXT"
        case audio = "AUDIO"
        case tool = "TOOL"
    }
    
    public enum ContentRole: String {
        case system = "SYSTEM"
        case user = "USER"
        case assistant = "ASSISTANT"
        case tool = "TOOL"
    }
    
    public init(promptName: String, contentName: String, contentType: ContentType, role: ContentRole? = nil, interactive: Bool = true) {
        self.promptName = promptName
        self.contentName = contentName
        self.contentType = contentType
        self.role = role
        self.interactive = interactive
        self.inputSampleRate = nil
    }
    
    public static func buildEvent() -> String {
        ContentStartEvent(promptName: "", contentName: "", contentType: .text).buildEvent()
    }
    
    public func buildEvent() -> String {
        var contentStart: [String: Any] = [
            "promptName": promptName,
            "contentName": contentName,
            "type": contentType.rawValue,
            "interactive": interactive
        ]
        
        if let role = role {
            contentStart["role"] = role.rawValue
        }
        
        switch contentType {
        case .text:
            contentStart["textInputConfiguration"] = [
                "mediaType": "text/plain"
            ]
        case .audio:
            contentStart["audioInputConfiguration"] = [
                "mediaType": "audio/lpcm",
                "sampleRateHertz": inputSampleRate ?? 16000,
                "sampleSizeBits": 16,
                "channelCount": 1,
                "audioType": "SPEECH",
                "encoding": "base64"
            ]
        case .tool:
            // Tool configuration will be added separately
            break
        }
        
        let event: [String: Any] = [
            "event": [
                "contentStart": contentStart
            ]
        ]
        
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }
}

public struct ContentEndEvent: EventBuilder {
    public let promptName: String
    public let contentName: String
    
    public init(promptName: String, contentName: String) {
        self.promptName = promptName
        self.contentName = contentName
    }
    
    public static func buildEvent() -> String {
        ContentEndEvent(promptName: "", contentName: "").buildEvent()
    }
    
    public func buildEvent() -> String {
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
}

// MARK: - Input Events

public struct TextInputEvent: EventBuilder {
    public let promptName: String
    public let contentName: String
    public let content: String
    public let role: String?
    
    public init(promptName: String, contentName: String, content: String, role: String? = nil) {
        self.promptName = promptName
        self.contentName = contentName
        self.content = content
        self.role = role
    }
    
    public static func buildEvent() -> String {
        TextInputEvent(promptName: "", contentName: "", content: "").buildEvent()
    }
    
    public func buildEvent() -> String {
        var textInput: [String: Any] = [
            "promptName": promptName,
            "contentName": contentName,
            "content": content
        ]
        
        if let role = role {
            textInput["role"] = role
        }
        
        let event: [String: Any] = [
            "event": [
                "textInput": textInput
            ]
        ]
        
        let eventData = try! JSONSerialization.data(withJSONObject: event, options: [])
        return String(data: eventData, encoding: .utf8)!
    }
}

public struct AudioInputEvent: EventBuilder {
    public let promptName: String
    public let contentName: String
    public let audioData: Data
    
    public init(promptName: String, contentName: String, audioData: Data) {
        self.promptName = promptName
        self.contentName = contentName
        self.audioData = audioData
    }
    
    public static func buildEvent() -> String {
        AudioInputEvent(promptName: "", contentName: "", audioData: Data()).buildEvent()
    }
    
    public func buildEvent() -> String {
        let base64Audio = audioData.base64EncodedString()
        return """
        {
            "event": {
                "audioInput": {
                    "promptName": "\(promptName)",
                    "contentName": "\(contentName)",
                    "content": "\(base64Audio)"
                }
            }
        }
        """
    }
}

// MARK: - Tool Events

public struct ToolContentStartEvent: EventBuilder {
    public let promptName: String
    public let contentName: String
    public let toolUseId: String
    
    public init(promptName: String, contentName: String, toolUseId: String) {
        self.promptName = promptName
        self.contentName = contentName
        self.toolUseId = toolUseId
    }
    
    public static func buildEvent() -> String {
        ToolContentStartEvent(promptName: "", contentName: "", toolUseId: "").buildEvent()
    }
    
    public func buildEvent() -> String {
        """
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
}

public struct ToolResultEvent: EventBuilder {
    public let promptName: String
    public let contentName: String
    public let result: String
    
    public init(promptName: String, contentName: String, result: String) {
        self.promptName = promptName
        self.contentName = contentName
        self.result = result
    }
    
    public static func buildEvent() -> String {
        ToolResultEvent(promptName: "", contentName: "", result: "").buildEvent()
    }
    
    public func buildEvent() -> String {
        // Properly escape the JSON string to avoid parsing issues
        let escapedResult = result
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        return """
        {
            "event": {
                "textInput": {
                    "promptName": "\(promptName)",
                    "contentName": "\(contentName)",
                    "content": "\(escapedResult)"
                }
            }
        }
        """
    }
}

// MARK: - Supporting Types

public struct NovaSonicToolSpec {
    public let name: String
    public let description: String
    public let schema: String
    
    public init(name: String, description: String, schema: String) {
        self.name = name
        self.description = description
        self.schema = schema
    }
}
