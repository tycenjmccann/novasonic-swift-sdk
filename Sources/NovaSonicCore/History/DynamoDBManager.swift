//
//  DynamoDBManager.swift
//  NovaSonicCore
//
//  Internal DynamoDB operations for Nova Sonic chat history
//  Handles low-level DynamoDB interactions for the built-in history manager
//

import Foundation
import AWSDynamoDB
import AWSSDKIdentity
import SmithyIdentity
import ClientRuntime

/// Internal manager for DynamoDB operations related to chat history
/// Used by DynamoDBHistoryManager to handle low-level database operations
internal class DynamoDBManager {
    private let client: DynamoDBClient
    private let tableName: String
    private let userId: String
    
    /// Initialize the DynamoDB manager with region, table name, user ID, and optional credentials
    /// - Parameters:
    ///   - region: AWS region for DynamoDB operations
    ///   - tableName: Name of the DynamoDB table for chat storage
    ///   - userId: User ID for conversation isolation (defaults to "default-user" for backward compatibility)
    ///   - credentialsProvider: Optional AWS credentials provider (uses default if not provided)
    internal init(
        region: String = "us-east-1", 
        tableName: String = "nova_sonic_chat_history", 
        userId: String = "default-user",
        credentialsProvider: (any SmithyIdentity.AWSCredentialIdentityResolver)? = nil
    ) async throws {
        // Create DynamoDB client configuration with credentials if provided
        let config: DynamoDBClient.DynamoDBClientConfiguration
        if let credentialsProvider = credentialsProvider {
            config = try await DynamoDBClient.DynamoDBClientConfiguration(
                awsCredentialIdentityResolver: credentialsProvider,
                region: region
            )
            NovaSonicLogger.minimal("DynamoDBManager using provided credentials")
        } else {
            config = try await DynamoDBClient.DynamoDBClientConfiguration(region: region)
            NovaSonicLogger.minimal("DynamoDBManager using default credential resolution")
        }
        
        self.client = DynamoDBClient(config: config)
        self.tableName = tableName
        self.userId = userId
        
        NovaSonicLogger.standard("DynamoDBManager initialized with userId: \(userId)")
    }
    
    /// Save a message to DynamoDB
    /// - Parameters:
    ///   - conversationId: Unique identifier for the conversation
    ///   - type: Message type ("user" or "assistant")
    ///   - content: The message content
    ///   - messageType: Type of message ("normal", "tool", "system")
    ///   - timestamp: Unix timestamp for the message
    internal func saveMessage(
        conversationId: String,
        type: String,
        content: String,
        messageType: String = "normal",
        timestamp: Double = Date().timeIntervalSince1970
    ) async throws {
        // Create sort key as conversationId#timestamp
        let sortKey = "\(conversationId)#\(timestamp)"
        
        // Create item with attributes
        let item: [String: DynamoDBClientTypes.AttributeValue] = [
            "userId": .s(userId),
            "sortKey": .s(sortKey),
            "conversationId": .s(conversationId),
            "timestamp": .n(String(timestamp)),
            "type": .s(type),
            "content": .s(content),
            "messageType": .s(messageType)
        ]
        
        // Create put item input
        let input = PutItemInput(
            item: item,
            tableName: tableName
        )
        
        // Execute put item operation
        _ = try await client.putItem(input: input)
    }
    
    /// Query messages for a specific conversation
    /// - Parameter conversationId: The conversation ID to query
    /// - Returns: Array of DynamoDB items for the conversation
    internal func queryMessages(conversationId: String) async throws -> [[String: DynamoDBClientTypes.AttributeValue]] {
        // Create expression attribute values
        let expressionAttributeValues: [String: DynamoDBClientTypes.AttributeValue] = [
            ":userId": .s(userId),
            ":prefix": .s("\(conversationId)#")
        ]
        
        // Create key condition expression
        let keyConditionExpression = "userId = :userId AND begins_with(sortKey, :prefix)"
        
        // Create query input
        let input = QueryInput(
            expressionAttributeValues: expressionAttributeValues,
            keyConditionExpression: keyConditionExpression,
            tableName: tableName
        )
        
        // Execute query operation
        let response = try await client.query(input: input)
        
        // Return items or empty array
        return response.items ?? []
    }
    
    /// List all conversations for the user.
    ///
    /// ⚠️ Performance note: this queries the full user partition and de-duplicates in memory.
    /// For production workloads with large conversation histories, add a GSI on
    /// (userId, conversationId) and store one summary row per conversation rather than
    /// scanning all message rows. The Limit below caps reads to the 500 most-recent rows.
    internal func listConversations() async throws -> [[String : DynamoDBClientTypes.AttributeValue]] {
        let input = QueryInput(
            expressionAttributeValues: [":userId": .s(userId)],
            keyConditionExpression: "userId = :userId",
            limit: 500,
            scanIndexForward: false,
            tableName: tableName
        )
        let items = try await client.query(input: input).items ?? []

        // Keep only the newest row per conversationId
        var latest: [String : (ts: Double, row: [String : DynamoDBClientTypes.AttributeValue])] = [:]

        for row in items {
            guard
                case let .s(sortKey)? = row["sortKey"],
                let convoId = sortKey.split(separator: "#").first.map(String.init),
                case let .n(tsStr)? = row["timestamp"],
                let ts = Double(tsStr)
            else { continue }

            if let existing = latest[convoId] {
                if ts > existing.ts { latest[convoId] = (ts, row) }
            } else {
                latest[convoId] = (ts, row)
            }
        }

        // Sort newest‑first and return
        func ts(_ row: [String : DynamoDBClientTypes.AttributeValue]) -> Double {
            if case let .n(s)? = row["timestamp"], let d = Double(s) { return d }
            return 0
        }

        return latest.values.map(\.row).sorted { ts($0) > ts($1) }
    }
    
    /// Format a date for display in the conversation list
    /// - Parameter timestamp: Unix timestamp to format
    /// - Returns: Formatted date string (e.g., "Mon, May 4th, 5:30PM")
    internal static func formatDate(timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d'th', h:mm a"
        return formatter.string(from: date)
    }
}
