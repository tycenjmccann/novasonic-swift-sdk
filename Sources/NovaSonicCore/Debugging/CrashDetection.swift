import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Crash detection and monitoring utility for Nova Sonic integration
public class NovaSonicCrashDetection {
    
    private static var conversationStartTime: Date?
    private static var lastMemoryWarning: Date?
    private static var memoryCheckTimer: Timer?
    
    /// Enable crash detection monitoring
    public static func enableMonitoring() {
        #if canImport(UIKit)
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            lastMemoryWarning = Date()
            NovaSonicLogger.memory("⚠️ Memory warning received during Nova Sonic session")
            logMemoryUsage()
        }
        
        // Monitor app state changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            NovaSonicLogger.session("📱 App entered background during Nova Sonic session")
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            NovaSonicLogger.session("📱 App entering foreground")
        }
        #endif
        
        // Start periodic memory monitoring
        startMemoryMonitoring()
        
        NovaSonicLogger.standard("🔍 Nova Sonic crash detection enabled")
    }
    
    /// Call when starting a Nova Sonic conversation
    public static func conversationStarted() {
        conversationStartTime = Date()
        NovaSonicLogger.session("🎙️ Conversation started - monitoring for crashes")
        logMemoryUsage()
    }
    
    /// Call when ending a Nova Sonic conversation
    public static func conversationEnded() {
        if let startTime = conversationStartTime {
            let duration = Date().timeIntervalSince(startTime)
            NovaSonicLogger.session("🎙️ Conversation ended after \(String(format: "%.1f", duration)) seconds")
            
            // Log if this was a long conversation (potential crash risk)
            if duration > 120 { // 2 minutes
                NovaSonicLogger.session("⚠️ Long conversation completed successfully (\(String(format: "%.1f", duration))s)")
            }
        }
        conversationStartTime = nil
        logMemoryUsage()
    }
    
    /// Log current memory usage
    public static func logMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        NovaSonicLogger.memory("Current memory usage: \(memoryUsage) MB")
        
        // Warn if memory usage is high
        if memoryUsage > 200 {
            NovaSonicLogger.memory("⚠️ High memory usage detected: \(memoryUsage) MB")
        }
    }
    
    /// Get current memory usage in MB
    private static func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size / 1024 / 1024) // Convert to MB
        }
        return 0
    }
    
    /// Start periodic memory monitoring
    private static func startMemoryMonitoring() {
        memoryCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            // Only log during active conversations to avoid spam
            if conversationStartTime != nil {
                logMemoryUsage()
            }
        }
    }
    
    /// Stop monitoring (call when app is shutting down)
    public static func stopMonitoring() {
        memoryCheckTimer?.invalidate()
        memoryCheckTimer = nil
        NotificationCenter.default.removeObserver(self)
        NovaSonicLogger.standard("🔍 Nova Sonic crash detection disabled")
    }
    
    /// Check if we're in a potentially crash-prone state
    public static func checkCrashRisk() -> String? {
        var warnings: [String] = []
        
        // Check conversation duration
        if let startTime = conversationStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration > 180 { // 3 minutes
                warnings.append("Long conversation (\(String(format: "%.1f", duration))s)")
            }
        }
        
        // Check memory usage
        let memoryUsage = getMemoryUsage()
        if memoryUsage > 150 {
            warnings.append("High memory usage (\(memoryUsage) MB)")
        }
        
        // Check recent memory warnings
        if let lastWarning = lastMemoryWarning,
           Date().timeIntervalSince(lastWarning) < 60 {
            warnings.append("Recent memory warning")
        }
        
        return warnings.isEmpty ? nil : warnings.joined(separator: ", ")
    }
}

// MARK: - EZMeals Integration Helper

public extension NovaSonicCrashDetection {
    
    /// Easy integration for EZMeals app
    static func setupForEZMeals() {
        // Enable verbose logging for debugging
        NovaSonicLogger.currentLevel = .verbose
        
        // Enable crash detection
        enableMonitoring()
        
        NovaSonicLogger.standard("🍽️ Nova Sonic crash detection configured for EZMeals")
    }
    
    /// Call this in your EZMeals voice chat view onAppear
    static func voiceChatStarted() {
        conversationStarted()
        NovaSonicLogger.session("🍽️ EZMeals voice chat started")
    }
    
    /// Call this in your EZMeals voice chat view onDisappear
    static func voiceChatEnded() {
        conversationEnded()
        NovaSonicLogger.session("🍽️ EZMeals voice chat ended")
    }
}
