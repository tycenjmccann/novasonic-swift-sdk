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

// MARK: - Language Hint Validation Tests (FR-2.4, FR-2.5, FR-2.6)

final class LanguageHintValidationTests: XCTestCase {

    // FR-2.4: Bare "es" rejected with descriptive error
    func testBareEsRejectedWithDescriptiveError() {
        let cfg = NovaSonicConfiguration(languageHint: "es")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard let nsError = error as? NovaSonicError else {
                XCTFail("Expected NovaSonicError"); return
            }
            let description = nsError.errorDescription ?? ""
            XCTAssertTrue(description.contains("regional variant"), "Error should mention regional variant, got: \(description)")
            XCTAssertTrue(description.lowercased().contains("es-"), "Error should suggest es- variants, got: \(description)")
        }
    }

    // FR-2.4: Bare "pt" rejected with descriptive error
    func testBarePtRejectedWithDescriptiveError() {
        let cfg = NovaSonicConfiguration(languageHint: "pt")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard let nsError = error as? NovaSonicError else {
                XCTFail("Expected NovaSonicError"); return
            }
            let description = nsError.errorDescription ?? ""
            XCTAssertTrue(description.contains("regional variant"), "Error should mention regional variant, got: \(description)")
            XCTAssertTrue(description.lowercased().contains("pt-"), "Error should suggest pt- variants, got: \(description)")
        }
    }

    // FR-2.4: Case insensitive
    func testBareEsUppercaseRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "ES")
        XCTAssertThrowsError(try cfg.validate())
    }

    func testBarePtUppercaseRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "PT")
        XCTAssertThrowsError(try cfg.validate())
    }

    // FR-2.5: Regional variants accepted
    func testEsMXAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "es-MX")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testEsESAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "es-ES")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testPtBRAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "pt-BR")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testPtPTAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "pt-PT")
        XCTAssertNoThrow(try cfg.validate())
    }

    // FR-2.6: Unknown but well-formed BCP-47 codes pass
    func testUnknownBCP47CodeAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "xx-YY")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testJapaneseAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "ja")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testEnglishUSAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "en-US")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testNilLanguageHintAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: nil)
        XCTAssertNoThrow(try cfg.validate())
    }
}
