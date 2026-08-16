import XCTest
@testable import NovaSonicCore

final class BedrockEventsEncodingTests: XCTestCase {

    // MARK: - Helpers

    private func parseJSON(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj
    }

    private func audioOutputConfig(from json: [String: Any]) -> [String: Any]? {
        let event = json["event"] as? [String: Any]
        let promptStart = event?["promptStart"] as? [String: Any]
        return promptStart?["audioOutputConfiguration"] as? [String: Any]
    }

    private func audioInputConfig(from json: [String: Any]) -> [String: Any]? {
        let event = json["event"] as? [String: Any]
        let contentStart = event?["contentStart"] as? [String: Any]
        return contentStart?["audioInputConfiguration"] as? [String: Any]
    }

    // MARK: - promptStartEvent tests

    func testPromptStartEvent_defaultTransport_encodingBase64_noTransportField() {
        let result = BedrockEvents.promptStartEvent(promptName: "p1", voiceId: "matthew")
        let json = parseJSON(result)!
        let config = audioOutputConfig(from: json)!

        XCTAssertEqual(config["encoding"] as? String, "base64")
        XCTAssertNil(config["transport"])
    }

    func testPromptStartEvent_binaryTransport_encodingNone_transportBinary() {
        let result = BedrockEvents.promptStartEvent(promptName: "p1", voiceId: "matthew", outputTransport: "binary")
        let json = parseJSON(result)!
        let config = audioOutputConfig(from: json)!

        XCTAssertEqual(config["encoding"] as? String, "none")
        XCTAssertEqual(config["transport"] as? String, "binary")
    }

    func testPromptStartEvent_websocketTransport_encodingBase64_transportWebsocket() {
        let result = BedrockEvents.promptStartEvent(promptName: "p1", voiceId: "matthew", outputTransport: "websocket")
        let json = parseJSON(result)!
        let config = audioOutputConfig(from: json)!

        XCTAssertEqual(config["encoding"] as? String, "base64")
        XCTAssertEqual(config["transport"] as? String, "websocket")
    }

    // MARK: - audioContentStartEvent tests

    func testAudioContentStartEvent_defaultTransport_encodingBase64_noTransportField() {
        let result = BedrockEvents.audioContentStartEvent(promptName: "p1", audioContentName: "a1")
        let json = parseJSON(result)!
        let config = audioInputConfig(from: json)!

        XCTAssertEqual(config["encoding"] as? String, "base64")
        XCTAssertNil(config["transport"])
    }

    func testAudioContentStartEvent_binaryTransport_encodingNone_transportBinary() {
        let result = BedrockEvents.audioContentStartEvent(promptName: "p1", audioContentName: "a1", inputTransport: "binary")
        let json = parseJSON(result)!
        let config = audioInputConfig(from: json)!

        XCTAssertEqual(config["encoding"] as? String, "none")
        XCTAssertEqual(config["transport"] as? String, "binary")
    }

    func testAudioContentStartEvent_websocketTransport_encodingBase64_transportWebsocket() {
        let result = BedrockEvents.audioContentStartEvent(promptName: "p1", audioContentName: "a1", inputTransport: "websocket")
        let json = parseJSON(result)!
        let config = audioInputConfig(from: json)!

        XCTAssertEqual(config["encoding"] as? String, "base64")
        XCTAssertEqual(config["transport"] as? String, "websocket")
    }
}
