import Foundation

/// Transport mode controlling how audio frames are serialized on the wire.
public enum AudioTransport: String, Sendable, CaseIterable {
    /// Audio bytes are base64-encoded and wrapped in JSON event payloads (default, backward-compatible).
    case json

    /// Audio bytes are sent as raw binary frames in the event-stream, no base64/JSON wrapping.
    case binary

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .json:   return "JSON (base64)"
        case .binary: return "Binary frames"
        }
    }
}
