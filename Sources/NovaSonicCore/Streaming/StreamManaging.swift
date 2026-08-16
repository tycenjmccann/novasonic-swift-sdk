import Foundation

/// Represents the connection state of a stream manager
public enum ConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(NovaSonicError)
}

/// Events received from the stream
public enum StreamEvent: Sendable {
    case json(Data)
    case audioFrame(Data)
}

/// Protocol for managing bidirectional streams to Nova Sonic
public protocol StreamManaging: AnyObject {
    var connectionState: ConnectionState { get }
    func connect(configuration: NovaSonicConfiguration) async throws
    func sendEvent(_ event: Data) async throws
    func sendAudio(_ audioData: Data) async throws
    func receiveEvent() async throws -> StreamEvent?
    func disconnect() async
    func sendSessionUpdate(_ update: SessionUpdate) async throws
}
