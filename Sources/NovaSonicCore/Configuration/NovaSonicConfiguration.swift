import Foundation
import SmithyIdentity
#if IOS_AUDIO
import AVFoundation
#endif

/// Configuration for Nova Sonic speech-to-speech interactions
public struct NovaSonicConfiguration {
    
    // MARK: - Model Configuration
    
    /// AWS region for Nova Sonic (supports us-east-1, us-west-2, ap-northeast-1)
    public let region: String
    
    /// Voice to use for speech synthesis
    public let voice: NovaSonicVoice
    
    /// Controls randomness in response generation (0.0-1.0)
    public let temperature: Double
    
    /// Controls nucleus sampling for response diversity (0.0-1.0)
    public let topP: Double
    
    /// Maximum tokens in response
    public let maxTokens: Int
    
    /// System prompt for conversation context
    public let systemPrompt: String
    
    // MARK: - Nova 2.0 Features
    
    /// Turn detection sensitivity (Nova 2.0)
    /// Controls how quickly Nova Sonic takes its turn
    public let endpointingSensitivity: EndpointingSensitivity
    
    /// Enable paralinguistic detection (Nova 2.0)
    /// Returns sentiment tags in ASR transcript
    public let enableParalinguisticDetection: Bool
    
    /// Initial text prompt to start conversation (Nova 2.0)
    /// If provided, sends text instead of audio for speakFirst
    /// Example: "Hello, I'm your assistant. How can I help you today?"
    public let initialTextPrompt: String?
    
    // MARK: - Audio Configuration
    
    /// Input audio sample rate (8kHz, 16kHz, or 24kHz - higher rates give crisper output)
    public let inputSampleRate: NovaSonicSampleRate
    
    /// Output audio sample rate (8kHz, 16kHz, or 24kHz - matches input capabilities)
    public let outputSampleRate: NovaSonicSampleRate
    
    #if IOS_AUDIO
    /// iOS audio session category
    public let audioSessionCategory: AVAudioSession.Category
    
    /// iOS audio session options
    public let audioSessionOptions: AVAudioSession.CategoryOptions
    #endif
    
    // MARK: - History Management
    
    /// Optional history manager for conversation persistence
    /// Following the same optional and pluggable pattern as tools
    public let historyManager: NovaSonicHistoryManager?
    
    /// Enable built-in DynamoDB history (simple one-line setup)
    public let enableDynamoDBHistory: Bool
    
    /// DynamoDB table name (when using built-in DynamoDB history)
    public let dynamoDBTableName: String
    
    /// User ID for DynamoDB history (required for multi-user apps)
    /// If not provided, defaults to "default-user" for backward compatibility
    public let dynamoDBUserId: String?
    
    /// AWS region for DynamoDB (defaults to same as Nova Sonic)
    public let dynamoDBRegion: String
    
    /// Optional AWS credentials resolver for cross-region authentication
    /// Used for both Bedrock and DynamoDB clients when provided
    public let awsCredentialIdentityResolver: (any SmithyIdentity.AWSCredentialIdentityResolver)?
    
    // MARK: - Logging Configuration
    
    /// Logging level for Nova Sonic operations
    public let logLevel: NovaSonicLogLevel
    
    // MARK: - Initialization
    
    public init(
        region: String = "us-east-1",
        voice: NovaSonicVoice = .tiffany,
        temperature: Double = 0.7,
        topP: Double = 0.9,
        maxTokens: Int = 1024,
        systemPrompt: String = "You are a helpful assistant.",
        endpointingSensitivity: EndpointingSensitivity = .high,
        enableParalinguisticDetection: Bool = false,
        initialTextPrompt: String? = nil,
        inputSampleRate: NovaSonicSampleRate = .rate16kHz,
        outputSampleRate: NovaSonicSampleRate = .rate24kHz,
        historyManager: NovaSonicHistoryManager? = nil,
        enableDynamoDBHistory: Bool = false,
        dynamoDBTableName: String = "nova_sonic_chat_history",
        dynamoDBUserId: String? = nil,
        dynamoDBRegion: String? = nil,
        awsCredentialIdentityResolver: (any SmithyIdentity.AWSCredentialIdentityResolver)? = nil,
        logLevel: NovaSonicLogLevel = .standard
    ) {
        self.region = region
        self.voice = voice
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.endpointingSensitivity = endpointingSensitivity
        self.enableParalinguisticDetection = enableParalinguisticDetection
        self.initialTextPrompt = initialTextPrompt
        self.inputSampleRate = inputSampleRate
        self.outputSampleRate = outputSampleRate
        self.historyManager = historyManager
        self.enableDynamoDBHistory = enableDynamoDBHistory
        self.dynamoDBTableName = dynamoDBTableName
        self.dynamoDBUserId = dynamoDBUserId
        self.dynamoDBRegion = dynamoDBRegion ?? region
        self.awsCredentialIdentityResolver = awsCredentialIdentityResolver
        self.logLevel = logLevel
        
        #if IOS_AUDIO
        self.audioSessionCategory = .playAndRecord
        self.audioSessionOptions = [.defaultToSpeaker, .allowBluetooth]
        #endif
    }
    
