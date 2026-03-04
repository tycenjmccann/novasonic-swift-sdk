import Foundation

/// Protocol for managing chat history and conversation persistence
/// 
/// This protocol allows host applications to implement their own storage backend
/// (DynamoDB, Core Data, SQLite, etc.) while the package provides the integration hooks.
/// Following the same optional and pluggable pattern as tools.
public protocol NovaSonicHistoryManager {
    /// Save a message to the conversation history
    /// - Parameters:
    ///   - conversationId: Unique identifier for the conversation
    ///   - content: The message content (text)
    ///   - role: The role of the message sender ("user", "assistant", "system", "tool")
    ///   - messageType: The type of message ("normal", "tool", "system")
    func saveMessage(conversationId: String, content: String, role: String, messageType: String) async throws
    
    /// Load all messages for a specific conversation
    /// - Parameter conversationId: Unique identifier for the conversation
    /// - Returns: Array of ChatMessage objects in chronological order
    func loadConversation(conversationId: String) async throws -> [ChatMessage]
    
    /// List all conversations with summary information
    /// - Returns: Array of ConversationSummary objects sorted by most recent
    func listConversations() async throws -> [ConversationSummary]
}
