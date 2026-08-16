import Foundation

/// Audio media types supported by Nova Sonic for input and output streams
public enum AudioMediaType: String, CaseIterable, Sendable {
    case lpcm = "audio/lpcm"
    case pcm = "audio/pcm"
    case pcmu = "audio/pcmu"
    case pcma = "audio/pcma"

    /// The wire-format value sent in Bedrock event JSON
    public var wireValue: String { rawValue }

    /// Whether this media type supports configurable sample rates.
    /// Only `.pcm` allows arbitrary rates; others have fixed rates.
    public var supportsSampleRate: Bool { self == .pcm }
}
