import XCTest
@testable import NovaSonicCore

/// Regression tests for binary transport mode (TEAM-2365).
/// These tests verify:
/// 1. AudioTransport enum exists and defaults to .json
/// 2. BedrockEvents.audioInputEvent() base64-encodes in JSON mode
/// 3. Binary send path sends raw Data without base64 wrapping
/// 4. promptStartEvent() and audioContentStartEvent() conditionally set encoding
/// 5. Sample rate is configurable (already works, verified here)
final class AudioTransportTests: XCTestCase {

    // MARK: - AudioTransport Enum

    func testAudioTransportEnumExists() {
        // AudioTransport enum must exist with .json and .binary cases
        let json = AudioTransport.json
        let binary = AudioTransport.binary
        XCTAssertEqual(json.rawValue, "json")
        XCTAssertEqual(binary.rawValue, "binary")
    }

    func testAudioTransportDefaultsToJson() {
        // Default configuration must use .json transport
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.audioInputTransport, .json)
        XCTAssertEqual(config.audioOutputTransport, .json)
    }

    func testAudioTransportCanBeSetToBinary() {
        let config = NovaSonicConfiguration(
            audioInputTransport: .binary,
            audioOutputTransport: .binary
        )
        XCTAssertEqual(config.audioInputTransport, .binary)
        XCTAssertEqual(config.audioOutputTransport, .binary)
    }

    func testAudioTransportCanBeMixed() {
        // Input binary, output JSON (or vice versa)
        let config = NovaSonicConfiguration(
            audioInputTransport: .binary,
            audioOutputTransport: .json
        )
        XCTAssertEqual(config.audioInputTransport, .binary)
        XCTAssertEqual(config.audioOutputTransport, .json)
    }

    // MARK: - BedrockEvents JSON Mode (existing behavior preserved)

    func testAudioInputEventBase64EncodesInJsonMode() {
        // audioInputEvent() must base64-encode audio data in JSON
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let event = BedrockEvents.audioInputEvent(
            audioData: testData,
            promptName: "test-prompt",
            audioContentName: "test-audio"
        )

        // Verify it's valid JSON
        let jsonData = event.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let eventDict = parsed["event"] as! [String: Any]
        let audioInput = eventDict["audioInput"] as! [String: Any]

        // Verify content is base64-encoded
        let content = audioInput["content"] as! String
        let expectedBase64 = testData.base64EncodedString()
        XCTAssertEqual(content, expectedBase64)

        // Verify prompt and content names are correct
        XCTAssertEqual(audioInput["promptName"] as! String, "test-prompt")
        XCTAssertEqual(audioInput["contentName"] as! String, "test-audio")
    }

    // MARK: - Binary Send Path

    func testBinaryAudioInputDataReturnsRawData() {
        // binaryAudioInputData() must return raw Data without any encoding
        let testData = Data([0xFF, 0xFE, 0x00, 0x01, 0x80, 0x7F])
        let result = BedrockEvents.binaryAudioInputData(audioData: testData)

        // Must be byte-for-byte identical — no base64, no JSON wrapping
        XCTAssertEqual(result, testData)
        XCTAssertEqual(result.count, testData.count)

        // Verify it's NOT base64 (would be longer) and NOT JSON (wouldn't start with 0xFF)
        XCTAssertNotEqual(result.count, testData.base64EncodedData().count)
    }

    func testBinaryAudioInputDataPreservesLargePayload() {
        // Simulate a realistic audio chunk (e.g., 3200 bytes of 16-bit PCM at 16kHz = 100ms)
        let chunkSize = 3200
        var audioChunk = Data(count: chunkSize)
        for i in 0..<chunkSize {
            audioChunk[i] = UInt8(i % 256)
        }

        let result = BedrockEvents.binaryAudioInputData(audioData: audioChunk)
        XCTAssertEqual(result.count, chunkSize)
        XCTAssertEqual(result, audioChunk)
    }

    // MARK: - promptStartEvent Conditional Encoding

    func testPromptStartEventSetsBase64EncodingForJsonTransport() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany",
            outputSampleRate: 24000,
            audioOutputTransport: .json
        )

        let parsed = parseJSON(event)
        let promptStart = ((parsed["event"] as! [String: Any])["promptStart"] as! [String: Any])
        let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["encoding"] as! String, "base64")
        XCTAssertEqual(audioConfig["sampleRateHertz"] as! Int, 24000)
        XCTAssertEqual(audioConfig["voiceId"] as! String, "tiffany")
    }

    func testPromptStartEventSetsNoneEncodingForBinaryTransport() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "matthew",
            outputSampleRate: 16000,
            audioOutputTransport: .binary
        )

        let parsed = parseJSON(event)
        let promptStart = ((parsed["event"] as! [String: Any])["promptStart"] as! [String: Any])
        let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["encoding"] as! String, "none")
        XCTAssertEqual(audioConfig["sampleRateHertz"] as! Int, 16000)
        XCTAssertEqual(audioConfig["voiceId"] as! String, "matthew")
    }

    func testPromptStartEventDefaultsToJsonTransport() {
        // Without explicit transport parameter, must default to base64 (backward compat)
        let event = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany",
            outputSampleRate: 24000
        )

        let parsed = parseJSON(event)
        let promptStart = ((parsed["event"] as! [String: Any])["promptStart"] as! [String: Any])
        let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["encoding"] as! String, "base64")
    }

    // MARK: - audioContentStartEvent Conditional Encoding

    func testAudioContentStartEventSetsBase64ForJsonTransport() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-1",
            inputSampleRate: 16000,
            audioInputTransport: .json
        )

        let parsed = parseJSON(event)
        let contentStart = ((parsed["event"] as! [String: Any])["contentStart"] as! [String: Any])
        let audioConfig = contentStart["audioInputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["encoding"] as! String, "base64")
        XCTAssertEqual(audioConfig["sampleRateHertz"] as! Int, 16000)
        XCTAssertEqual(audioConfig["mediaType"] as! String, "audio/lpcm")
    }

    func testAudioContentStartEventSetsNoneForBinaryTransport() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-1",
            inputSampleRate: 24000,
            audioInputTransport: .binary
        )

        let parsed = parseJSON(event)
        let contentStart = ((parsed["event"] as! [String: Any])["contentStart"] as! [String: Any])
        let audioConfig = contentStart["audioInputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["encoding"] as! String, "none")
        XCTAssertEqual(audioConfig["sampleRateHertz"] as! Int, 24000)
    }

    func testAudioContentStartEventDefaultsToJsonTransport() {
        // Without explicit transport, must use base64 (backward compat)
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-1",
            inputSampleRate: 16000
        )

        let parsed = parseJSON(event)
        let contentStart = ((parsed["event"] as! [String: Any])["contentStart"] as! [String: Any])
        let audioConfig = contentStart["audioInputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["encoding"] as! String, "base64")
    }

    // MARK: - Sample Rate Configuration (verify existing behavior)

    func testSampleRateIsConfigurable() {
        let config8k = NovaSonicConfiguration(inputSampleRate: .rate8kHz, outputSampleRate: .rate8kHz)
        XCTAssertEqual(config8k.inputSampleRate.hertz, 8000)
        XCTAssertEqual(config8k.outputSampleRate.hertz, 8000)

        let config16k = NovaSonicConfiguration(inputSampleRate: .rate16kHz, outputSampleRate: .rate16kHz)
        XCTAssertEqual(config16k.inputSampleRate.hertz, 16000)
        XCTAssertEqual(config16k.outputSampleRate.hertz, 16000)

        let config24k = NovaSonicConfiguration(inputSampleRate: .rate24kHz, outputSampleRate: .rate24kHz)
        XCTAssertEqual(config24k.inputSampleRate.hertz, 24000)
        XCTAssertEqual(config24k.outputSampleRate.hertz, 24000)
    }

    func testSampleRatePassedToPromptStartEvent() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany",
            outputSampleRate: 8000
        )

        let parsed = parseJSON(event)
        let promptStart = ((parsed["event"] as! [String: Any])["promptStart"] as! [String: Any])
        let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["sampleRateHertz"] as! Int, 8000)
    }

    func testSampleRatePassedToAudioContentStartEvent() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-1",
            inputSampleRate: 24000
        )

        let parsed = parseJSON(event)
        let contentStart = ((parsed["event"] as! [String: Any])["contentStart"] as! [String: Any])
        let audioConfig = contentStart["audioInputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["sampleRateHertz"] as! Int, 24000)
    }

    // MARK: - AudioTransport Codable

    func testAudioTransportIsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let jsonData = try encoder.encode(AudioTransport.json)
        let decoded = try decoder.decode(AudioTransport.self, from: jsonData)
        XCTAssertEqual(decoded, .json)

        let binaryData = try encoder.encode(AudioTransport.binary)
        let decodedBinary = try decoder.decode(AudioTransport.self, from: binaryData)
        XCTAssertEqual(decodedBinary, .binary)
    }

    // MARK: - Backward Compatibility

    func testDefaultConfigurationIsFullyBackwardCompatible() {
        // A default config must produce identical behavior to pre-transport code
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.audioInputTransport, .json)
        XCTAssertEqual(config.audioOutputTransport, .json)
        XCTAssertEqual(config.inputSampleRate, .rate16kHz)
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
    }

    func testPresetConfigurationsPreserveJsonTransport() {
        // All presets must default to JSON transport
        XCTAssertEqual(NovaSonicConfiguration.default.audioInputTransport, .json)
        XCTAssertEqual(NovaSonicConfiguration.default.audioOutputTransport, .json)
        XCTAssertEqual(NovaSonicConfiguration.maxQuality.audioInputTransport, .json)
        XCTAssertEqual(NovaSonicConfiguration.maxQuality.audioOutputTransport, .json)
        XCTAssertEqual(NovaSonicConfiguration.lowBandwidth.audioInputTransport, .json)
        XCTAssertEqual(NovaSonicConfiguration.lowBandwidth.audioOutputTransport, .json)
    }

    // MARK: - Helpers

    private func parseJSON(_ jsonString: String) -> [String: Any] {
        let data = jsonString.data(using: .utf8)!
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
