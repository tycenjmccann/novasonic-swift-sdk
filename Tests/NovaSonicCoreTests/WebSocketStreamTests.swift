import XCTest
@testable import NovaSonicCore

final class WebSocketStreamTests: XCTestCase {

    // MARK: - WebSocketStreamManager initialization

    func testWebSocketStreamManagerInitialState() {
        let manager = WebSocketStreamManager()
        if case .disconnected = manager.connectionState {
            // expected
        } else {
            XCTFail("Expected initial state to be .disconnected")
        }
    }

    // MARK: - ConnectionState enum

    func testConnectionStateDisconnected() {
        let state = ConnectionState.disconnected
        if case .disconnected = state {
            // pass
        } else {
            XCTFail("Expected disconnected")
        }
    }

    func testConnectionStateConnecting() {
        let state = ConnectionState.connecting
        if case .connecting = state {
            // pass
        } else {
            XCTFail("Expected connecting")
        }
    }

    func testConnectionStateConnected() {
        let state = ConnectionState.connected
        if case .connected = state {
            // pass
        } else {
            XCTFail("Expected connected")
        }
    }

    func testConnectionStateReconnecting() {
        let state = ConnectionState.reconnecting(attempt: 3)
        if case .reconnecting(let attempt) = state {
            XCTAssertEqual(attempt, 3)
        } else {
            XCTFail("Expected reconnecting")
        }
    }

    func testConnectionStateFailed() {
        let error = NovaSonicError.webSocketConnectionFailed(underlying: nil)
        let state = ConnectionState.failed(error)
        if case .failed(let stateError) = state {
            if case .webSocketConnectionFailed = stateError {
                // pass
            } else {
                XCTFail("Expected webSocketConnectionFailed")
            }
        } else {
            XCTFail("Expected failed state")
        }
    }

    // MARK: - StreamEvent enum

    func testStreamEventJson() {
        let data = "{\"type\":\"test\"}".data(using: .utf8)!
        let event = StreamEvent.json(data)
        if case .json(let eventData) = event {
            XCTAssertEqual(eventData, data)
        } else {
            XCTFail("Expected json event")
        }
    }

    func testStreamEventAudioFrame() {
        let audioData = Data([0x01, 0x02, 0x03, 0x04])
        let event = StreamEvent.audioFrame(audioData)
        if case .audioFrame(let data) = event {
            XCTAssertEqual(data, audioData)
        } else {
            XCTFail("Expected audioFrame event")
        }
    }

    // MARK: - SessionUpdateBuilder

    func testSessionUpdateBuilderEmptyReturnsNil() {
        let builder = SessionUpdateBuilder()
        XCTAssertNil(builder.build())
    }

    func testSessionUpdateBuilderWithVoice() {
        var builder = SessionUpdateBuilder()
        builder.voice(.matthew)
        let update = builder.build()
        XCTAssertNotNil(update)
        XCTAssertEqual(update?.fields["voiceId"] as? String, "matthew")
    }

    func testSessionUpdateBuilderWithMultipleFields() {
        var builder = SessionUpdateBuilder()
        builder.voice(.tiffany)
        builder.systemPrompt("Be concise")
        builder.temperature(0.5)
        builder.topP(0.8)
        let update = builder.build()
        XCTAssertNotNil(update)
        XCTAssertEqual(update?.fields["voiceId"] as? String, "tiffany")
        XCTAssertEqual(update?.fields["systemPrompt"] as? String, "Be concise")
        XCTAssertEqual(update?.fields["temperature"] as? Double, 0.5)
        XCTAssertEqual(update?.fields["topP"] as? Double, 0.8)
    }

    func testSessionUpdateToJSONData() {
        var builder = SessionUpdateBuilder()
        builder.voice(.amy)
        guard let update = builder.build() else {
            XCTFail("Expected non-nil update")
            return
        }
        guard let data = update.toJSONData() else {
            XCTFail("Expected non-nil JSON data")
            return
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Expected valid JSON")
            return
        }
        XCTAssertEqual(json["type"] as? String, "session.update")
        let session = json["session"] as? [String: Any]
        XCTAssertEqual(session?["voiceId"] as? String, "amy")
    }

    // MARK: - WebSocket disconnect

    func testDisconnectSetsStateToDisconnected() async {
        let manager = WebSocketStreamManager()
        await manager.disconnect()
        if case .disconnected = manager.connectionState {
            // expected
        } else {
            XCTFail("Expected disconnected after disconnect()")
        }
    }

    // MARK: - Connect requires WebSocket mode

    func testConnectWithBedrockModeThrows() async {
        let manager = WebSocketStreamManager()
        let config = NovaSonicConfiguration()
        do {
            try await manager.connect(configuration: config)
            XCTFail("Expected error when connecting with bedrockSDK mode")
        } catch let error as NovaSonicError {
            if case .invalidConfiguration = error {
                // expected
            } else {
                XCTFail("Expected invalidConfiguration, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
