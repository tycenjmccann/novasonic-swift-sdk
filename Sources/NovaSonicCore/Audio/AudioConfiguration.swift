import Foundation

/// Audio transport mode for WebSocket communication
public enum AudioTransport: String, Codable, Sendable, CaseIterable {
    /// Base64-encoded audio in JSON event messages (default)
    case json = "json"
    /// Raw binary audio data frames over WebSocket
    case binary = "binary"

    /// Human-readable label suitable for UI display.
    public var displayName: String {
        switch self {
        case .json: return "JSON (base64)"
        case .binary: return "Binary (raw PCM)"
        }
    }

    /// The `encoding` value to emit in audio configuration events.
    public var encodingValue: String {
        switch self {
        case .json: return "base64"
        case .binary: return "none"
        }
    }
}

#if IOS_AUDIO
import AVFoundation

/// Audio configuration constants and utilities for Nova Sonic
public struct AudioConfiguration {
    
    // MARK: - Audio Format Factory
    
    /// Create input audio format for Nova Sonic
    public static func inputFormat(sampleRate: Double) -> AudioFormat {
        return AudioFormat(
            sampleRate: sampleRate,
            channels: 1,
            bitDepth: 16,
            encoding: .pcm
        )
    }
    
    /// Create output audio format from Nova Sonic
    public static func outputFormat(sampleRate: Double) -> AudioFormat {
        return AudioFormat(
            sampleRate: sampleRate,
            channels: 1,
            bitDepth: 16,
            encoding: .pcm
        )
    }
    
    /// Create AVAudioFormat for input processing
    public static func avInputFormat(sampleRate: Double) -> AVAudioFormat? {
        return AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )
    }
    
    /// Create AVAudioFormat for output processing
    public static func avOutputFormat(sampleRate: Double) -> AVAudioFormat? {
        return AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )
    }
    
    // MARK: - Buffer Configuration
    
    /// Audio buffer size for processing
    public static let bufferSize: AVAudioFrameCount = 256
    
    /// Preferred buffer duration for low latency
    public static let preferredBufferDuration: TimeInterval = 0.005
    
    /// Maximum frames per slice for processing
    public static let maxFramesPerSlice: AVAudioFrameCount = 4096
}

/// Audio format specification
public struct AudioFormat {
    public let sampleRate: Double
    public let channels: UInt32
    public let bitDepth: UInt32
    public let encoding: AudioEncoding
    
    public init(sampleRate: Double, channels: UInt32, bitDepth: UInt32, encoding: AudioEncoding) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
        self.encoding = encoding
    }
}

/// Audio encoding types
public enum AudioEncoding {
    case pcm
    case compressed
}

#endif
