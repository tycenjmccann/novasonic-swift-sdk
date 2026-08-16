import Foundation

/// Errors thrown when audio configuration is invalid.
public enum NovaSonicConfigurationError: Error, Sendable, LocalizedError {
    /// The requested sample rate is not valid for the specified codec.
    /// G.711 codecs (pcmu, pcma) only support 8000 Hz.
    case invalidSampleRateForCodec(
        codec: AudioCodec,
        requested: NovaSonicSampleRate,
        allowed: [NovaSonicSampleRate]
    )

    /// Binary transport currently only supported with PCM codec.
    case binaryTransportRequiresPCM(codec: AudioCodec)

    /// Codec not available on this platform/OS version.
    case unsupportedCodec(AudioCodec)

    /// Binary transport not supported by the service endpoint.
    case binaryTransportUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidSampleRateForCodec(let codec, let requested, let allowed):
            let rates = allowed.map { "\($0.rawValue)" }.joined(separator: ", ")
            return "Sample rate \(requested.rawValue) Hz is not valid for codec \(codec.rawValue). Allowed rates: \(rates) Hz."
        case .binaryTransportRequiresPCM(let codec):
            return "Binary transport is only supported with PCM codec. Configured codec: \(codec.rawValue)."
        case .unsupportedCodec(let codec):
            return "Codec \(codec.displayName) is not available on this platform."
        case .binaryTransportUnavailable:
            return "Binary transport is not supported by the service endpoint. Falling back to JSON transport."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidSampleRateForCodec:
            return "Use .rate8kHz with G.711 formats, or switch to .pcm for other sample rates."
        case .binaryTransportRequiresPCM:
            return "Set audio format to .pcm, or switch transport to .json."
        case .unsupportedCodec:
            return "Use .pcm codec or ensure your device supports the requested codec."
        case .binaryTransportUnavailable:
            return "Use .json transport or ensure the service endpoint supports binary frames."
        }
    }
}
