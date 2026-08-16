import Foundation

/// Connection mode for Nova Sonic streaming
public enum ConnectionMode: Sendable {
    /// Standard Bedrock SDK bidirectional stream (InvokeModelWithBidirectionalStream)
    case bedrockSDK
    /// Direct WebSocket connection to a Nova Sonic endpoint
    case webSocket(endpoint: URL)
}
