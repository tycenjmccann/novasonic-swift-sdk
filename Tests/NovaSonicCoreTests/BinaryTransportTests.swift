import XCTest
@testable import NovaSonicCore

/// Tests for binary WebSocket transport mode and sample rate propagation.
final class BinaryTransportTests: XCTestCase {

    // MARK: - AudioTransport Enum Tests

    func testAudioTransportRawValues() {
        XCTAssertEqual(AudioTransport.json.rawValue, "json")
        XCTAssertEqual(AudioTransport.binary.rawValue, "binary")
    }

    func testAudioTransportCaseIterable() {
        XCTAssertEqual(AudioTransport.allCases.count, 2)
        XCTAssertTrue(AudioTransport.allCases.contains(.json))
        XCTAssertTrue(AudioTransport.allCases.contains(.binary))
    }

    func testAudioTransportCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let original = AudioTransport.binary
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AudioTransport.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Configuration Defaults

    func testDefaultTransportIsJson() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.inputTransport, .json)
        XCTAssertEqual(config.outputTransport, .json)
    }

    func testBinaryTransportConfigurable() {
        let config = NovaSonicConfiguration(inputTransport: .binary, outputTransport: .binary)
        XCTAssertEqual(config.inputTransport, .binary)
        XCTAssertEqual(config.outputTransport, .binary)
    }

    func testMixedTransportConfigurable() {
        let config = NovaSonicConfiguration(inputTransport: .binary, outputTransport: .json)
        XCTAssertEqual(config.inputTransport, .binary)
        XCTAssertEqual(config.outputTransport, .json)
    }

    // MARK: - BedrockEvents Transport Field Tests

    func testPromptStartEventContainsJsonTransport() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test-prompt", voiceId: "tiffany",
            outputSampleRate: 24000, outputTransport: "json"
        )
        XCTAssertTrue(event.contains("\"transport\""))
        XCTAssertTrue(event.contains("json"))
    }

    func testPromptStartEventContainsBinaryTransport() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test-prompt", voiceId: "tiffany",
            outputSampleRate: 24000, outputTransport: "binary"
        )
        XCTAssertTrue(event.contains("\"transport\""))
        XCTAssertTrue(event.contains("binary"))
    }

    func testAudioContentStartEventContainsJsonTransport() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test-prompt", audioContentName: "audio-1",
            inputSampleRate: 16000, inputTransport: "json"
        )
        XCTAssertTrue(event.contains("\"transport\""))
        XCTAssertTrue(event.contains("json"))
    }

    func testAudioContentStartEventContainsBinaryTransport() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test-prompt", audioContentName: "audio-1",
            inputSampleRate: 16000, inputTransport: "binary"
        )
        XCTAssertTrue(event.contains("\"transport\""))
        XCTAssertTrue(event.contains("binary"))
    }

    // MARK: - Binary Audio Data Passthrough

    func testBinaryAudioInputDataPassesThrough() {
        let originalData = Data([0x01, 0x02, 0x03, 0x04, 0xFF, 0xFE])
        let result = BedrockEvents.binaryAudioInputData(audioData: originalData)
        XCTAssertEqual(result, originalData)
    }

    func testBinaryAudioInputDataPreservesLength() {
        let pcmData = Data(repeating: 0xAB, count: 1024)
        let result = BedrockEvents.binaryAudioInputData(audioData: pcmData)
        XCTAssertEqual(result.count, 1024)
    }

    // MARK: - JSON Transport Backward Compatibility

    func testJsonAudioInputEventUnchanged() {
        let audioData = Data([0x00, 0x01, 0x02, 0x03])
        let event = BedrockEvents.audioInputEvent(
            audioData: audioData, promptName: "test", audioContentName: "audio-1"
        )
        let expectedBase64 = audioData.base64EncodedString()
        XCTAssertTrue(event.contains(expectedBase64))
        XCTAssertTrue(event.contains("\"event\""))
        XCTAssertTrue(event.contains("\"audioInput\""))
    }

    func testPromptStartEventDefaultTransportIsJson() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test", voiceId: "tiffany", outputSampleRate: 24000
        )
        XCTAssertTrue(event.contains("\"transport\""))
    }

    func testAudioContentStartEventDefaultTransportIsJson() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test", audioContentName: "audio-1", inputSampleRate: 16000
        )
        XCTAssertTrue(event.contains("\"transport\""))
    }

    // MARK: - Sample Rate Propagation Tests

    func testSampleRate16kHzInAudioContentStart() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "t", audioContentName: "a", inputSampleRate: 16000
        )
        XCTAssertTrue(event.contains("16000"))
    }

    func testSampleRate24kHzInAudioContentStart() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "t", audioContentName: "a", inputSampleRate: 24000
        )
        XCTAssertTrue(event.contains("24000"))
    }

    func testSampleRate8kHzInAudioContentStart() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "t", audioContentName: "a", inputSampleRate: 8000
        )
        XCTAssertTrue(event.contains("8000"))
    }

    func testSampleRate16kHzInPromptStart() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "t", voiceId: "tiffany", outputSampleRate: 16000
        )
        XCTAssertTrue(event.contains("16000"))
    }

    func testSampleRate24kHzInPromptStart() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "t", voiceId: "tiffany", outputSampleRate: 24000
        )
        XCTAssertTrue(event.contains("24000"))
    }

    func testSampleRate8kHzInPromptStart() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "t", voiceId: "tiffany", outputSampleRate: 8000
        )
        XCTAssertTrue(event.contains("8000"))
    }

    // MARK: - Configuration Sample Rate Values

    func testSampleRateHertzValues() {
        XCTAssertEqual(NovaSonicSampleRate.rate8kHz.hertz, 8000)
        XCTAssertEqual(NovaSonicSampleRate.rate16kHz.hertz, 16000)
        XCTAssertEqual(NovaSonicSampleRate.rate24kHz.hertz, 24000)
    }

    func testConfigPreservesSampleRates() {
        let config = NovaSonicConfiguration(
            inputSampleRate: .rate16kHz, outputSampleRate: .rate24kHz
        )
        XCTAssertEqual(config.inputSampleRate, .rate16kHz)
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
    }

    func testConfigCustomSampleRates() {
        let config = NovaSonicConfiguration(
            inputSampleRate: .rate8kHz, outputSampleRate: .rate8kHz
        )
        XCTAssertEqual(config.inputSampleRate.hertz, 8000)
        XCTAssertEqual(config.outputSampleRate.hertz, 8000)
    }

    // MARK: - Event JSON Structure Validation

    func testPromptStartJsonStructure() throws {
        let event = BedrockEvents.promptStartEvent(
            promptName: "p", voiceId: "matthew",
            outputSampleRate: 16000, outputTransport: "binary"
        )
        let data = event.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let ev = json["event"] as! [String: Any]
        let ps = ev["promptStart"] as! [String: Any]
        let ac = ps["audioOutputConfiguration"] as! [String: Any]
        XCTAssertEqual(ac["mediaType"] as? String, "audio/lpcm")
        XCTAssertEqual(ac["sampleRateHertz"] as? Int, 16000)
        XCTAssertEqual(ac["sampleSizeBits"] as? Int, 16)
        XCTAssertEqual(ac["channelCount"] as? Int, 1)
        XCTAssertEqual(ac["transport"] as? String, "binary")
        XCTAssertEqual(ac["voiceId"] as? String, "matthew")
    }

    func testAudioContentStartJsonStructure() throws {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "p", audioContentName: "a",
            inputSampleRate: 24000, inputTransport: "binary"
        )
        let data = event.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let ev = json["event"] as! [String: Any]
        let cs = ev["contentStart"] as! [String: Any]
        let ac = cs["audioInputConfiguration"] as! [String: Any]
        XCTAssertEqual(ac["mediaType"] as? String, "audio/lpcm")
        XCTAssertEqual(ac["sampleRateHertz"] as? Int, 24000)
        XCTAssertEqual(ac["sampleSizeBits"] as? Int, 16)
        XCTAssertEqual(ac["channelCount"] as? Int, 1)
        XCTAssertEqual(ac["transport"] as? String, "binary")
    }

    // MARK: - Preset Configurations

    func testDefaultPresetHasJsonTransport() {
        let config = NovaSonicConfiguration.default
        XCTAssertEqual(config.inputTransport, .json)
        XCTAssertEqual(config.outputTransport, .json)
    }

    func testMaxQualityPresetHasJsonTransport() {
        let config = NovaSonicConfiguration.maxQuality
        XCTAssertEqual(config.inputTransport, .json)
        XCTAssertEqual(config.outputTransport, .json)
    }

    func testLowBandwidthPresetHasJsonTransport() {
        let config = NovaSonicConfiguration.lowBandwidth
        XCTAssertEqual(config.inputTransport, .json)
        XCTAssertEqual(config.outputTransport, .json)
    }

    // MARK: - Validation with Transport

    func testValidationPassesWithBinaryTransport() {
        let config = NovaSonicConfiguration(inputTransport: .binary, outputTransport: .binary)
        XCTAssertNoThrow(try config.validate())
    }

    func testValidationPassesWithJsonTransport() {
        let config = NovaSonicConfiguration(inputTransport: .json, outputTransport: .json)
        XCTAssertNoThrow(try config.validate())
    }

    func testPromptStartEventJsonTransportHasBase64Encoding() throws {
        let event = BedrockEvents.promptStartEvent(promptName: "test-prompt", voiceId: "tiffany", outputSampleRate: 24000, outputTransport: "json")
        let data = event.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let ev = json["event"] as! [String: Any]
        let ps = ev["promptStart"] as! [String: Any]
        let ac = ps["audioOutputConfiguration"] as! [String: Any]
        XCTAssertEqual(ac["encoding"] as? String, "base64")
    }

    func testPromptStartEventBinaryTransportHasRawEncoding() throws {
        let event = BedrockEvents.promptStartEvent(promptName: "test-prompt", voiceId: "tiffany", outputSampleRate: 24000, outputTransport: "binary")
        let data = event.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let ev = json["event"] as! [String: Any]
        let ps = ev["promptStart"] as! [String: Any]
        let ac = ps["audioOutputConfiguration"] as! [String: Any]
        XCTAssertEqual(ac["encoding"] as? String, "raw")
    }

    func testAudioContentStartEventJsonTransportHasBase64Encoding() throws {
        let event = BedrockEvents.audioContentStartEvent(promptName: "test-prompt", audioContentName: "audio-1", inputSampleRate: 16000, inputTransport: "json")
        let data = event.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let ev = json["event"] as! [String: Any]
        let cs = ev["contentStart"] as! [String: Any]
        let ac = cs["audioInputConfiguration"] as! [String: Any]
        XCTAssertEqual(ac["encoding"] as? String, "base64")
    }

    func testAudioContentStartEventBinaryTransportHasRawEncoding() throws {
        let event = BedrockEvents.audioContentStartEvent(promptName: "test-prompt", audioContentName: "audio-1", inputSampleRate: 16000, inputTransport: "binary")
        let data = event.data(using: .utf8)!
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let ev = json["event"] as! [String: Any]
        let cs = ev["contentStart"] as! [String: Any]
        let ac = cs["audioInputConfiguration"] as! [String: Any]
        XCTAssertEqual(ac["encoding"] as? String, "raw")
    }
}
