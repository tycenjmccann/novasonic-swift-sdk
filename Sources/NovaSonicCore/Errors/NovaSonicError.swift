import Foundation

public enum NovaSonicError: Error, LocalizedError {
    case audioPermissionDenied
    case networkConnectionFailed
    case authenticationFailed
    case toolExecutionFailed(String)
    case sessionTimeout
    case invalidConfiguration
    case streamingError(String)
    case audioSessionError(String)
    case invalidResponse(String)
    case serviceUnavailable
    case rateLimitExceeded
    case invalidAudioFormat
    case microphoneNotAvailable
    
    // Audio-specific errors
    case converterCreationFailed
    case sessionConfigurationFailed
    case engineStartFailed
    case conversionFailed
    case bufferCreationFailed
    case invalidFormat
    
    public var errorDescription: String? {
        switch self {
        case .audioPermissionDenied:
            return "Microphone access is required for voice conversations"
        case .networkConnectionFailed:
            return "Unable to connect to Nova Sonic service"
        case .authenticationFailed:
            return "AWS authentication failed"
        case .toolExecutionFailed(let tool):
            return "Tool '\(tool)' execution failed"
        case .sessionTimeout:
            return "Conversation session has timed out"
        case .invalidConfiguration:
            return "Invalid Nova Sonic configuration"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .audioSessionError(let message):
            return "Audio session error: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from service: \(message)"
        case .serviceUnavailable:
            return "Nova Sonic service is temporarily unavailable"
        case .rateLimitExceeded:
            return "Rate limit exceeded - too many requests"
        case .invalidAudioFormat:
            return "Invalid audio format or corrupted audio data"
        case .microphoneNotAvailable:
            return "Microphone is not available on this device"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .sessionConfigurationFailed:
            return "Failed to configure audio session"
        case .engineStartFailed:
            return "Failed to start audio engine"
        case .conversionFailed:
            return "Audio format conversion failed"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .invalidFormat:
            return "Invalid audio format"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .audioPermissionDenied:
            return "Please enable microphone access in Settings > Privacy & Security > Microphone"
        case .networkConnectionFailed:
            return "Check your internet connection and try again"
        case .authenticationFailed:
            return "Verify your AWS credentials are properly configured"
        case .toolExecutionFailed:
            return "Try the request again or contact support if the issue persists"
        case .sessionTimeout:
            return "Start a new conversation session"
        case .invalidConfiguration:
            return "Check your Nova Sonic configuration settings"
        case .streamingError, .audioSessionError:
            return "Try restarting the conversation"
        case .invalidResponse:
            return "Try your request again or restart the session"
        case .serviceUnavailable:
            return "Please try again in a few minutes"
        case .rateLimitExceeded:
            return "Wait a moment before making another request"
        case .invalidAudioFormat:
            return "Try restarting the audio session"
        case .microphoneNotAvailable:
            return "Try using a device with microphone support"
        case .converterCreationFailed:
            return "Try restarting the audio session"
        case .sessionConfigurationFailed:
            return "Check audio permissions and try again"
        case .engineStartFailed:
            return "Try restarting the audio session"
        case .conversionFailed:
            return "Try restarting the audio session"
        case .bufferCreationFailed:
            return "Try restarting the audio session"
        case .invalidFormat:
            return "Try restarting the audio session"
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .networkConnectionFailed, .serviceUnavailable, .rateLimitExceeded, .sessionTimeout:
            return true
        case .audioPermissionDenied, .authenticationFailed, .invalidConfiguration, .microphoneNotAvailable:
            return false
        case .converterCreationFailed, .sessionConfigurationFailed, .engineStartFailed, .conversionFailed, .bufferCreationFailed, .invalidFormat:
            return true  // Audio errors are often retryable
        case .toolExecutionFailed, .streamingError, .audioSessionError, .invalidResponse, .invalidAudioFormat:
            return true
        }
    }
}

// MARK: - Error Handling Utilities

public extension NovaSonicError {
    /// Creates an appropriate error from an AWS service error
    static func from(awsError: Error) -> NovaSonicError {
        let errorString = String(describing: awsError)
        
        if errorString.contains("ValidationException") {
            return .invalidConfiguration
        } else if errorString.contains("UnauthorizedException") || errorString.contains("AccessDenied") {
            return .authenticationFailed
        } else if errorString.contains("ThrottlingException") || errorString.contains("TooManyRequests") {
            return .rateLimitExceeded
        } else if errorString.contains("ServiceUnavailable") || errorString.contains("InternalServerError") {
            return .serviceUnavailable
        } else if errorString.contains("NetworkError") || errorString.contains("URLError") {
            return .networkConnectionFailed
        } else {
            return .streamingError(errorString)
        }
    }
    
    /// Creates an appropriate error from an audio-related error
    static func from(audioError: Error) -> NovaSonicError {
        let errorString = String(describing: audioError)
        
        if errorString.contains("AVAudioSessionErrorCodeCannotInterruptOthers") {
            return .audioSessionError("Cannot interrupt other audio sessions")
        } else if errorString.contains("AVAudioSessionErrorCodeMissingEntitlement") {
            return .audioPermissionDenied
        } else if errorString.contains("AVAudioSessionErrorCodeCannotStartPlaying") {
            return .audioSessionError("Cannot start audio playback")
        } else if errorString.contains("AVAudioSessionErrorCodeCannotStartRecording") {
            return .audioSessionError("Cannot start audio recording")
        } else {
            return .audioSessionError(errorString)
        }
    }
}
