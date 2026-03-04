import Foundation
import os.log

/// Log levels for Nova Sonic package operations
public enum NovaSonicLogLevel: Int, CaseIterable {
    case off = -1       // No logging
    case minimal = 0    // Only critical messages
    case standard = 1   // Key operations (default)
    case verbose = 2    // Everything (debugging)
    
    public var description: String {
        switch self {
        case .off: return "Off"
        case .minimal: return "Minimal"
        case .standard: return "Standard"
        case .verbose: return "Verbose"
        }
    }
}

/// Centralized logging system for Nova Sonic package
public class NovaSonicLogger {
    /// Current log level - set from configuration
    public static var currentLevel: NovaSonicLogLevel = .standard {
        didSet {
            // Log level changes for debugging
            if currentLevel != .off {
                print("🔧 NovaSonic logging level set to: \(currentLevel.description)")
            }
        }
    }
    
    /// Thread-safe logging queue
    private static let loggingQueue = DispatchQueue(label: "com.novasonic.logging", qos: .utility)
    
    /// OSLog for system integration and crash debugging
    private static let osLog = OSLog(subsystem: "com.novasonic.package", category: "NovaSONIC")
    
    /// Log minimal level messages (critical errors and key lifecycle events)
    public static func minimal(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .minimal, message: message, file: file, function: function, line: line)
    }
    
    /// Log standard level messages (normal operational logging)
    public static func standard(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .standard, message: message, file: file, function: function, line: line)
    }
    
    /// Log verbose level messages (detailed debugging)
    public static func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .verbose, message: message, file: file, function: function, line: line)
    }
    
    /// Log error messages (always shown unless level is .off)
    public static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .minimal, message: "❌ ERROR: \(message)", file: file, function: function, line: line)
    }
    
    /// Log threading information for debugging crashes
    public static func thread(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let threadInfo = Thread.isMainThread ? "[MAIN]" : "[BG-\(Thread.current.hash)]"
        log(level: .verbose, message: "🧵 \(threadInfo) \(message)", file: file, function: function, line: line)
    }
    
    /// Log memory warnings and issues
    public static func memory(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .standard, message: "🧠 MEMORY: \(message)", file: file, function: function, line: line)
    }
    
    /// Log session lifecycle for crash debugging
    public static func session(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .standard, message: "🔄 SESSION: \(message)", file: file, function: function, line: line)
    }
    
    /// Initialize logging with a specific level (backward compatibility)
    public static func initialize(level: NovaSonicLogLevel) {
        currentLevel = level
        if level != .off {
            print("🚀 NovaSonic Logger initialized with level: \(level.description)")
        }
    }
    
    // MARK: - Private Implementation
    
    private static func log(level: NovaSonicLogLevel, message: String, file: String, function: String, line: Int) {
        // Skip if logging is disabled or level is too low
        guard currentLevel != .off && level.rawValue <= currentLevel.rawValue else { return }
        
        // Thread-safe logging to prevent crashes during logging
        loggingQueue.async {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            let timestamp = DateFormatter.logFormatter.string(from: Date())
            let threadInfo = Thread.isMainThread ? "[MAIN]" : "[BG]"
            
            let logMessage = "[\(timestamp)] \(threadInfo) [\(level.description.uppercased())] \(fileName):\(line) \(function) - \(message)"
            
            // Print to console
            print(logMessage)
            
            // Also log to OSLog for system debugging and crash analysis
            os_log("%{public}@", log: osLog, type: .default, logMessage)
        }
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
