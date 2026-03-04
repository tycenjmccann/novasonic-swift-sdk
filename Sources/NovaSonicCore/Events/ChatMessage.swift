import Foundation

/// Represents a chat message in Nova Sonic conversations
public struct ChatMessage: Identifiable, Codable {
    public let id: String
    public var text: String  // Changed from 'let' to 'var' to allow updates
    public let isUser: Bool
    public let messageType: MessageType
    public let timestamp: Date
    
    public enum MessageType: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
        case tool = "tool"
        case transcription = "transcription"
        case speculative = "speculative"
    }
    
    public init(
        text: String,
        isUser: Bool,
        messageType: MessageType = .assistant,
        timestamp: Date = Date()
    ) {
        self.id = UUID().uuidString
        self.text = text
        self.isUser = isUser
        self.messageType = messageType
        self.timestamp = timestamp
    }
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        isUser: Bool,
        messageType: MessageType,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.messageType = messageType
        self.timestamp = timestamp
    }
}

extension ChatMessage: Equatable {
    public static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

extension ChatMessage: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
