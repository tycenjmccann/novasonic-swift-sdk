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

// MARK: - Session Configuration New Features Tests

/// Tests for pronunciation replacements, language hint, and keyterms (TEAM-2441).
final class SessionConfigNewFeaturesTests: XCTestCase {

    // MARK: - Replace (PR-01 through PR-05)

    func testReplaceNilOmitsField() {
        let event = SessionStartEvent(replace: nil)
        let json = event.buildEvent()
        XCTAssertFalse(json.contains("\"replace\""))
    }

    func testReplaceEmptyDictOmitsField() {
        let event = SessionStartEvent(replace: [:])
        let json = event.buildEvent()
        XCTAssertFalse(json.contains("\"replace\""))
    }

    func testReplaceNonNilSerializesCorrectly() {
        let event = SessionStartEvent(replace: ["Acme": "Akmee"])
        let json = event.buildEvent()
        XCTAssertTrue(json.contains("\"replace\""))
        XCTAssertTrue(json.contains("\"Acme\""))
        XCTAssertTrue(json.contains("\"Akmee\""))
    }

    func testReplaceMixedCasePreserved() {
        let event = SessionStartEvent(replace: ["NovaSonic": "Nova Sonnic"])
        let json = event.buildEvent()
        XCTAssertTrue(json.contains("NovaSonic"))
        XCTAssertTrue(json.contains("Nova Sonnic"))
    }

    // MARK: - LanguageHint (LH-02 through LH-07)

    func testLanguageHintNilOmitsField() {
        let event = SessionStartEvent(languageHint: nil)
        let json = event.buildEvent()
        XCTAssertFalse(json.contains("language_hint"))
    }

    func testLanguageHintSerializesCorrectPath() {
        let event = SessionStartEvent(languageHint: "es-MX")
        let json = event.buildEvent()
        XCTAssertTrue(json.contains("audioInputConfiguration"))
        XCTAssertTrue(json.contains("transcription"))
        XCTAssertTrue(json.contains("language_hint"))
        XCTAssertTrue(json.contains("es-MX"))
    }

    func testLanguageHintBareEsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "es")
        XCTAssertThrowsError(try cfg.validate())
    }

    func testLanguageHintBarePtRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "pt")
        XCTAssertThrowsError(try cfg.validate())
    }

    func testLanguageHintBareEsUppercaseRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "ES")
        XCTAssertThrowsError(try cfg.validate())
    }

    func testLanguageHintBarePtUppercaseRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "PT")
        XCTAssertThrowsError(try cfg.validate())
    }

    func testLanguageHintJaAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "ja")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testLanguageHintEnAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "en")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testLanguageHintFrAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "fr")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testLanguageHintRegionalVariantsAccepted() {
        for hint in ["es-MX", "pt-BR", "en-US", "fr-FR"] {
            let cfg = NovaSonicConfiguration(languageHint: hint)
            XCTAssertNoThrow(try cfg.validate(), "\(hint) should be accepted")
        }
    }

    // MARK: - Keyterms (KT-02 through KT-07)

    func testKeytermsNilOmitsField() {
        let event = SessionStartEvent(keyterms: nil)
        let json = event.buildEvent()
        XCTAssertFalse(json.contains("keyterms"))
    }

    func testKeytermsEmptyArrayOmitsField() {
        let event = SessionStartEvent(keyterms: [])
        let json = event.buildEvent()
        XCTAssertFalse(json.contains("keyterms"))
    }

    func testKeytermsSerializesCorrectPath() {
        let event = SessionStartEvent(keyterms: ["NovaSonic", "Bedrock"])
        let json = event.buildEvent()
        XCTAssertTrue(json.contains("audioInputConfiguration"))
        XCTAssertTrue(json.contains("transcription"))
        XCTAssertTrue(json.contains("keyterms"))
        XCTAssertTrue(json.contains("NovaSonic"))
        XCTAssertTrue(json.contains("Bedrock"))
    }

    func testKeytermsOver100Rejected() {
        let terms = (0...100).map { "term\($0)" } // 101 entries
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertThrowsError(try cfg.validate())
    }

    func testKeytermsExactly100Accepted() {
        let terms = (0..<100).map { "term\($0)" } // exactly 100
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermsOver50CharsRejected() {
        let longTerm = String(repeating: "a", count: 51)
        let cfg = NovaSonicConfiguration(keyterms: [longTerm])
        XCTAssertThrowsError(try cfg.validate())
    }

    func testKeytermsExactly50CharsAccepted() {
        let term = String(repeating: "a", count: 50)
        let cfg = NovaSonicConfiguration(keyterms: [term])
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermsDuplicatesPreserved() {
        let event = SessionStartEvent(keyterms: ["dup", "dup", "dup"])
        let json = event.buildEvent()
        // Count occurrences of "dup" in the keyterms array portion
        let count = json.components(separatedBy: "\"dup\"").count - 1
        XCTAssertEqual(count, 3)
    }

    // MARK: - Cross-Cutting (CC-01, CC-03)

    func testAllThreeFieldsCombined() {
        let event = SessionStartEvent(
            replace: ["Hello": "Hola"],
            languageHint: "en-US",
            keyterms: ["NovaSonic"]
        )
        let json = event.buildEvent()
        XCTAssertTrue(json.contains("\"replace\""))
        XCTAssertTrue(json.contains("language_hint"))
        XCTAssertTrue(json.contains("keyterms"))
        XCTAssertTrue(json.contains("\"Hello\""))
        XCTAssertTrue(json.contains("\"Hola\""))
        XCTAssertTrue(json.contains("en-US"))
        XCTAssertTrue(json.contains("NovaSonic"))
    }

    func testBackwardCompatibilityDefaultInit() {
        // Old-style init with no new params should still compile and work
        let cfg = NovaSonicConfiguration()
        XCTAssertNil(cfg.replace)
        XCTAssertNil(cfg.languageHint)
        XCTAssertNil(cfg.keyterms)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testBackwardCompatibilitySessionStartEvent() {
        // Old-style SessionStartEvent init should still work
        let event = SessionStartEvent(maxTokens: 1024, topP: 0.9, temperature: 0.7)
        let json = event.buildEvent()
        XCTAssertFalse(json.contains("\"replace\""))
        XCTAssertFalse(json.contains("language_hint"))
        XCTAssertFalse(json.contains("keyterms"))
    }
}
