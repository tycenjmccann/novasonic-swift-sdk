//
//  ConversationListView.swift
//  NovaSonicUI
//
//  SwiftUI component for displaying and managing conversation history
//

import SwiftUI
import NovaSonicCore

/// A view that displays a list of conversations with the ability to resume them
public struct ConversationListView: View {
    @ObservedObject private var streamManager: NovaSonicStreamManager
    @State private var conversations: [ConversationSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    /// Initialize the conversation list view
    /// - Parameter streamManager: The stream manager to use for loading conversations
    public init(streamManager: NovaSonicStreamManager) {
        self.streamManager = streamManager
    }
    
    public var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading conversations...")
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                } else if conversations.isEmpty {
                    VStack {
                        Image(systemName: "message")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No conversations yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Start a voice conversation to see it here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(conversations) { conversation in
                        ConversationRowView(
                            conversation: conversation,
                            onTap: {
                                loadConversation(conversation.id)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Conversations")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .onAppear {
            loadConversations()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadConversations() {
        isLoading = true
        
        Task {
            do {
                // Get the history manager from the stream manager's configuration
                guard let historyManager = streamManager.getCurrentHistoryManager() else {
                    await MainActor.run {
                        isLoading = false
                        conversations = []
                        NovaSonicLogger.minimal("No history manager available in ConversationListView")
                    }
                    return
                }
                
                let loadedConversations = try await historyManager.listConversations()
                
                await MainActor.run {
                    isLoading = false
                    conversations = loadedConversations
                    NovaSonicLogger.verbose("Loaded \(loadedConversations.count) conversations in UI")
                    
                    // Format conversation dates for display
                    for (index, conversation) in loadedConversations.prefix(3).enumerated() {
                        NovaSonicLogger.verbose("Conversation \(index + 1):")
                        NovaSonicLogger.verbose("   Relative Date: \(conversation.relativeDate)")
                        NovaSonicLogger.verbose("   Formatted Time: \(conversation.formattedTime)")
                        NovaSonicLogger.verbose("   Timestamp: \(conversation.timestamp)")
                    }
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    conversations = []
                    errorMessage = "Failed to load conversations: \(error.localizedDescription)"
                    NovaSonicLogger.error("Failed to load conversations in UI: \(error)")
                }
            }
        }
    }
    
    private func loadConversation(_ conversationId: String) {
        Task {
            do {
                try await streamManager.loadConversationHistory(conversationId)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load conversation: \(error.localizedDescription)"
                }
            }
        }
    }
}

/// A row view for displaying individual conversation summaries
private struct ConversationRowView: View {
    let conversation: ConversationSummary
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date display (e.g., "Tuesday, July 1st" or "Today")
            Text(conversation.relativeDate)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Time display (e.g., "4:37 PM")
            Text(conversation.formattedTime)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Optional: Show a preview of the conversation for context
            if !conversation.lastMessage.isEmpty {
                Text(conversation.lastMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview

struct ConversationListView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample conversations with different dates for preview
        let now = Date()
        let calendar = Calendar.current
        
        let sampleConversations = [
            ConversationSummary(
                id: "1",
                lastMessage: "What's the weather like today?",
                timestamp: now // Today
            ),
            ConversationSummary(
                id: "2", 
                lastMessage: "Change my heart to blue",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now) ?? now // Yesterday
            ),
            ConversationSummary(
                id: "3",
                lastMessage: "Tell me about Nova Sonic",
                timestamp: calendar.date(byAdding: .day, value: -3, to: now) ?? now // This week
            ),
            ConversationSummary(
                id: "4",
                lastMessage: "Help me with meal planning",
                timestamp: calendar.date(byAdding: .day, value: -8, to: now) ?? now // Last week
            ),
            ConversationSummary(
                id: "5",
                lastMessage: "Planning a vacation to Europe",
                timestamp: calendar.date(byAdding: .month, value: -1, to: now) ?? now // Last month
            ),
            ConversationSummary(
                id: "6",
                lastMessage: "New Year's resolutions discussion",
                timestamp: calendar.date(byAdding: .year, value: -1, to: now) ?? now // Last year
            )
        ]
        
        NavigationView {
            List(sampleConversations) { conversation in
                ConversationRowView(conversation: conversation) {
                    NovaSonicLogger.verbose("Tapped conversation: \(conversation.id)")
                }
            }
            .navigationTitle("Conversations")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .previewDisplayName("Date Format Examples")
    }
}
