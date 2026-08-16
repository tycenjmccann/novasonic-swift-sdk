import XCTest
@testable import NovaSonicCore

/// Covers the model-selection + validation behavior added for the Nova 2.5 beta comparison.
final class ModelConfigurationTests: XCTestCase {

    func testModelRawValuesMatchBedrockIDs() {
        XCTAssertEqual(NovaSonicModel.novaSonic1.id, "amazon.nova-sonic-v1:0")
        XCTAssertEqual(NovaSonicModel.novaSonic2.id, "amazon.nova-2-sonic-v1:0")
        XCTAssertEqual(NovaSonicModel.novaSonic25EA.id, "amazon.nova-2-sonic-early-access:0")
    }

    func testDefaultModelIsNovaSonic2() {
        XCTAssertEqual(NovaSonicConfiguration().model, .novaSonic2)
    }

    func testEarlyAccessRejectedOutsideUSEast1() {
        let cfg = NovaSonicConfiguration(region: "us-west-2", model: .novaSonic25EA)
        XCTAssertThrowsError(try cfg.validate(), "2.5 EA must be rejected outside us-east-1")
    }

    func testEarlyAccessAcceptedInUSEast1() {
        let cfg = NovaSonicConfiguration(region: "us-east-1", model: .novaSonic25EA)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testNonEACanUseOtherSupportedRegions() {
        let cfg = NovaSonicConfiguration(region: "us-west-2", model: .novaSonic2)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testUnsupportedRegionStillRejected() {
        let cfg = NovaSonicConfiguration(region: "eu-west-1", model: .novaSonic2)
        XCTAssertThrowsError(try cfg.validate())
    }

    // MARK: - Per-model region support (PR #4 review, Codex)

    func testV1SupportedRegions() {
        // v1: us-east-1 / eu-north-1 / ap-northeast-1 — NOT us-west-2.
        XCTAssertNoThrow(try NovaSonicConfiguration(region: "us-east-1", model: .novaSonic1).validate())
        XCTAssertNoThrow(try NovaSonicConfiguration(region: "eu-north-1", model: .novaSonic1).validate())
        XCTAssertNoThrow(try NovaSonicConfiguration(region: "ap-northeast-1", model: .novaSonic1).validate())
        XCTAssertThrowsError(try NovaSonicConfiguration(region: "us-west-2", model: .novaSonic1).validate(),
                             "v1 is not available in us-west-2")
    }

    func testV2RegionsRejectEUNorth1() {
        // eu-north-1 is a v1 region, not a v2 region.
        XCTAssertThrowsError(try NovaSonicConfiguration(region: "eu-north-1", model: .novaSonic2).validate())
    }

    func testEarlyAccessOnlyUSEast1() {
        XCTAssertEqual(NovaSonicModel.novaSonic25EA.supportedRegions, ["us-east-1"])
    }

    // MARK: - v1 + Nova 2.0-only voice (PR #3/#4 review, Codex)

    func testNovaSonic1WithNova2OnlyVoiceIsRejected() {
        // olivia (Australian) was introduced with Nova 2.0 — reject on v1.
        let cfg = NovaSonicConfiguration(region: "us-east-1", model: .novaSonic1, voice: .olivia)
        XCTAssertThrowsError(try cfg.validate(), "v1 + a Nova 2.0-only voice must be rejected before stream open")
    }

    func testNovaSonic1WithV1SafeVoiceIsAccepted() {
        // Per AWS v1 voice list: US/UK English, French, Italian, German, Spanish.
        let v1Voices: [NovaSonicVoice] = [.matthew, .tiffany, .amy, .lupe, .carlos,
                                          .ambre, .florian, .beatrice, .lorenzo, .greta, .lennart]
        for voice in v1Voices {
            let cfg = NovaSonicConfiguration(region: "us-east-1", model: .novaSonic1, voice: voice)
            XCTAssertNoThrow(try cfg.validate(), "\(voice) shipped with v1 and must be accepted")
        }
    }

    func testNova2OnlyVoiceAllowedOnV2() {
        let cfg = NovaSonicConfiguration(region: "us-east-1", model: .novaSonic2, voice: .olivia)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testVoiceNova2OnlyClassification() {
        // v1-available voices
        for v in [NovaSonicVoice.matthew, .tiffany, .amy, .lupe, .carlos,
                  .ambre, .florian, .beatrice, .lorenzo, .greta, .lennart] {
            XCTAssertFalse(v.isNova2Only, "\(v) is a v1 voice")
        }
        // v2-only voices
        for v in [NovaSonicVoice.olivia, .tina, .camila, .leo, .aditi, .rohan] {
            XCTAssertTrue(v.isNova2Only, "\(v) is v2-only")
        }
    }
}

/// Sanity checks on the metrics value types used for latency comparison.
final class SessionMetricsTests: XCTestCase {

    func testTimeToFirstAudioDerivation() {
        var turn = TurnMetric(turnIndex: 0)
        turn.userTranscriptAt = 1.0
        turn.firstAudioChunkAt = 1.4
        XCTAssertEqual(turn.timeToFirstAudioSeconds ?? -1, 0.4, accuracy: 0.0001)
    }

    func testToolRoundTripDerivation() {
        var call = ToolCallMetric(toolName: "searchMeals", toolUseId: "abc", requestedAt: 2.0)
        XCTAssertNil(call.roundTripSeconds)
        call.resultSentAt = 2.25
        XCTAssertEqual(call.roundTripSeconds ?? -1, 0.25, accuracy: 0.0001)
    }

    func testMedianTimeToFirstAudio() {
        var m = NovaSonicSessionMetrics(modelId: NovaSonicModel.novaSonic2.id, startedAt: Date())
        for (i, ttfa) in [0.3, 0.5, 0.9].enumerated() {
            var t = TurnMetric(turnIndex: i)
            t.userTranscriptAt = 0
            t.firstAudioChunkAt = ttfa
            m.turns.append(t)
        }
        XCTAssertEqual(m.medianTimeToFirstAudio ?? -1, 0.5, accuracy: 0.0001)
    }

    // MARK: - Turn attribution / negative TTFA (PR #3 review, Devin finding 1)

    func testTimeToFirstAudioNilWhenAudioPredatesTranscript() {
        // Barge-in: this turn's first recorded audio chunk belongs to the previous
        // response, arriving *before* the user's transcript. That's not a real latency.
        var turn = TurnMetric(turnIndex: 1)
        turn.firstAudioChunkAt = 1.0
        turn.userTranscriptAt = 1.5
        XCTAssertNil(turn.timeToFirstAudioSeconds, "audio before transcript must not yield a negative latency")
    }

    func testMedianExcludesNegativeTurns() {
        var m = NovaSonicSessionMetrics(modelId: NovaSonicModel.novaSonic2.id, startedAt: Date())
        // A speakFirst preamble turn (audio, no user transcript) contributes nothing.
        var preamble = TurnMetric(turnIndex: 0)
        preamble.firstAudioChunkAt = 0.2
        m.turns.append(preamble)
        // Two real turns.
        for (i, (u, a)) in [(1.0, 1.4), (2.0, 2.6)].enumerated() {
            var t = TurnMetric(turnIndex: i + 1)
            t.userTranscriptAt = u
            t.firstAudioChunkAt = a
            m.turns.append(t)
        }
        XCTAssertEqual(m.medianTimeToFirstAudio ?? -1, 0.5, accuracy: 0.0001)
    }

    func testMetricsRoundTripThroughJSON() throws {
        var m = NovaSonicSessionMetrics(modelId: NovaSonicModel.novaSonic25EA.id, startedAt: Date())
        var t = TurnMetric(turnIndex: 0)
        t.userTranscriptAt = 0.1
        t.firstAudioChunkAt = 0.6
        t.toolCalls = [ToolCallMetric(toolName: "selectMeal", toolUseId: "x", requestedAt: 0.2, resultSentAt: 0.35)]
        m.turns.append(t)

        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(NovaSonicSessionMetrics.self, from: data)
        XCTAssertEqual(decoded, m)
    }
}

/// Tests for session update features: replace, languageHint, keyterms (TEAM-2466)
final class SessionUpdateConfigurationTests: XCTestCase {

    // MARK: - LanguageCode Tests

    func testLanguageCodeRawValues() {
        XCTAssertEqual(LanguageCode.en_US.rawValue, "en-US")
        XCTAssertEqual(LanguageCode.es_MX.rawValue, "es-MX")
        XCTAssertEqual(LanguageCode.pt_BR.rawValue, "pt-BR")
        XCTAssertEqual(LanguageCode.pt_PT.rawValue, "pt-PT")
        XCTAssertEqual(LanguageCode.es_ES.rawValue, "es-ES")
    }

    func testLanguageCodeTagProperty() {
        XCTAssertEqual(LanguageCode.fr.tag, "fr")
        XCTAssertEqual(LanguageCode.ja.tag, "ja")
        XCTAssertEqual(LanguageCode.en.tag, "en")
    }

    func testNoBareSPanishOrPortuguese() {
        // Ensure no bare "es" or "pt" case exists (structural enforcement)
        let allCodes = LanguageCode.allCases.map { $0.rawValue }
        XCTAssertFalse(allCodes.contains("es"), "Bare 'es' must not exist - use es-MX or es-ES")
        XCTAssertFalse(allCodes.contains("pt"), "Bare 'pt' must not exist - use pt-BR or pt-PT")
    }

    func testLanguageCodeCaseIterable() {
        // Verify all expected codes are present
        XCTAssertTrue(LanguageCode.allCases.count >= 20)
        XCTAssertTrue(LanguageCode.allCases.contains(.en_US))
        XCTAssertTrue(LanguageCode.allCases.contains(.es_MX))
        XCTAssertTrue(LanguageCode.allCases.contains(.pt_BR))
    }

    // MARK: - TranscriptionConfig Validation Tests

    func testTranscriptionConfigValidCreation() {
        XCTAssertNoThrow(try TranscriptionConfig(languageHint: .en_US, keyterms: ["NovaSonic", "Bedrock"]))
    }

    func testTranscriptionConfigNilDefaults() {
        let config = try! TranscriptionConfig()
        XCTAssertNil(config.languageHint)
        XCTAssertNil(config.keyterms)
    }

    func testKeytermCountExceeded() {
        let terms = (0..<101).map { "term\($0)" }
        XCTAssertThrowsError(try TranscriptionConfig(keyterms: terms)) { error in
            guard let validationError = error as? SessionUpdateValidationError else {
                XCTFail("Expected SessionUpdateValidationError"); return
            }
            if case .keytermCountExceeded(let count) = validationError {
                XCTAssertEqual(count, 101)
            } else {
                XCTFail("Expected keytermCountExceeded, got \(validationError)")
            }
        }
    }

    func testKeytermLengthExceeded() {
        let longTerm = String(repeating: "a", count: 51)
        XCTAssertThrowsError(try TranscriptionConfig(keyterms: [longTerm])) { error in
            guard let validationError = error as? SessionUpdateValidationError else {
                XCTFail("Expected SessionUpdateValidationError"); return
            }
            if case .keytermLengthExceeded(_, let length) = validationError {
                XCTAssertEqual(length, 51)
            } else {
                XCTFail("Expected keytermLengthExceeded, got \(validationError)")
            }
        }
    }

    func testEmptyKeytermRejected() {
        XCTAssertThrowsError(try TranscriptionConfig(keyterms: ["valid", ""])) { error in
            guard let validationError = error as? SessionUpdateValidationError else {
                XCTFail("Expected SessionUpdateValidationError"); return
            }
            if case .emptyKeyterm = validationError {
                // pass
            } else {
                XCTFail("Expected emptyKeyterm, got \(validationError)")
            }
        }
    }

    func testMaximum100KeytermsAccepted() {
        let terms = (0..<100).map { "term\($0)" }
        XCTAssertNoThrow(try TranscriptionConfig(keyterms: terms))
    }

    func test50CharTermAccepted() {
        let term = String(repeating: "a", count: 50)
        XCTAssertNoThrow(try TranscriptionConfig(keyterms: [term]))
    }

    // MARK: - Replace Validation Tests

    func testValidateReplaceSuccess() {
        XCTAssertNoThrow(try validateReplace(["AWS": "Amazon Web Services", "SDK": "S.D.K."]))
    }

    func testValidateReplaceEmptyDict() {
        XCTAssertNoThrow(try validateReplace([:]))
    }

    func testValidateReplaceEmptyKeyRejected() {
        XCTAssertThrowsError(try validateReplace(["": "something"])) { error in
            guard let validationError = error as? SessionUpdateValidationError else {
                XCTFail("Expected SessionUpdateValidationError"); return
            }
            if case .emptyReplacementKey = validationError {
                // pass
            } else {
                XCTFail("Expected emptyReplacementKey, got \(validationError)")
            }
        }
    }

    func testValidateReplaceCountExceeded() {
        var dict: [String: String] = [:]
        for i in 0..<201 {
            dict["key\(i)"] = "value\(i)"
        }
        XCTAssertThrowsError(try validateReplace(dict)) { error in
            guard let validationError = error as? SessionUpdateValidationError else {
                XCTFail("Expected SessionUpdateValidationError"); return
            }
            if case .replacementCountExceeded(let count) = validationError {
                XCTAssertEqual(count, 201)
            } else {
                XCTFail("Expected replacementCountExceeded, got \(validationError)")
            }
        }
    }

    func testMax200ReplacementsAccepted() {
        var dict: [String: String] = [:]
        for i in 0..<200 {
            dict["key\(i)"] = "value\(i)"
        }
        XCTAssertNoThrow(try validateReplace(dict))
    }

    // MARK: - NovaSonicConfiguration Integration Tests

    func testConfigurationWithReplaceProperty() {
        let config = NovaSonicConfiguration(replace: ["AWS": "Amazon Web Services"])
        XCTAssertEqual(config.replace?["AWS"], "Amazon Web Services")
    }

    func testConfigurationReplaceDefaultsToNil() {
        let config = NovaSonicConfiguration()
        XCTAssertNil(config.replace)
    }

    func testConfigurationWithTranscriptionConfig() throws {
        let txConfig = try TranscriptionConfig(languageHint: .es_MX, keyterms: ["NovaSonic"])
        let config = NovaSonicConfiguration(transcriptionConfig: txConfig)
        XCTAssertEqual(config.languageHint, .es_MX)
        XCTAssertEqual(config.keyterms, ["NovaSonic"])
    }

    func testConfigurationTranscriptionConfigDefaultsToNil() {
        let config = NovaSonicConfiguration()
        XCTAssertNil(config.transcriptionConfig)
        XCTAssertNil(config.languageHint)
        XCTAssertNil(config.keyterms)
    }

    // MARK: - BedrockEvents.sessionUpdateEvent Tests

    func testSessionUpdateEventWithReplace() {
        let json = BedrockEvents.sessionUpdateEvent(replace: ["AWS": "Amazon Web Services"])
        XCTAssertTrue(json.contains("session.update"))
        XCTAssertTrue(json.contains("session_config"))
        XCTAssertTrue(json.contains("replace"))
        XCTAssertTrue(json.contains("Amazon Web Services"))
    }

    func testSessionUpdateEventWithLanguageHint() {
        let json = BedrockEvents.sessionUpdateEvent(languageHint: .en_US)
        XCTAssertTrue(json.contains("session.update"))
        XCTAssertTrue(json.contains("language_hint"))
        XCTAssertTrue(json.contains("en-US"))
        XCTAssertTrue(json.contains("transcription_config"))
    }

    func testSessionUpdateEventWithKeyterms() {
        let json = BedrockEvents.sessionUpdateEvent(keyterms: ["NovaSonic", "Bedrock"])
        XCTAssertTrue(json.contains("session.update"))
        XCTAssertTrue(json.contains("keyterms"))
        XCTAssertTrue(json.contains("NovaSonic"))
        XCTAssertTrue(json.contains("Bedrock"))
    }

    func testSessionUpdateEventCombined() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: ["SDK": "S.D.K."],
            languageHint: .fr,
            keyterms: ["transcription"]
        )
        XCTAssertTrue(json.contains("replace"))
        XCTAssertTrue(json.contains("language_hint"))
        XCTAssertTrue(json.contains("keyterms"))
        XCTAssertTrue(json.contains("S.D.K."))
        XCTAssertTrue(json.contains("\"fr\""))
        XCTAssertTrue(json.contains("transcription"))
    }

    func testSessionUpdateEventEmptyReplace() {
        let json = BedrockEvents.sessionUpdateEvent(replace: [:])
        // Empty dict should still include the "replace" key
        XCTAssertTrue(json.contains("replace"))
    }

    func testSessionUpdateEventOmitsNilFields() {
        let json = BedrockEvents.sessionUpdateEvent(languageHint: .ja)
        XCTAssertFalse(json.contains("replace"))
        XCTAssertFalse(json.contains("keyterms"))
        XCTAssertTrue(json.contains("language_hint"))
    }

    // MARK: - SessionUpdatedResponse Tests

    func testSessionUpdatedResponseModel() {
        let response = SessionUpdatedResponse(sessionId: "sess-123", timestamp: "2024-01-01", success: true, errorMessage: nil)
        XCTAssertEqual(response.sessionId, "sess-123")
        XCTAssertTrue(response.success)
        XCTAssertNil(response.errorMessage)
    }

    func testSessionUpdatedResponseFailure() {
        let response = SessionUpdatedResponse(sessionId: nil, timestamp: nil, success: false, errorMessage: "Invalid language code")
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.errorMessage, "Invalid language code")
    }

    func testSessionUpdatedResponseDefaults() {
        let response = SessionUpdatedResponse()
        XCTAssertNil(response.sessionId)
        XCTAssertNil(response.timestamp)
        XCTAssertTrue(response.success)
        XCTAssertNil(response.errorMessage)
    }
}
