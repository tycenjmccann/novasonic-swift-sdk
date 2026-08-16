import Foundation

/// WebSocket-based stream manager for direct Nova Sonic connections.
/// Supports both text (JSON) and binary (raw PCM) frame transport.
public final class WebSocketStreamManager: NSObject, StreamManaging, URLSessionWebSocketDelegate {
    public private(set) var connectionState: ConnectionState = .disconnected

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var endpoint: URL?
    private var pingTimer: Timer?
    private let pingInterval: TimeInterval = 30.0

    public override init() {
        super.init()
    }

    // MARK: - StreamManaging

    public func connect(configuration: NovaSonicConfiguration) async throws {
        guard case .webSocket(let endpoint) = configuration.connectionMode else {
            throw NovaSonicError.invalidConfiguration
        }
        self.endpoint = endpoint
        connectionState = .connecting

        let session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: nil
        )
        self.urlSession = session

        let task = session.webSocketTask(with: endpoint)
        self.webSocketTask = task
        task.resume()

        connectionState = .connected
        schedulePing()
    }

    public func sendEvent(_ event: Data) async throws {
        guard let task = webSocketTask else {
            throw NovaSonicError.webSocketConnectionFailed(underlying: nil)
        }
        guard let jsonString = String(data: event, encoding: .utf8) else {
            throw NovaSonicError.invalidResponse("Failed to encode event as UTF-8 string")
        }
        let message = URLSessionWebSocketTask.Message.string(jsonString)
        try await task.send(message)
    }

    public func sendAudio(_ audioData: Data) async throws {
        guard let task = webSocketTask else {
            throw NovaSonicError.webSocketConnectionFailed(underlying: nil)
        }
        let message = URLSessionWebSocketTask.Message.data(audioData)
        try await task.send(message)
    }

    public func receiveEvent() async throws -> StreamEvent? {
        guard let task = webSocketTask else {
            return nil
        }
        let message = try await task.receive()
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else {
                return nil
            }
            return .json(data)
        case .data(let data):
            return .audioFrame(data)
        @unknown default:
            return nil
        }
    }

    public func disconnect() async {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        connectionState = .disconnected
    }

    public func sendSessionUpdate(_ update: SessionUpdate) async throws {
        guard let data = update.toJSONData() else {
            throw NovaSonicError.sessionUpdateRejected(field: "payload", reason: "Failed to serialize session update")
        }
        try await sendEvent(data)
    }

    // MARK: - Ping/Keep-alive

    private func schedulePing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { error in
                if let error = error {
                    NovaSonicLogger.error("WebSocket ping failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        connectionState = .connected
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        connectionState = .disconnected
    }
}
