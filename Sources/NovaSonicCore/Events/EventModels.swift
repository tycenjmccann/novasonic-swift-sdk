import Foundation

// MARK: - Response Event Models

/// Represents different types of events received from Nova Sonic
public enum NovaResponseEvent {
    case completionStart(CompletionStartEvent)
    case contentStart(ContentStartResponse)
    case textOutput(TextOutputResponse)
    case audioOutput(AudioOutputResponse)
    case toolUse(ToolUseResponse)
    case contentEnd(ContentEndResponse)
    case completionEnd(CompletionEndEvent)
    case error(ErrorResponse)
}

// MARK: - Event Response Models

public struct CompletionStartEvent: Codable {
    public let sessionId: String
    public let promptName: String
    public let completionId: String
}

public struct ContentStartResponse: Codable {
    public let sessionId: String
    public let promptName: String
    public let completionId: String
    public let contentId: String
    public let type: String
    public let role: String?
    public let additionalModelFields: String?
    
    public var generationStage: GenerationStage? {
        guard let fields = additionalModelFields,
              let data = fields.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stage = json["generationStage"] as? String else {
            return nil
        }
        return GenerationStage(rawValue: stage)
    }
}

public struct TextOutputResponse: Codable {
    public let sessionId: String
    public let promptName: String
    public let completionId: String
    public let contentId: String
    public let content: String
    public let role: String?
}

public struct AudioOutputResponse: Codable {
    public let sessionId: String
    public let promptName: String
    public let completionId: String
    public let contentId: String
    public let content: String // Base64 encoded audio
    
    public var audioData: Data? {
        return Data(base64Encoded: content)
    }
}

public struct ToolUseResponse: Codable {
    public let sessionId: String
    public let promptName: String
    public let completionId: String
    public let contentId: String
    public let content: String // JSON string
    public let toolName: String
    public let toolUseId: String
    
    public var parameters: [String: Any]? {
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}

public struct ContentEndResponse: Codable {
    public let sessionId: String
    public let promptName: String
    public let completionId: String
    public let contentId: String
    public let stopReason: String
    public let type: String
}

public struct CompletionEndEvent: Codable {
    public let sessionId: String
    public let promptName: String
    public let completionId: String
    public let stopReason: String
}

public struct ErrorResponse: Codable {
    public let message: String
    public let code: String?
    public let type: String?
}

// MARK: - Supporting Enums

public enum GenerationStage: String, Codable {
    case speculative = "SPECULATIVE"
    case final = "FINAL"
}

public enum StopReason: String, Codable {
    case partialTurn = "PARTIAL_TURN"
    case endTurn = "END_TURN"
    case interrupted = "INTERRUPTED"
    case toolUse = "TOOL_USE"
}

// MARK: - Event Parser

public struct EventParser {
    
    /// Parses a raw JSON string into a NovaResponseEvent
    public static func parse(_ jsonString: String) -> NovaResponseEvent? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? [String: Any] else {
            return nil
        }
        
        // Parse different event types
        if let completionStart = event["completionStart"] as? [String: Any] {
            return parseCompletionStart(completionStart)
        } else if let contentStart = event["contentStart"] as? [String: Any] {
            return parseContentStart(contentStart)
        } else if let textOutput = event["textOutput"] as? [String: Any] {
            return parseTextOutput(textOutput)
        } else if let audioOutput = event["audioOutput"] as? [String: Any] {
            return parseAudioOutput(audioOutput)
        } else if let toolUse = event["toolUse"] as? [String: Any] {
            return parseToolUse(toolUse)
        } else if let contentEnd = event["contentEnd"] as? [String: Any] {
            return parseContentEnd(contentEnd)
        } else if let completionEnd = event["completionEnd"] as? [String: Any] {
            return parseCompletionEnd(completionEnd)
        } else if let error = event["error"] as? [String: Any] {
            return parseError(error)
        }
        
        return nil
    }
    
    // MARK: - Private Parsing Methods
    
