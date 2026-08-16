import XCTest
@testable import NovaSonicCore

final class AudioTransportTests: XCTestCase {

    // MARK: - Sample Rate Tests

    func testAllSevenSampleRatesExist() {
        let allRates = NovaSonicSampleRate.allCases
        XCTAssertEqual(allRates.count, 7)
    }

    func testSampleRateRawValues() {
        XCTAssertEqual(NovaSonicSampleRate.rate8kHz.rawValue, 8000)
        XCTAssertEqual(NovaSonicSampleRate.rate16kHz.rawValue, 16000)
        XCTAssertEqual(NovaSonicSampleRate.rate22kHz.rawValue, 22050)
        XCTAssertEqual(NovaSonicSampleRate.rate24kHz.rawValue, 24000)
        XCTAssertEqual(NovaSonicSampleRate.rate32kHz.rawValue, 32000)
        XCTAssertEqual(NovaSonicSampleRate.rate44kHz.rawValue, 44100)
        XCTAssertEqual(NovaSonicSampleRate.rate48kHz.rawValue, 48000)
    }

    func testSampleRateHertzProperty() {
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertEqual(rate.hertz, rate.rawValue)
        }
    }

    func testSampleRateDisplayNames() {
        XCTAssertEqual(NovaSonicSampleRate.rate8kHz.displayName, "8 kHz")
        XCTAssertEqual(NovaSonicSampleRate.rate16kHz.displayName, "16 kHz")
        XCTAssertEqual(NovaSonicSampleRate.rate22kHz.displayName, "22.05 kHz")
        XCTAssertEqual(NovaSonicSampleRate.rate24kHz.displayName, "24 kHz")
        XCTAssertEqual(NovaSonicSampleRate.rate32kHz.displayName, "32 kHz")
        XCTAssertEqual(NovaSonicSampleRate.rate44kHz.displayName, "44.1 kHz")
        XCTAssertEqual(NovaSonicSampleRate.rate48kHz.displayName, "48 kHz")
    }

    func testSampleRateCodable() throws {
        for rate in NovaSonicSampleRate.allCases {
            let data = try JSONEncoder().encode(rate)
            let decoded = try JSONDecoder().decode(NovaSonicSampleRate.self, from: data)
            XCTAssertEqual(decoded, rate)
        }
    }

    func testSampleRateSerializesInPromptStartEvent() {
        // Test that all 7 rates serialize correctly in the sampleRateHertz JSON field
        for rate in NovaSonicSampleRate.allCases {
            let event = BedrockEvents.promptStartEvent(
                promptName: "test-prompt",
                voiceId: "tiffany",
                outputSampleRate: rate.hertz
            )
            XCTAssertTrue(event.contains("\(rate.hertz)"),
                "promptStartEvent should contain sampleRateHertz: \(rate.hertz)")
        }
    }

    func testSampleRateSerializesInAudioContentStartEvent() {
        for rate in NovaSonicSampleRate.allCases {
            let event = BedrockEvents.audioContentStartEvent(
                promptName: "test-prompt",
                audioContentName: "audio-input",
                inputSampleRate: rate.hertz
            )
            XCTAssertTrue(event.contains("\(rate.hertz)"),
                "audioContentStartEvent should contain sampleRateHertz: \(rate.hertz)")
        }
    }

    // MARK: - Media Type Tests

    func testPromptStartEventUsesAudioPCM() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany",
            outputSampleRate: 24000
        )
        XCTAssertTrue(event.contains("audio/pcm"), "Should use audio/pcm media type")
        XCTAssertFalse(event.contains("audio/lpcm"), "Should NOT contain audio/lpcm")
    }

    func testAudioContentStartEventUsesAudioPCM() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-input",
            inputSampleRate: 16000
        )
        XCTAssertTrue(event.contains("audio/pcm"), "Should use audio/pcm media type")
        XCTAssertFalse(event.contains("audio/lpcm"), "Should NOT contain audio/lpcm")
    }

    // MARK: - AudioTransportMode Tests

    func testAudioTransportModeDefaultsToJSON() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.audioTransportMode, .json)
    }

    func testAudioTransportModeCanBeSetToBinary() {
        let config = NovaSonicConfiguration(audioTransportMode: .binary)
        XCTAssertEqual(config.audioTransportMode, .binary)
    }

    func testAudioTransportModeRawValues() {
        XCTAssertEqual(AudioTransportMode.json.rawValue, "json")
        XCTAssertEqual(AudioTransportMode.binary.rawValue, "binary")
    }

    func testAudioTransportModeCodable() throws {
        for mode in AudioTransportMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(AudioTransportMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }

    func testAudioTransportModeAllCases() {
        XCTAssertEqual(AudioTransportMode.allCases.count, 2)
        XCTAssertTrue(AudioTransportMode.allCases.contains(.json))
        XCTAssertTrue(AudioTransportMode.allCases.contains(.binary))
    }

    // MARK: - Configuration Validation Tests

    func testConfigurationWithJsonModeValidates() {
        let config = NovaSonicConfiguration(audioTransportMode: .json)
        XCTAssertNoThrow(try config.validate())
    }

    func testConfigurationWithBinaryModeValidates() {
        let config = NovaSonicConfiguration(audioTransportMode: .binary)
        XCTAssertNoThrow(try config.validate())
    }

    func testDefaultConfigurationUnchanged() {
        // Verify that default config behavior is unchanged
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.audioTransportMode, .json)
        XCTAssertEqual(config.inputSampleRate, .rate16kHz)
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - Error Tests

    func testBinaryTransportNotEnabledError() {
        let error = NovaSonicError.binaryTransportNotEnabled
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not enabled"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains(".binary"))
        XCTAssertFalse(error.isRetryable)
    }

    func testUnsupportedSampleRateError() {
        let error = NovaSonicError.unsupportedSampleRate(.rate48kHz)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("48 kHz"))
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertFalse(error.isRetryable)
    }

    // MARK: - Binary Frame Encoder Tests

    func testBinaryFrameEncoderProducesValidFrame() {
        let audioData = Data(repeating: 0x42, count: 320) // 160 samples
        let frame = BinaryFrameEncoder.encodeAudioFrame(
            audioData: audioData,
            promptName: "test-prompt",
            audioContentName: "audio-input"
        )

        // Frame should be larger than just the audio data (has headers + framing)
        XCTAssertGreaterThan(frame.count, audioData.count)

        // Frame should have at least 16 bytes of framing overhead
        XCTAssertGreaterThan(frame.count, 16 + audioData.count)
    }

    func testBinaryFrameEncoderTotalLengthField() {
        let audioData = Data(repeating: 0xAB, count: 160)
        let frame = BinaryFrameEncoder.encodeAudioFrame(
            audioData: audioData,
            promptName: "p",
            audioContentName: "a"
        )

        // First 4 bytes should be total length (big-endian)
        let totalLength = UInt32(frame[0]) << 24 | UInt32(frame[1]) << 16 | UInt32(frame[2]) << 8 | UInt32(frame[3])
        XCTAssertEqual(Int(totalLength), frame.count)
    }

    // MARK: - Binary Frame Decoder Tests

    func testBinaryFrameDecoderRoundTrip() {
        let originalAudio = Data(repeating: 0x55, count: 320)
        let encoded = BinaryFrameEncoder.encodeAudioFrame(
            audioData: originalAudio,
            promptName: "test",
            audioContentName: "audio"
        )

        let decoded = BinaryFrameDecoder.decode(encoded)

        switch decoded {
        case .binaryAudio(let data):
            XCTAssertEqual(data, originalAudio)
        case .jsonEvent, .unknown:
            XCTFail("Expected binary audio frame, got \(decoded)")
        }
    }

    func testBinaryFrameDecoderHandlesTooSmallFrame() {
        let tooSmall = Data(repeating: 0, count: 10)
        let decoded = BinaryFrameDecoder.decode(tooSmall)

        switch decoded {
        case .unknown:
            break // expected
        default:
            XCTFail("Expected .unknown for too-small frame")
        }
    }

    // MARK: - Backward Compatibility Tests

    func testExistingSampleRatesUnchanged() {
        // Verify the original 3 rates still have correct raw values
        XCTAssertEqual(NovaSonicSampleRate.rate8kHz.rawValue, 8000)
        XCTAssertEqual(NovaSonicSampleRate.rate16kHz.rawValue, 16000)
        XCTAssertEqual(NovaSonicSampleRate.rate24kHz.rawValue, 24000)
    }

    func testExistingConfigDefaultsUnchanged() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.region, "us-east-1")
        XCTAssertEqual(config.model, .novaSonic2)
        XCTAssertEqual(config.voice, .tiffany)
        XCTAssertEqual(config.inputSampleRate, .rate16kHz)
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
    }
}
