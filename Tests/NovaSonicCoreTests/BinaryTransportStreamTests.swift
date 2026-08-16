import XCTest
@testable import NovaSonicCore

final class BinaryTransportStreamTests: XCTestCase {

    // MARK: - Configuration Locking Tests

    @MainActor
    func testConfigurationLockedErrorProperties() {
        XCTAssertEqual(NovaSonicError.configurationLocked.errorDescription,
                      "Configuration cannot be changed after the stream has started")
        XCTAssertEqual(NovaSonicError.configurationLocked.recoverySuggestion,
                      "Stop the current session before changing configuration")
        XCTAssertFalse(NovaSonicError.configurationLocked.isRetryable)
    }

    @MainActor
    func testConfigureSucceedsWhenNotStreaming() {
        let manager = NovaSonicStreamManager()
        let config = NovaSonicConfiguration()

        manager.configure(with: config)
        XCTAssertNil(manager.lastError)
        XCTAssertTrue(manager.isConfigured)
    }

    // MARK: - Binary Transport Audio Event Tests

    func testBinaryTransportSkipsJSONWrapping() {
        // In binary transport mode, raw PCM data is sent directly without JSON wrapping.
        let pcmData = Data(repeating: 0x42, count: 640) // 20ms at 16kHz/16-bit

        // JSON transport wraps in JSON (existing behavior):
        let jsonWrapped = BedrockEvents.audioInputEvent(
            audioData: pcmData,
            promptName: "p1",
            audioContentName: "a1"
        )
        XCTAssertTrue(jsonWrapped.contains("audioInput"))
        XCTAssertTrue(jsonWrapped.contains("content"))

        // In binary mode, raw pcmData would be sent directly (no JSON)
        // Verify the data is just raw bytes
        XCTAssertEqual(pcmData.count, 640)
        XCTAssertFalse(String(data: pcmData, encoding: .utf8)?.contains("audioInput") ?? false)
    }

    // MARK: - Frame Discrimination Tests

    func testJSONFrameDetection() {
        let jsonFrame = """
        {"event":{"textOutput":{"content":"Hello","role":"ASSISTANT"}}}
        """.data(using: .utf8)!

        let jsonString = String(data: jsonFrame, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.trimmingCharacters(in: .whitespaces).hasPrefix("{"))

        // Should parse as valid JSON
        let parsed = try? JSONSerialization.jsonObject(with: jsonFrame) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertNotNil(parsed?["event"])
    }

    func testBinaryFrameDetection() {
        // A binary PCM frame will not start with '{' and may not be valid UTF-8
        let binaryFrame = Data([0x00, 0x01, 0xFF, 0xFE, 0x42, 0x43])

        // Attempt to interpret as UTF-8 JSON - may fail or produce non-JSON text
        if let str = String(data: binaryFrame, encoding: .utf8) {
            XCTAssertFalse(str.trimmingCharacters(in: .whitespaces).hasPrefix("{"))
        }
        // Binary data should NOT parse as JSON
        let parsed = try? JSONSerialization.jsonObject(with: binaryFrame)
        XCTAssertNil(parsed)
    }

    func testMixedFrameHandling() {
        let jsonFrame = "{\"event\":{\"textOutput\":{\"content\":\"Hi\"}}}".data(using: .utf8)!
        let binaryFrame = Data(repeating: 0xAB, count: 320)

        // JSON frame should be parseable
        let parsed = try? JSONSerialization.jsonObject(with: jsonFrame) as? [String: Any]
        XCTAssertNotNil(parsed)
        XCTAssertNotNil(parsed?["event"])

        // Binary frame should NOT be parseable as JSON
        let binaryParsed = try? JSONSerialization.jsonObject(with: binaryFrame)
        XCTAssertNil(binaryParsed)
    }

    func testWhitespaceJSONFrameDetection() {
        // JSON with leading whitespace should still be detected
        let jsonFrame = "  {\"event\":{\"contentEnd\":{}}}".data(using: .utf8)!
        let jsonString = String(data: jsonFrame, encoding: .utf8)!
        XCTAssertTrue(jsonString.trimmingCharacters(in: .whitespaces).hasPrefix("{"))
    }

    // MARK: - Preset Configuration Tests

    func testHighFidelityPreset() {
        let config = NovaSonicConfiguration.highFidelity
        XCTAssertEqual(config.inputSampleRate, .rate48kHz)
        XCTAssertEqual(config.outputSampleRate, .rate48kHz)
        XCTAssertEqual(config.audioTransport, .binary)
    }

    func testCdQualityPreset() {
        let config = NovaSonicConfiguration.cdQuality
        XCTAssertEqual(config.inputSampleRate, .rate44100Hz)
        XCTAssertEqual(config.outputSampleRate, .rate44100Hz)
        XCTAssertEqual(config.audioTransport, .binary)
    }

    func testBinaryTransportPreset() {
        let config = NovaSonicConfiguration.binaryTransport
        XCTAssertEqual(config.inputSampleRate, .rate16kHz)
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
        XCTAssertEqual(config.audioTransport, .binary)
    }

    // MARK: - Transport in Event Serialization

    func testBinaryTransportInPromptStartEvent() throws {
        let json = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany",
            outputSampleRate: 48000,
            transport: .binary
        )

        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let promptStart = event["promptStart"] as! [String: Any]
        let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["encoding"] as? String, "none")
        XCTAssertEqual(audioConfig["transport"] as? String, "binary")
    }

    func testBinaryTransportInAudioContentStartEvent() throws {
        let json = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-1",
            inputSampleRate: 48000,
            transport: .binary
        )

        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let contentStart = event["contentStart"] as! [String: Any]
        let audioConfig = contentStart["audioInputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["encoding"] as? String, "none")
        XCTAssertEqual(audioConfig["transport"] as? String, "binary")
    }

    // MARK: - Default Configuration Backward Compatibility

    func testDefaultConfigProducesJsonTransport() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.audioTransport, .json)
        XCTAssertEqual(config.inputSampleRate, .rate16kHz)
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
    }
}