    private static func parseCompletionStart(_ data: [String: Any]) -> NovaResponseEvent? {
        guard let sessionId = data["sessionId"] as? String,
              let promptName = data["promptName"] as? String,
              let completionId = data["completionId"] as? String else {
            return nil
        }
        
        let event = CompletionStartEvent(
            sessionId: sessionId,
            promptName: promptName,
            completionId: completionId
        )
        return .completionStart(event)
    }
    
    private static func parseContentStart(_ data: [String: Any]) -> NovaResponseEvent? {
        guard let sessionId = data["sessionId"] as? String,
              let promptName = data["promptName"] as? String,
              let completionId = data["completionId"] as? String,
              let contentId = data["contentId"] as? String,
              let type = data["type"] as? String else {
            return nil
        }
        
        let event = ContentStartResponse(
            sessionId: sessionId,
            promptName: promptName,
            completionId: completionId,
            contentId: contentId,
            type: type,
            role: data["role"] as? String,
            additionalModelFields: data["additionalModelFields"] as? String
        )
        return .contentStart(event)
    }
    
    private static func parseTextOutput(_ data: [String: Any]) -> NovaResponseEvent? {
        guard let sessionId = data["sessionId"] as? String,
              let promptName = data["promptName"] as? String,
              let completionId = data["completionId"] as? String,
              let contentId = data["contentId"] as? String,
              let content = data["content"] as? String else {
            return nil
        }
        
        let event = TextOutputResponse(
            sessionId: sessionId,
            promptName: promptName,
            completionId: completionId,
            contentId: contentId,
            content: content,
            role: data["role"] as? String
        )
        return .textOutput(event)
    }
    
    private static func parseAudioOutput(_ data: [String: Any]) -> NovaResponseEvent? {
        guard let sessionId = data["sessionId"] as? String,
              let promptName = data["promptName"] as? String,
              let completionId = data["completionId"] as? String,
              let contentId = data["contentId"] as? String,
              let content = data["content"] as? String else {
            return nil
        }
        
        let event = AudioOutputResponse(
            sessionId: sessionId,
            promptName: promptName,
            completionId: completionId,
            contentId: contentId,
            content: content
        )
        return .audioOutput(event)
    }
    
    private static func parseToolUse(_ data: [String: Any]) -> NovaResponseEvent? {
        guard let sessionId = data["sessionId"] as? String,
              let promptName = data["promptName"] as? String,
              let completionId = data["completionId"] as? String,
              let contentId = data["contentId"] as? String,
              let content = data["content"] as? String,
              let toolName = data["toolName"] as? String,
              let toolUseId = data["toolUseId"] as? String else {
            return nil
        }
        
        let event = ToolUseResponse(
            sessionId: sessionId,
            promptName: promptName,
            completionId: completionId,
            contentId: contentId,
            content: content,
            toolName: toolName,
            toolUseId: toolUseId
        )
        return .toolUse(event)
    }
    
    private static func parseContentEnd(_ data: [String: Any]) -> NovaResponseEvent? {
        guard let sessionId = data["sessionId"] as? String,
              let promptName = data["promptName"] as? String,
              let completionId = data["completionId"] as? String,
              let contentId = data["contentId"] as? String,
              let stopReason = data["stopReason"] as? String,
              let type = data["type"] as? String else {
            return nil
        }
        
        let event = ContentEndResponse(
            sessionId: sessionId,
            promptName: promptName,
            completionId: completionId,
            contentId: contentId,
            stopReason: stopReason,
            type: type
        )
        return .contentEnd(event)
    }
    
    private static func parseCompletionEnd(_ data: [String: Any]) -> NovaResponseEvent? {
        guard let sessionId = data["sessionId"] as? String,
              let promptName = data["promptName"] as? String,
              let completionId = data["completionId"] as? String,
              let stopReason = data["stopReason"] as? String else {
            return nil
        }
        
        let event = CompletionEndEvent(
            sessionId: sessionId,
            promptName: promptName,
            completionId: completionId,
            stopReason: stopReason
        )
        return .completionEnd(event)
    }
    
    private static func parseError(_ data: [String: Any]) -> NovaResponseEvent? {
        guard let message = data["message"] as? String else {
            return nil
        }
        
        let event = ErrorResponse(
            message: message,
            code: data["code"] as? String,
            type: data["type"] as? String
        )
        return .error(event)
    }
}
