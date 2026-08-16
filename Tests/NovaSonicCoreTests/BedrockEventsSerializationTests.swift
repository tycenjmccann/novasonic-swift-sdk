import XCTest
@testable import NovaSonicCore

final class BedrockEventsSerializationTests: XCTestCase {

    // MARK: - promptStartEvent Tests

    func testPromptStartEventDefaultTransport() throws {
        let json = BedrockEvents.promptStartEvent(
            promptName: "test-prompt",
            voiceId: "tiffany",
            outputSampleRate: 24000
        )

        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let promptStart = event["promptStart"] as! [String: Any]
        let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["sampleRateHertz"] as? Int, 24000)
        XCTAssertEqual(audioConfig["encoding"] as? String, "base64")
        XCTAssertEqual(audioConfig["transport"] as? String, "json")
        XCTAssertEqual(audioConfig["voiceId"] as? String, "tiffany")
        XCTAssertEqual(audioConfig["mediaType"] as? String, "audio/lpcm")
        XCTAssertEqual(audioConfig["sampleSizeBits"] as? Int, 16)
        XCTAssertEqual(audioConfig["channelCount"] as? Int, 1)
        XCTAssertEqual(audioConfig["audioType"] as? String, "SPEECH")
    }

    func testPromptStartEventBinaryTransport() throws {
        let json = BedrockEvents.promptStartEvent(
            promptName: "test-prompt",
            voiceId: "matthew",
            outputSampleRate: 48000,
            transport: .binary
        )

        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let promptStart = event["promptStart"] as! [String: Any]
        let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["sampleRateHertz"] as? Int, 48000)
        XCTAssertEqual(audioConfig["encoding"] as? String, "none")
        XCTAssertEqual(audioConfig["transport"] as? String, "binary")
    }

    func testPromptStartEventAllSampleRates() throws {
        for rate in NovaSonicSampleRate.allCases {
            let json = BedrockEvents.promptStartEvent(
                promptName: "test",
                voiceId: "tiffany",
                outputSampleRate: rate.hertz
            )

            let data = json.data(using: .utf8)!
            let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let event = parsed["event"] as! [String: Any]
            let promptStart = event["promptStart"] as! [String: Any]
            let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

            XCTAssertEqual(audioConfig["sampleRateHertz"] as? Int, rate.hertz,
                         "sampleRateHertz mismatch for \(rate)")
        }
    }

    // MARK: - audioContentStartEvent Tests

    func testAudioContentStartEventDefaultTransport() throws {
        let json = BedrockEvents.audioContentStartEvent(
            promptName: "test-prompt",
            audioContentName: "audio-1",
            inputSampleRate: 16000
        )

        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let contentStart = event["contentStart"] as! [String: Any]
        let audioConfig = contentStart["audioInputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["sampleRateHertz"] as? Int, 16000)
        XCTAssertEqual(audioConfig["encoding"] as? String, "base64")
        XCTAssertEqual(audioConfig["transport"] as? String, "json")
        XCTAssertEqual(contentStart["type"] as? String, "AUDIO")
        XCTAssertEqual(contentStart["role"] as? String, "USER")
        XCTAssertEqual(contentStart["interactive"] as? Bool, true)
    }

    func testAudioContentStartEventBinaryTransport() throws {
        let json = BedrockEvents.audioContentStartEvent(
            promptName: "test-prompt",
            audioContentName: "audio-1",
            inputSampleRate: 44100,
            transport: .binary
        )

        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let contentStart = event["contentStart"] as! [String: Any]
        let audioConfig = contentStart["audioInputConfiguration"] as! [String: Any]

        XCTAssertEqual(audioConfig["sampleRateHertz"] as? Int, 44100)
        XCTAssertEqual(audioConfig["encoding"] as? String, "none")
        XCTAssertEqual(audioConfig["transport"] as? String, "binary")
    }

    func testAudioContentStartEventAllSampleRates() throws {
        for rate in NovaSonicSampleRate.allCases {
            let json = BedrockEvents.audioContentStartEvent(
                promptName: "test",
                audioContentName: "audio-1",
                inputSampleRate: rate.hertz
            )

            let data = json.data(using: .utf8)!
            let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let event = parsed["event"] as! [String: Any]
            let contentStart = event["contentStart"] as! [String: Any]
            let audioConfig = contentStart["audioInputConfiguration"] as! [String: Any]

            XCTAssertEqual(audioConfig["sampleRateHertz"] as? Int, rate.hertz,
                         "sampleRateHertz mismatch for \(rate)")
        }
    }

    // MARK: - Backward Compatibility

    func testDefaultCallsProduceBackwardCompatibleJSON() throws {
        let promptJson = BedrockEvents.promptStartEvent(
            promptName: "p1",
            voiceId: "tiffany",
            outputSampleRate: 24000
        )

        let data = promptJson.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let promptStart = event["promptStart"] as! [String: Any]
        let audioConfig = promptStart["audioOutputConfiguration"] as! [String: Any]

        // These are the values the existing code always produced
        XCTAssertEqual(audioConfig["encoding"] as? String, "base64")
        XCTAssertEqual(audioConfig["mediaType"] as? String, "audio/lpcm")
        XCTAssertEqual(audioConfig["sampleSizeBits"] as? Int, 16)
        XCTAssertEqual(audioConfig["channelCount"] as? Int, 1)
        XCTAssertEqual(audioConfig["audioType"] as? String, "SPEECH")
    }

    func testPromptStartEventContainsToolConfiguration() throws {
        let json = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany"
        )

        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let promptStart = event["promptStart"] as! [String: Any]

        XCTAssertNotNil(promptStart["toolConfiguration"])
        XCTAssertNotNil(promptStart["textOutputConfiguration"])
        XCTAssertNotNil(promptStart["toolUseOutputConfiguration"])
    }
}