    #if IOS_AUDIO
    /// Full initialization with iOS audio session control
    public init(
        region: String = "us-east-1",
        voice: NovaSonicVoice = .tiffany,
        temperature: Double = 0.7,
        topP: Double = 0.9,
        maxTokens: Int = 1024,
        systemPrompt: String = "You are a helpful assistant.",
        endpointingSensitivity: EndpointingSensitivity = .high,
        enableParalinguisticDetection: Bool = false,
        initialTextPrompt: String? = nil,
        inputSampleRate: NovaSonicSampleRate = .rate16kHz,
        outputSampleRate: NovaSonicSampleRate = .rate24kHz,
        audioSessionCategory: AVAudioSession.Category = .playAndRecord,
        audioSessionOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth],
        historyManager: NovaSonicHistoryManager? = nil,
        enableDynamoDBHistory: Bool = false,
        dynamoDBTableName: String = "nova_sonic_chat_history",
        dynamoDBUserId: String? = nil,
        dynamoDBRegion: String? = nil,
        awsCredentialIdentityResolver: (any SmithyIdentity.AWSCredentialIdentityResolver)? = nil,
        logLevel: NovaSonicLogLevel = .standard
    ) {
        self.region = region
        self.voice = voice
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.endpointingSensitivity = endpointingSensitivity
        self.enableParalinguisticDetection = enableParalinguisticDetection
        self.initialTextPrompt = initialTextPrompt
        self.inputSampleRate = inputSampleRate
        self.outputSampleRate = outputSampleRate
        self.audioSessionCategory = audioSessionCategory
        self.audioSessionOptions = audioSessionOptions
        self.historyManager = historyManager
        self.enableDynamoDBHistory = enableDynamoDBHistory
        self.dynamoDBTableName = dynamoDBTableName
        self.dynamoDBUserId = dynamoDBUserId
        self.dynamoDBRegion = dynamoDBRegion ?? region
        self.awsCredentialIdentityResolver = awsCredentialIdentityResolver
        self.logLevel = logLevel
    }
    #endif
}

// MARK: - Preset Configurations

public extension NovaSonicConfiguration {
    
    /// Default configuration for most use cases
    static let `default` = NovaSonicConfiguration()
    
    /// Maximum quality configuration (24kHz input/output)
    static let maxQuality = NovaSonicConfiguration(
        inputSampleRate: .rate24kHz,
        outputSampleRate: .rate24kHz
    )
    
    /// Low bandwidth configuration (8kHz input/output)
    static let lowBandwidth = NovaSonicConfiguration(
        inputSampleRate: .rate8kHz,
        outputSampleRate: .rate8kHz
    )
    
    /// Creative responses configuration
    static let creative = NovaSonicConfiguration(
        temperature: 0.9,
        topP: 0.95
    )
    
    /// Focused responses configuration
    static let focused = NovaSonicConfiguration(
        temperature: 0.3,
        topP: 0.7
    )
    
    /// 🎉 ONE-LINE DYNAMODB SETUP!
    /// Simple DynamoDB history setup - just provide table name and user ID
    static func withDynamoDBHistory(
        tableName: String = "nova_sonic_chat_history",
        userId: String,
        voice: NovaSonicVoice = .tiffany,
        systemPrompt: String = "You are a helpful assistant."
    ) -> NovaSonicConfiguration {
        return NovaSonicConfiguration(
            voice: voice,
            systemPrompt: systemPrompt,
            enableDynamoDBHistory: true,
            dynamoDBTableName: tableName,
            dynamoDBUserId: userId
        )
    }
}

// MARK: - Supporting Types

/// Turn detection sensitivity for Nova Sonic 2.0
/// Controls how quickly Nova Sonic takes its turn in conversation
public enum EndpointingSensitivity: String, CaseIterable {
    case high = "HIGH"      // Fastest, latency-optimized (default)
    case medium = "MEDIUM"  // Intermediary setting
    case low = "LOW"        // Slowest, waits longest to take turn
    
    public var displayName: String {
        switch self {
        case .high: return "High (Fastest Response)"
        case .medium: return "Medium (Balanced)"
        case .low: return "Low (Patient, Waits Longer)"
        }
    }
}

/// Nova Sonic voice options
public enum NovaSonicVoice: String, CaseIterable {
    // US English
    case matthew, tiffany
    
