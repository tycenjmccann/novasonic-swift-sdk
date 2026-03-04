// MARK: - Error Handling Utilities for Integration

extension NovaSonicStreamManager {
    
    /// Helper method to handle errors consistently across the app
    func handleError(_ error: Error, context: String) {
        let novaSonicError: NovaSonicError
        
        // Convert to NovaSonicError based on context
        if context.contains("audio") {
            novaSonicError = NovaSonicError.from(audioError: error)
        } else {
            novaSonicError = NovaSonicError.from(awsError: error)
        }
        
        NovaSonicLogger.error("\(context): \(novaSonicError.localizedDescription)")
        
        if let recovery = novaSonicError.recoverySuggestion {
            NovaSonicLogger.error("Recovery suggestion: \(recovery)")
        }
        
        // You could also emit this to a @Published property for UI display
        // self.lastError = novaSonicError
    }
}

/*
 EXAMPLE USAGE IN EXISTING CODE:
 
 Instead of:
 } catch {
     NovaSonicLogger.error("Failed to set up audio streams: \(error)")
     throw error
 }
 
 Use:
 } catch {
     handleError(error, context: "Failed to set up audio streams")
     throw NovaSonicError.from(audioError: error)
 }
*/
