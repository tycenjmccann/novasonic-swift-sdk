import Foundation

/// Codec selection for audio encoding/decoding in the NovaSonic pipeline.
public enum AudioCodec: String, Sendable, CaseIterable {
    case pcm    // Linear PCM, 16-bit signed integer
    case pcmu   // G.711 µ-law (ITU-T G.711)
    case pcma   // G.711 A-law (ITU-T G.711)

    /// The media type string sent in Bedrock event-stream protocol messages.
    public var mediaType: String {
        switch self {
        case .pcm:  return "audio/lpcm"
        case .pcmu: return "audio/pcmu"
        case .pcma: return "audio/pcma"
        }
    }

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .pcm:  return "Linear PCM"
        case .pcmu: return "G.711 µ-law"
        case .pcma: return "G.711 A-law"
        }
    }

    /// Valid sample rates for this codec.
    public var supportedSampleRates: [NovaSonicSampleRate] {
        switch self {
        case .pcm:
            return NovaSonicSampleRate.allCases
        case .pcmu, .pcma:
            return [.rate8kHz]
        }
    }

    /// Whether this codec requires a fixed sample rate (no negotiation).
    public var isFixedRate: Bool {
        switch self {
        case .pcm:  return false
        case .pcmu, .pcma: return true
        }
    }

    /// Bytes per sample in the encoded domain.
    public var bytesPerEncodedSample: Int {
        switch self {
        case .pcm:  return 2  // Int16
        case .pcmu, .pcma: return 1  // 8-bit compressed
        }
    }

    /// Bits per sample for Bedrock event payload configuration.
    public var sampleSizeBits: Int {
        switch self {
        case .pcm: return 16
        case .pcmu, .pcma: return 8
        }
    }
}
