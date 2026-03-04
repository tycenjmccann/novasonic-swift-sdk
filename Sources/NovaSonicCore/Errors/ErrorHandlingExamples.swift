import Foundation

// MARK: - Error Handling Integration Examples
// This file shows how to integrate NovaSonicError with existing code

/*
 EXAMPLE 1: Replace simple print statements with proper error handling
 
 BEFORE:
 } catch {
     NovaSonicLogger.error("Failed to initialize DynamoDB manager: \(error)")
 }
 
 AFTER:
 } catch {
     let novaSonicError = NovaSonicError.from(awsError: error)
     NovaSonicLogger.error("Failed to initialize DynamoDB manager: \(novaSonicError.localizedDescription)")
     if let recovery = novaSonicError.recoverySuggestion {
         NovaSonicLogger.error("Recovery suggestion: \(recovery)")
     }
 }
*/

/*
 EXAMPLE 2: Audio session error handling
 
 BEFORE:
 } catch {
     NovaSonicLogger.error("Error starting audio recording: \(error)")
 }
 
 AFTER:
 } catch {
     let novaSonicError = NovaSonicError.from(audioError: error)
     NovaSonicLogger.error("Error starting audio recording: \(novaSonicError.localizedDescription)")
     if let recovery = novaSonicError.recoverySuggestion {
         NovaSonicLogger.error("Recovery suggestion: \(recovery)")
     }
     
     // Handle specific error types
     if case .audioPermissionDenied = novaSonicError {
         // Show permission request UI
     }
 }
*/

/*
 EXAMPLE 3: Streaming error handling with retry logic
 
 BEFORE:
 } catch {
     NovaSonicLogger.error("Stream failed to open: \(error)")
     await stopStreaming()
 }
 
 AFTER:
 } catch {
     let novaSonicError = NovaSonicError.from(awsError: error)
     NovaSonicLogger.error("Stream failed to open: \(novaSonicError.localizedDescription)")
     
     if novaSonicError.isRetryable {
         NovaSonicLogger.standard("Error is retryable, attempting retry...")
         // Implement retry logic here
     } else {
         NovaSonicLogger.error("Error is not retryable")
         if let recovery = novaSonicError.recoverySuggestion {
             NovaSonicLogger.error("Recovery suggestion: \(recovery)")
         }
     }
     await stopStreaming()
 }
*/

