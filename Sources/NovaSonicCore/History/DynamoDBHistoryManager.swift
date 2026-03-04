//
//  DynamoDBHistoryManager.swift
//  NovaSonicCore
//
//  Built-in DynamoDB implementation of NovaSonicHistoryManager protocol
//  Provides zero-configuration chat persistence for Nova Sonic conversations
//

import Foundation
import AWSDynamoDB
import AWSSDKIdentity
import SmithyIdentity

/// Built-in DynamoDB implementation of the NovaSonicHistoryManager protocol
/// Provides zero-configuration setup for chat persistence
public struct DynamoDBHistoryManager: NovaSonicHistoryManager {
    private let dynamoDBManager: DynamoDBManager
    
    /// Initialize with DynamoDB table name, region, user ID, and optional credentials
    /// - Parameters:
    ///   - region: AWS region for DynamoDB (defaults to us-east-1)
    ///   - tableName: Name of the DynamoDB table to use for storage
    ///   - userId: User ID for conversation isolation (defaults to "default-user" for backward compatibility)
    ///   - credentialsProvider: Optional AWS credentials provider (uses default if not provided)
    public init(
        region: String = "us-east-1", 
        tableName: String = "nova_sonic_chat_history", 
        userId: String = "default-user",
        credentialsProvider: (any SmithyIdentity.AWSCredentialIdentityResolver)? = nil
    ) async throws {
        self.dynamoDBManager = try await DynamoDBManager(
            region: region, 
            tableName: tableName, 
            userId: userId,
            credentialsProvider: credentialsProvider
        )
    }
    
    /// Save a message to DynamoDB
    public func saveMessage(conversationId: String, content: String, role: String, messageType: String) async throws {
        try await dynamoDBManager.saveMessage(
            conversationId: conversationId,
            type: role.lowercased(),
            content: content,
            messageType: messageType
        )
    }
    
    /// Load all messages for a conversation from DynamoDB
    public func loadConversation(conversationId: String) async throws -> [ChatMessage] {
        let items = try await dynamoDBManager.queryMessages(conversationId: conversationId)
        
        var messagesWithTimestamps: [(ChatMessage, Double)] = []
        
        for item in items {
            if let message = ChatMessage.fromDynamoItem(item),
               let timestamp = extractTimestamp(from: item) {
                messagesWithTimestamps.append((message, timestamp))
            }
        }
        
        // Sort by timestamp to ensure chronological order (oldest first)
        messagesWithTimestamps.sort { $0.1 < $1.1 }
        
        let sortedMessages = messagesWithTimestamps.map { $0.0 }
        
        // Validate that first message is from user (as required by Nova Sonic)
        if let firstMessage = sortedMessages.first, !firstMessage.isUser {
            NovaSonicLogger.minimal("Warning: First message in conversation history is not from user")
            NovaSonicLogger.minimal("This may cause Nova Sonic validation errors")
        }
        
        NovaSonicLogger.verbose("Loaded \(sortedMessages.count) messages in chronological order")
        if let first = sortedMessages.first {
            NovaSonicLogger.verbose("First message: \(first.isUser ? "USER" : "ASSISTANT") - \(first.text.prefix(50))...")
        }
        if let last = sortedMessages.last {
            NovaSonicLogger.verbose("Last message: \(last.isUser ? "USER" : "ASSISTANT") - \(last.text.prefix(50))...")
        }
        
        return sortedMessages
    }
    
    /// List all conversations with summary information
    public func listConversations() async throws -> [ConversationSummary] {
        let items = try await dynamoDBManager.listConversations()
        
        return items.compactMap { item in
            guard let conversationId = extractConversationId(from: item),
                  let content = extractContent(from: item),
                  let timestamp = extractTimestamp(from: item) else {
                return nil
            }
            
            return ConversationSummary(
                id: conversationId,
                lastMessage: content,
                timestamp: Date(timeIntervalSince1970: timestamp)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Extract conversation ID from DynamoDB item
    private func extractConversationId(from item: [String: DynamoDBClientTypes.AttributeValue]) -> String? {
        if case let .s(conversationId) = item["conversationId"] {
            return conversationId
        }
        return nil
    }
    
    /// Extract content from DynamoDB item
    private func extractContent(from item: [String: DynamoDBClientTypes.AttributeValue]) -> String? {
        if case let .s(content) = item["content"] {
            return content
        }
        return nil
    }
    
    /// Extract timestamp from DynamoDB item
    private func extractTimestamp(from item: [String: DynamoDBClientTypes.AttributeValue]) -> Double? {
        if case let .n(timestampString) = item["timestamp"] {
            return Double(timestampString)
        }
        return nil
    }
}

// MARK: - ChatMessage Extensions

/// Extension to convert DynamoDB items to ChatMessage objects
extension ChatMessage {
    /// Create a ChatMessage from a DynamoDB item
    /// - Parameter item: DynamoDB item dictionary
    /// - Returns: ChatMessage object or nil if conversion fails
    static func fromDynamoItem(_ item: [String: DynamoDBClientTypes.AttributeValue]) -> ChatMessage? {
        guard let contentAttr = item["content"],
              case let .s(content) = contentAttr,
              let typeAttr = item["type"],
              case let .s(type) = typeAttr else {
            return nil
        }
        
        let isUser = (type == "user")
        
        // Extract message type
        let messageTypeString: String
        if let messageTypeAttr = item["messageType"],
           case let .s(messageType) = messageTypeAttr {
            messageTypeString = messageType
        } else {
            messageTypeString = "normal"
        }
        
        // Convert to ChatMessage.MessageType
        let messageType: ChatMessage.MessageType
        switch messageTypeString {
        case "tool":
            messageType = .tool
        case "system":
            messageType = .system
        default:
            messageType = isUser ? .user : .assistant
        }
        
        return ChatMessage(
            text: content,
            isUser: isUser,
            messageType: messageType
        )
    }
}
