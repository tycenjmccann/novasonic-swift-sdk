import Foundation

/// Transport mode for audio data between client and service
public enum AudioTransport: Sendable {
    /// JSON transport: audio is base64-encoded within JSON event payloads
    case json
    /// Binary transport: raw PCM frames sent as WebSocket binary messages
    case binary

    /// Per-frame overhead in bytes introduced by the transport framing
    public var frameOverhead: Int {
        switch self {
        case .json: return 0
        case .binary: return 4
        }
    }
}
