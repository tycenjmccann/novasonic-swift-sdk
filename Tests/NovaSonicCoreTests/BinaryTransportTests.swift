import XCTest
@testable import NovaSonicCore

final class BinaryTransportTests: XCTestCase {

    // MARK: - AudioTransportMode enum

    func testAudioTransportModeRawValues() {
        XCTAssertEqual(AudioTransportMode.json.rawValue, "json")
        XCTAssertEqual(AudioTransportMode.binary.rawValue, "binary")
    }

    func testAudioTransportModeIsCaseIterable() {
        let allCases = AudioTransportMode.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.json))
        XCTAssertTrue(allCases.contains(.binary))
    }

    // MARK: - Configuration defaults

    func testDefaultConfigUsesJsonTransport() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.inputTransport, .json)
        XCTAssertEqual(config.outputTransport, .json)
    }

    func testBinaryTransportConfigAccepted() {
        let config = NovaSonicConfiguration(
            inputTransport: .binary,
            outputTransport: .binary
        )
        XCTAssertEqual(config.inputTransport, .binary)
        XCTAssertEqual(config.outputTransport, .binary)
        XCTAssertNoThrow(try config.validate())
    }

    func testMixedTransportConfigAccepted() {
        let config = NovaSonicConfiguration(
            inputTransport: .binary,
            outputTransport: .json
        )
        XCTAssertEqual(config.inputTransport, .binary)
        XCTAssertEqual(config.outputTransport, .json)
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - promptStartEvent payload

    func testPromptStartEventJsonTransportHasBase64Encoding() {
        let json = BedrockEvents.promptStartEvent(
            promptName: "test-prompt",
            voiceId: "tiffany",
            outputSampleRate: 24000,
            outputTransport: .json
        )
        let parsed = parseJSON(json)
        let audioConfig = extractAudioOutputConfig(from: parsed)

        XCTAssertEqual(audioConfig?["encoding"] as? String, "base64")
        XCTAssertEqual(audioConfig?["transport"] as? String, "json")
    }

    func testPromptStartEventBinaryTransportHasRawEncoding() {
        let json = BedrockEvents.promptStartEvent(
            promptName: "test-prompt",
            voiceId: "tiffany",
            outputSampleRate: 24000,
            outputTransport: .binary
        )
        let parsed = parseJSON(json)
        let audioConfig = extractAudioOutputConfig(from: parsed)

        XCTAssertEqual(audioConfig?["encoding"] as? String, "raw")
        XCTAssertEqual(audioConfig?["transport"] as? String, "binary")
    }

    // MARK: - audioContentStartEvent payload

    func testAudioContentStartEventJsonTransport() {
        let json = BedrockEvents.audioContentStartEvent(
            promptName: "test-prompt",
            audioContentName: "audio-1",
            inputSampleRate: 16000,
            inputTransport: .json
        )
        let parsed = parseJSON(json)
        let audioInputConfig = extractAudioInputConfig(from: parsed)

        XCTAssertEqual(audioInputConfig?["encoding"] as? String, "base64")
        XCTAssertEqual(audioInputConfig?["transport"] as? String, "json")
    }

    func testAudioContentStartEventBinaryTransport() {
        let json = BedrockEvents.audioContentStartEvent(
            promptName: "test-prompt",
            audioContentName: "audio-1",
            inputSampleRate: 16000,
            inputTransport: .binary
        )
        let parsed = parseJSON(json)
        let audioInputConfig = extractAudioInputConfig(from: parsed)

        XCTAssertEqual(audioInputConfig?["encoding"] as? String, "raw")
        XCTAssertEqual(audioInputConfig?["transport"] as? String, "binary")
    }

    // MARK: - binaryAudioInputData passthrough

    func testBinaryAudioInputDataPassthrough() {
        let samplePCM = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0x80, 0x7F, 0x00])
        let result = BedrockEvents.binaryAudioInputData(audioData: samplePCM)
        XCTAssertEqual(result, samplePCM, "Binary passthrough must not modify data")
        XCTAssertEqual(result.count, samplePCM.count, "Binary passthrough must not expand data size")
    }

    func testBinaryAudioInputDataNoBase64Expansion() {
        let largeAudio = Data(repeating: 0xAB, count: 1024)
        let result = BedrockEvents.binaryAudioInputData(audioData: largeAudio)
        XCTAssertEqual(result.count, 1024, "Binary mode must not base64-expand the data")
    }

    // MARK: - JSON audioInputEvent unchanged

    func testJsonAudioInputEventStillWorks() {
        let audioData = Data([0x01, 0x02, 0x03, 0x04])
        let json = BedrockEvents.audioInputEvent(
            audioData: audioData,
            promptName: "test-prompt",
            audioContentName: "audio-1"
        )
        let parsed = parseJSON(json)
        let event = parsed?["event"] as? [String: Any]
        let audioInput = event?["audioInput"] as? [String: Any]

        XCTAssertNotNil(audioInput)
        XCTAssertEqual(audioInput?["promptName"] as? String, "test-prompt")
        XCTAssertEqual(audioInput?["contentName"] as? String, "audio-1")

        let content = audioInput?["content"] as? String
        XCTAssertNotNil(content)
        XCTAssertEqual(content, audioData.base64EncodedString())
    }

    // MARK: - Binary frame detection logic

    func testNonJsonBytesNotParsedAsJson() {
        let rawPCM = Data([0x80, 0x00, 0x7F, 0xFF, 0x01, 0x02])
        let jsonString = String(decoding: rawPCM, as: UTF8.self)
        let jsonData = jsonString.data(using: .utf8)

        let parsed: Any?
        if let data = jsonData {
            parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } else {
            parsed = nil
        }

        XCTAssertNil(parsed, "Raw PCM bytes must not parse as valid JSON")
    }

    func testValidJsonStillParses() {
        let validEvent = """
        {"event":{"textOutput":{"content":"hello","role":"ASSISTANT"}}}
        """
        let bytes = Data(validEvent.utf8)
        let jsonString = String(decoding: bytes, as: UTF8.self)
        guard let jsonData = jsonString.data(using: .utf8),
              let topLevel = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let event = topLevel["event"] as? [String: Any] else {
            XCTFail("Valid JSON event must parse successfully")
            return
        }

        XCTAssertNotNil(event["textOutput"])
    }

    // MARK: - Helpers

    private func parseJSON(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func extractAudioOutputConfig(from json: [String: Any]?) -> [String: Any]? {
        let event = json?["event"] as? [String: Any]
        let promptStart = event?["promptStart"] as? [String: Any]
        return promptStart?["audioOutputConfiguration"] as? [String: Any]
    }

    private func extractAudioInputConfig(from json: [String: Any]?) -> [String: Any]? {
        let event = json?["event"] as? [String: Any]
        let contentStart = event?["contentStart"] as? [String: Any]
        return contentStart?["audioInputConfiguration"] as? [String: Any]
    }
}
