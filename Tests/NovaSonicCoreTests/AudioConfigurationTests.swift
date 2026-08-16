import XCTest
@testable import NovaSonicCore

final class AudioConfigurationTests: XCTestCase {

    // MARK: - NovaSonicSampleRate Tests

    func testAllSampleRateCasesExist() {
        let allCases = NovaSonicSampleRate.allCases
        XCTAssertEqual(allCases.count, 7)
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
        XCTAssertEqual(NovaSonicSampleRate.rate8kHz.hertz, 8000)
        XCTAssertEqual(NovaSonicSampleRate.rate48kHz.hertz, 48000)
    }

    func testSampleRateDisplayNames() {
        XCTAssertFalse(NovaSonicSampleRate.rate22kHz.displayName.isEmpty)
        XCTAssertFalse(NovaSonicSampleRate.rate32kHz.displayName.isEmpty)
        XCTAssertFalse(NovaSonicSampleRate.rate44kHz.displayName.isEmpty)
        XCTAssertFalse(NovaSonicSampleRate.rate48kHz.displayName.isEmpty)
    }

    // MARK: - AudioCodec Tests

    func testAudioCodecCases() {
        let allCases = AudioCodec.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.pcm))
        XCTAssertTrue(allCases.contains(.pcmu))
        XCTAssertTrue(allCases.contains(.pcma))
    }

    func testAudioCodecMediaType() {
        XCTAssertEqual(AudioCodec.pcm.mediaType, "audio/lpcm")
        XCTAssertEqual(AudioCodec.pcmu.mediaType, "audio/pcmu")
        XCTAssertEqual(AudioCodec.pcma.mediaType, "audio/pcma")
    }

    func testAudioCodecDisplayName() {
        XCTAssertEqual(AudioCodec.pcm.displayName, "Linear PCM")
        XCTAssertEqual(AudioCodec.pcmu.displayName, "G.711 µ-law")
        XCTAssertEqual(AudioCodec.pcma.displayName, "G.711 A-law")
    }

    func testAudioCodecSupportedSampleRates() {
        // PCM supports all rates
        XCTAssertEqual(AudioCodec.pcm.supportedSampleRates.count, 7)

        // G.711 only supports 8kHz
        XCTAssertEqual(AudioCodec.pcmu.supportedSampleRates, [.rate8kHz])
        XCTAssertEqual(AudioCodec.pcma.supportedSampleRates, [.rate8kHz])
    }

    func testAudioCodecIsFixedRate() {
        XCTAssertFalse(AudioCodec.pcm.isFixedRate)
        XCTAssertTrue(AudioCodec.pcmu.isFixedRate)
        XCTAssertTrue(AudioCodec.pcma.isFixedRate)
    }

    func testAudioCodecBytesPerEncodedSample() {
        XCTAssertEqual(AudioCodec.pcm.bytesPerEncodedSample, 2)
        XCTAssertEqual(AudioCodec.pcmu.bytesPerEncodedSample, 1)
        XCTAssertEqual(AudioCodec.pcma.bytesPerEncodedSample, 1)
    }

    func testAudioCodecSampleSizeBits() {
        XCTAssertEqual(AudioCodec.pcm.sampleSizeBits, 16)
        XCTAssertEqual(AudioCodec.pcmu.sampleSizeBits, 8)
        XCTAssertEqual(AudioCodec.pcma.sampleSizeBits, 8)
    }

    // MARK: - AudioTransport Tests

    func testAudioTransportCases() {
        let allCases = AudioTransport.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.json))
        XCTAssertTrue(allCases.contains(.binary))
    }

    func testAudioTransportDisplayName() {
        XCTAssertEqual(AudioTransport.json.displayName, "JSON (base64)")
        XCTAssertEqual(AudioTransport.binary.displayName, "Binary frames")
    }

    // MARK: - Validation Tests

    func testPCMSupportsAllSampleRates() throws {
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertNoThrow(
                try NovaSonicConfigurationValidator.validate(codec: .pcm, sampleRate: rate),
                "PCM should support \(rate.rawValue) Hz"
            )
        }
    }

    func testG711OnlySupports8kHz() {
        // Valid: G.711 at 8kHz
        XCTAssertNoThrow(try NovaSonicConfigurationValidator.validate(codec: .pcmu, sampleRate: .rate8kHz))
        XCTAssertNoThrow(try NovaSonicConfigurationValidator.validate(codec: .pcma, sampleRate: .rate8kHz))

        // Invalid: G.711 at other rates
        let invalidRates: [NovaSonicSampleRate] = [.rate16kHz, .rate22kHz, .rate24kHz, .rate32kHz, .rate44kHz, .rate48kHz]
        for rate in invalidRates {
            XCTAssertThrowsError(
                try NovaSonicConfigurationValidator.validate(codec: .pcmu, sampleRate: rate),
                "PCMU should not support \(rate.rawValue) Hz"
            ) { error in
                guard case NovaSonicConfigurationError.invalidSampleRateForCodec = error else {
                    XCTFail("Expected invalidSampleRateForCodec error")
                    return
                }
            }
            XCTAssertThrowsError(
                try NovaSonicConfigurationValidator.validate(codec: .pcma, sampleRate: rate),
                "PCMA should not support \(rate.rawValue) Hz"
            ) { error in
                guard case NovaSonicConfigurationError.invalidSampleRateForCodec = error else {
                    XCTFail("Expected invalidSampleRateForCodec error")
                    return
                }
            }
        }
    }

    func testBinaryTransportRequiresPCM() {
        // Valid: binary with PCM
        XCTAssertNoThrow(try NovaSonicConfigurationValidator.validate(codec: .pcm, transport: .binary))

        // Valid: json with any codec
        XCTAssertNoThrow(try NovaSonicConfigurationValidator.validate(codec: .pcmu, transport: .json))
        XCTAssertNoThrow(try NovaSonicConfigurationValidator.validate(codec: .pcma, transport: .json))

        // Invalid: binary with G.711
        XCTAssertThrowsError(
            try NovaSonicConfigurationValidator.validate(codec: .pcmu, transport: .binary)
        ) { error in
            guard case NovaSonicConfigurationError.binaryTransportRequiresPCM = error else {
                XCTFail("Expected binaryTransportRequiresPCM error")
                return
            }
        }
        XCTAssertThrowsError(
            try NovaSonicConfigurationValidator.validate(codec: .pcma, transport: .binary)
        ) { error in
            guard case NovaSonicConfigurationError.binaryTransportRequiresPCM = error else {
                XCTFail("Expected binaryTransportRequiresPCM error")
                return
            }
        }
    }

    func testFullValidation() {
        // Valid: all defaults
        XCTAssertNoThrow(
            try NovaSonicConfigurationValidator.validateAudioConfiguration(
                inputCodec: .pcm, outputCodec: .pcm,
                inputSampleRate: .rate24kHz, outputSampleRate: .rate24kHz,
                inputTransport: .json, outputTransport: .json
            )
        )

        // Valid: telephony config
        XCTAssertNoThrow(
            try NovaSonicConfigurationValidator.validateAudioConfiguration(
                inputCodec: .pcmu, outputCodec: .pcmu,
                inputSampleRate: .rate8kHz, outputSampleRate: .rate8kHz,
                inputTransport: .json, outputTransport: .json
            )
        )

        // Invalid: G.711 with non-8kHz rate
        XCTAssertThrowsError(
            try NovaSonicConfigurationValidator.validateAudioConfiguration(
                inputCodec: .pcmu, outputCodec: .pcm,
                inputSampleRate: .rate48kHz, outputSampleRate: .rate24kHz,
                inputTransport: .json, outputTransport: .json
            )
        )
    }

    // MARK: - NovaSonicConfiguration Tests

    func testDefaultConfigurationValues() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.inputSampleRate, .rate24kHz)
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
        XCTAssertEqual(config.inputCodec, .pcm)
        XCTAssertEqual(config.outputCodec, .pcm)
        XCTAssertEqual(config.inputTransport, .json)
        XCTAssertEqual(config.outputTransport, .json)
    }

    func testTelephonyPreset() {
        let config = NovaSonicConfiguration.telephony
        XCTAssertEqual(config.inputSampleRate, .rate8kHz)
        XCTAssertEqual(config.outputSampleRate, .rate8kHz)
        XCTAssertEqual(config.inputCodec, .pcmu)
        XCTAssertEqual(config.outputCodec, .pcmu)
    }

    func testConfigurationValidationPasses() {
        let config = NovaSonicConfiguration()
        XCTAssertNoThrow(try config.validate())
    }

    func testConfigurationValidationFailsForInvalidCodecRate() {
        let config = NovaSonicConfiguration(
            inputSampleRate: .rate48kHz,
            inputCodec: .pcmu
        )
        XCTAssertThrowsError(try config.validate())
    }

    // MARK: - BedrockEvents Tests

    func testPromptStartEventWithPCMCodec() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany",
            outputCodec: .pcm,
            outputSampleRate: 24000
        )
        XCTAssertTrue(event.contains("audio/lpcm"))
        XCTAssertTrue(event.contains("24000"))
    }

    func testPromptStartEventWithG711Codec() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany",
            outputCodec: .pcmu,
            outputSampleRate: 8000
        )
        XCTAssertTrue(event.contains("audio/pcmu"))
        XCTAssertTrue(event.contains("8000"))
    }

    func testAudioContentStartEventWithPCMCodec() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-1",
            inputCodec: .pcm,
            inputSampleRate: 24000
        )
        XCTAssertTrue(event.contains("audio/lpcm"))
        XCTAssertTrue(event.contains("24000"))
    }

    func testAudioContentStartEventWithG711Codec() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-1",
            inputCodec: .pcma,
            inputSampleRate: 8000
        )
        XCTAssertTrue(event.contains("audio/pcma"))
        XCTAssertTrue(event.contains("8000"))
    }

    // MARK: - Backward Compatibility Tests

    func testExistingPromptStartEventStillWorks() {
        let event = BedrockEvents.promptStartEvent(
            promptName: "test",
            voiceId: "tiffany",
            outputSampleRate: 24000
        )
        XCTAssertTrue(event.contains("audio/lpcm"))
        XCTAssertTrue(event.contains("24000"))
    }

    func testExistingAudioContentStartEventStillWorks() {
        let event = BedrockEvents.audioContentStartEvent(
            promptName: "test",
            audioContentName: "audio-1",
            inputSampleRate: 16000
        )
        XCTAssertTrue(event.contains("audio/lpcm"))
        XCTAssertTrue(event.contains("16000"))
    }

    func testExistingSampleRateCasesUnchanged() {
        XCTAssertEqual(NovaSonicSampleRate.rate8kHz.rawValue, 8000)
        XCTAssertEqual(NovaSonicSampleRate.rate16kHz.rawValue, 16000)
        XCTAssertEqual(NovaSonicSampleRate.rate24kHz.rawValue, 24000)
    }

    // MARK: - Error Description Tests

    func testConfigurationErrorDescriptions() {
        let error1 = NovaSonicConfigurationError.invalidSampleRateForCodec(
            codec: .pcmu, requested: .rate48kHz, allowed: [.rate8kHz]
        )
        XCTAssertNotNil(error1.errorDescription)
        XCTAssertTrue(error1.errorDescription!.contains("48000"))
        XCTAssertNotNil(error1.recoverySuggestion)

        let error2 = NovaSonicConfigurationError.binaryTransportRequiresPCM(codec: .pcmu)
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertNotNil(error2.recoverySuggestion)

        let error3 = NovaSonicConfigurationError.unsupportedCodec(.pcma)
        XCTAssertNotNil(error3.errorDescription)

        let error4 = NovaSonicConfigurationError.binaryTransportUnavailable
        XCTAssertNotNil(error4.errorDescription)
    }
}
