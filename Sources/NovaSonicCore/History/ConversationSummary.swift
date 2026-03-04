import Foundation

/// Summary information for a conversation, used in conversation lists
public struct ConversationSummary {
    /// Unique identifier for the conversation
    public let id: String
    
    /// Preview of the last message in the conversation
    public let lastMessage: String
    
    /// Timestamp of the last message
    public let timestamp: Date
    
    /// Initialize a conversation summary
    /// - Parameters:
    ///   - id: Unique identifier for the conversation
    ///   - lastMessage: Preview of the last message
    ///   - timestamp: Timestamp of the last message
    public init(id: String, lastMessage: String, timestamp: Date) {
        self.id = id
        self.lastMessage = lastMessage
        self.timestamp = timestamp
    }
}

// MARK: - Identifiable conformance for SwiftUI
extension ConversationSummary: Identifiable {}

// MARK: - Equatable conformance
extension ConversationSummary: Equatable {
    public static func == (lhs: ConversationSummary, rhs: ConversationSummary) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable conformance
extension ConversationSummary: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Date Formatting Extensions
extension ConversationSummary {
    /// Formatted date for display (e.g., "Tuesday, July 1st")
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        formatter.timeZone = TimeZone.current
        
        let day = Calendar.current.component(.day, from: timestamp)
        let suffix = daySuffix(for: day)
        let baseString = formatter.string(from: timestamp)
        
        // Replace the day number with day + suffix
        return baseString.replacingOccurrences(of: " \(day)", with: " \(day)\(suffix)")
    }
    
    /// Formatted time for display (e.g., "4:37 PM")
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current  // User's timezone
        return formatter.string(from: timestamp)
    }
    
    /// Relative date for recent conversations (e.g., "Today", "Yesterday")
    public var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(timestamp) {
            return "Today"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(timestamp) == true {
            // This week - show day name only (e.g., "Monday")
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.timeZone = TimeZone.current
            return formatter.string(from: timestamp)
        } else if let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                  calendar.dateInterval(of: .weekOfYear, for: weekAgo)?.contains(timestamp) == true {
            // Last week - show "Last [Day]" (e.g., "Last Monday")
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.timeZone = TimeZone.current
            return "Last " + formatter.string(from: timestamp)
        } else {
            // Older - show full formatted date
            return formattedDate
        }
    }
    
    /// Compact date for space-constrained UI (e.g., "Jul 1" or "Today")
    public var compactDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(timestamp) {
            return "Today"
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else if calendar.isDate(timestamp, equalTo: now, toGranularity: .year) {
            // Same year - show month and day
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            formatter.timeZone = TimeZone.current
            return formatter.string(from: timestamp)
        } else {
            // Different year - show month, day, and year
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            formatter.timeZone = TimeZone.current
            return formatter.string(from: timestamp)
        }
    }
    
    /// Helper function to get ordinal suffix for day numbers
    private func daySuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
    
    /// Check if the conversation is from today
    public var isToday: Bool {
        Calendar.current.isDateInToday(timestamp)
    }
    
    /// Check if the conversation is from yesterday
    public var isYesterday: Bool {
        Calendar.current.isDateInYesterday(timestamp)
    }
    
    /// Check if the conversation is from this week
    public var isThisWeek: Bool {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateInterval(of: .weekOfYear, for: now)?.contains(timestamp) == true
    }
    
    /// Check if the conversation is from last week
    public var isLastWeek: Bool {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else { return false }
        return calendar.dateInterval(of: .weekOfYear, for: weekAgo)?.contains(timestamp) == true
    }
}