    // UK English
    case amy
    
    // Australian English (Nova 2.0)
    case olivia
    
    // Spanish
    case lupe, carlos
    
    // French (Nova 2.0)
    case florian, ambre
    
    // Italian (Nova 2.0)
    case lorenzo, beatrice
    
    // German (Nova 2.0)
    case lennart, tina, greta
    
    // Portuguese (Nova 2.0)
    case camila, leo
    
    // Hindi (Nova 2.0)
    case aditi, rohan
    
    public var displayName: String {
        switch self {
        case .matthew: return "Matthew"
        case .tiffany: return "Tiffany"
        case .amy: return "Amy"
        case .olivia: return "Olivia"
        case .lupe: return "Lupe"
        case .carlos: return "Carlos"
        case .florian: return "Florian"
        case .ambre: return "Ambre"
        case .lorenzo: return "Lorenzo"
        case .beatrice: return "Beatrice"
        case .lennart: return "Lennart"
        case .tina: return "Tina"
        case .greta: return "Greta"
        case .camila: return "Camila"
        case .leo: return "Leo"
        case .aditi: return "Aditi"
        case .rohan: return "Rohan"
        }
    }
    
    public var region: String {
        switch self {
        case .matthew, .tiffany: return "US English"
        case .amy: return "UK English"
        case .olivia: return "Australian English"
        case .lupe, .carlos: return "Spanish"
        case .florian, .ambre: return "French"
        case .lorenzo, .beatrice: return "Italian"
        case .lennart, .tina, .greta: return "German"
        case .camila, .leo: return "Portuguese"
        case .aditi, .rohan: return "Hindi"
        }
    }
    
    public var isPolyglot: Bool {
        switch self {
        case .tiffany: return true  // English, French, Italian, German, Spanish
        case .matthew, .amy, .olivia: return false
        case .lupe, .carlos: return true  // Spanish + English (code switching)
        case .florian, .ambre: return true  // French + English
        case .lorenzo, .beatrice: return true  // Italian + English
        case .lennart, .tina, .greta: return true  // German + English
        case .camila, .leo: return true  // Portuguese + English
        case .aditi, .rohan: return true  // Hindi + English (code switching)
        }
    }
}

/// Audio sample rate options supported by Nova Sonic
/// Higher rates give crisper output but use more bandwidth
public enum NovaSonicSampleRate: Int, CaseIterable {
    case rate8kHz = 8000
    case rate16kHz = 16000   // Demo default for input
    case rate24kHz = 24000   // Demo default for output
    
    public var displayName: String {
        switch self {
        case .rate8kHz: return "8 kHz (Low Quality, Low Bandwidth)"
        case .rate16kHz: return "16 kHz (Standard Quality)"
        case .rate24kHz: return "24 kHz (High Quality, Crisper Output)"
        }
    }
    
    public var hertz: Int {
        return self.rawValue
    }
}

// MARK: - Convenience Extensions

extension NovaSonicConfiguration {
    
    /// Voice Options
    
    /// - `.matthew` - US English, masculine
    /// - `.tiffany` - US English, feminine  
    /// - `.amy` - UK English, feminine
    /// - `.lupe` - Spanish, feminine
    /// - `.carlos` - Spanish, masculine
    
    /// Sample Rate Options
    
    /// - `.rate8kHz` - 8 kHz (Low bandwidth, basic quality)
    /// - `.rate16kHz` - 16 kHz (Demo default for input, balanced quality)
    /// - `.rate24kHz` - 24 kHz (High quality, crisper output)
    
    /// Model Parameters
    
    /// - `temperature`: 0.1-1.0 (0.1 = focused, 1.0 = creative)
    /// - `topP`: 0.5-1.0 (0.5 = consistent, 1.0 = diverse)
    /// - `maxTokens`: 1-4096 (response length limit)
}

// MARK: - Validation

extension NovaSonicConfiguration {
    
    /// Validate configuration parameters
    public func validate() throws {
        // Validate region - Nova Sonic 2 supports multiple regions
        let supportedRegions = ["us-east-1", "us-west-2", "ap-northeast-1"]
        guard supportedRegions.contains(region) else {
            throw NovaSonicError.invalidConfiguration
        }
        
        // Validate temperature range
        guard temperature >= 0.0 && temperature <= 1.0 else {
            throw NovaSonicError.invalidConfiguration
        }
        
        // Validate topP range
        guard topP >= 0.0 && topP <= 1.0 else {
            throw NovaSonicError.invalidConfiguration
        }
        
        // Validate maxTokens
        guard maxTokens > 0 && maxTokens <= 4096 else {
            throw NovaSonicError.invalidConfiguration
        }
        
        // Validate system prompt
        guard !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NovaSonicError.invalidConfiguration
        }
    }
}
