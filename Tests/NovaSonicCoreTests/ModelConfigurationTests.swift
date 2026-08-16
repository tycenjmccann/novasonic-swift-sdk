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

// MARK: - Session Update Tests

/// Tests for session.update event serialization, validation, and response decoding.
final class SessionUpdateTests: XCTestCase {

    // MARK: - Configuration Property Tests

    func testReplacePropertyDefaultsToNil() {
        let cfg = NovaSonicConfiguration()
        XCTAssertNil(cfg.replace)
    }

    func testLanguageHintPropertyDefaultsToNil() {
        let cfg = NovaSonicConfiguration()
        XCTAssertNil(cfg.languageHint)
    }

    func testKeytermsPropertyDefaultsToNil() {
        let cfg = NovaSonicConfiguration()
        XCTAssertNil(cfg.keyterms)
    }

    func testConfigWithAllSessionUpdateFields() {
        let cfg = NovaSonicConfiguration(
            replace: ["Acme Mobile": "Acme Mobull"],
            languageHint: "ja",
            keyterms: ["Acme Mobile", "NovaSonic"]
        )
        XCTAssertEqual(cfg.replace, ["Acme Mobile": "Acme Mobull"])
        XCTAssertEqual(cfg.languageHint, "ja")
        XCTAssertEqual(cfg.keyterms, ["Acme Mobile", "NovaSonic"])
    }

    // MARK: - Keyterms Validation

    func testKeytermsValidationAccepts100Items() {
        let terms = (1...100).map { "term\($0)" }
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermsValidationRejects101Items() {
        let terms = (1...101).map { "term\($0)" }
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertThrowsError(try cfg.validate(), "More than 100 keyterms must be rejected")
    }

    func testKeytermsValidationAccepts50CharTerm() {
        let term = String(repeating: "a", count: 50)
        let cfg = NovaSonicConfiguration(keyterms: [term])
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermsValidationRejects51CharTerm() {
        let term = String(repeating: "a", count: 51)
        let cfg = NovaSonicConfiguration(keyterms: [term])
        XCTAssertThrowsError(try cfg.validate(), "Term exceeding 50 chars must be rejected")
    }

    func testKeytermsNilPassesValidation() {
        let cfg = NovaSonicConfiguration(keyterms: nil)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermsEmptyArrayPassesValidation() {
        let cfg = NovaSonicConfiguration(keyterms: [])
        XCTAssertNoThrow(try cfg.validate())
    }

    // MARK: - Session Update Event Serialization

    func testSessionUpdateEventWithReplaceOnly() throws {
        let json = BedrockEvents.sessionUpdateEvent(replace: ["Acme Mobile": "Acme Mobull"])
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "session.update")
        let replaceDict = parsed["replace"] as? [String: String]
        XCTAssertEqual(replaceDict, ["Acme Mobile": "Acme Mobull"])
        // No session subtree when only replace is set
        XCTAssertNil(parsed["session"])
    }

    func testSessionUpdateEventWithEmptyReplace() throws {
        let json = BedrockEvents.sessionUpdateEvent(replace: [:])
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "session.update")
        // FR-1.3: empty replace dict must be omitted, not serialized as {}
        XCTAssertNil(parsed["replace"])
        // No session subtree either when no other fields set
        XCTAssertNil(parsed["session"])
    }

    func testSessionUpdateEventWithLanguageHintOnly() throws {
        let json = BedrockEvents.sessionUpdateEvent(languageHint: "ja")
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "session.update")
        XCTAssertNil(parsed["replace"])

        // Verify nesting: session.audio.input.transcription.language_hint
        let session = parsed["session"] as? [String: Any]
        let audio = session?["audio"] as? [String: Any]
        let input = audio?["input"] as? [String: Any]
        let transcription = input?["transcription"] as? [String: Any]
        XCTAssertEqual(transcription?["language_hint"] as? String, "ja")
        XCTAssertNil(transcription?["keyterms"])
    }

    func testSessionUpdateEventWithKeytermsOnly() throws {
        let json = BedrockEvents.sessionUpdateEvent(keyterms: ["Acme Mobile", "NovaSonic"])
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "session.update")
        XCTAssertNil(parsed["replace"])

        let session = parsed["session"] as? [String: Any]
        let audio = session?["audio"] as? [String: Any]
        let input = audio?["input"] as? [String: Any]
        let transcription = input?["transcription"] as? [String: Any]
        XCTAssertEqual(transcription?["keyterms"] as? [String], ["Acme Mobile", "NovaSonic"])
        XCTAssertNil(transcription?["language_hint"])
    }

    func testSessionUpdateEventWithAllFields() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: ["NovaSonic": "Nova Sonic"],
            languageHint: "es-MX",
            keyterms: ["BrandX"]
        )
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "session.update")
        XCTAssertEqual(parsed["replace"] as? [String: String], ["NovaSonic": "Nova Sonic"])

        let session = parsed["session"] as? [String: Any]
        let audio = session?["audio"] as? [String: Any]
        let input = audio?["input"] as? [String: Any]
        let transcription = input?["transcription"] as? [String: Any]
        XCTAssertEqual(transcription?["language_hint"] as? String, "es-MX")
        XCTAssertEqual(transcription?["keyterms"] as? [String], ["BrandX"])
    }

    func testSessionUpdateEventNilOmitsAllKeys() throws {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: nil, keyterms: nil)
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "session.update")
        XCTAssertNil(parsed["replace"])
        XCTAssertNil(parsed["session"])
    }

    func testSessionUpdateEventEmptyKeytermsOmitsKey() throws {
        let json = BedrockEvents.sessionUpdateEvent(keyterms: [])
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "session.update")
        // Empty keyterms should not produce a session subtree
        XCTAssertNil(parsed["session"])
    }

    func testSessionUpdateEventFromConfiguration() throws {
        let cfg = NovaSonicConfiguration(
            replace: ["Hello": "Hey"],
            languageHint: "pt-BR",
            keyterms: ["SDK"]
        )
        let json = BedrockEvents.sessionUpdateEvent(configuration: cfg)
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(parsed["type"] as? String, "session.update")
        XCTAssertEqual(parsed["replace"] as? [String: String], ["Hello": "Hey"])

        let session = parsed["session"] as? [String: Any]
        let audio = session?["audio"] as? [String: Any]
        let input = audio?["input"] as? [String: Any]
        let transcription = input?["transcription"] as? [String: Any]
        XCTAssertEqual(transcription?["language_hint"] as? String, "pt-BR")
        XCTAssertEqual(transcription?["keyterms"] as? [String], ["SDK"])
    }

    func testLanguageHintAcceptsVariousBCP47Tags() throws {
        for tag in ["ja", "es-MX", "pt-BR", "en-US", "zh-Hans-CN"] {
            let json = BedrockEvents.sessionUpdateEvent(languageHint: tag)
            let data = json.data(using: .utf8)!
            let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let session = parsed["session"] as? [String: Any]
            let audio = session?["audio"] as? [String: Any]
            let input = audio?["input"] as? [String: Any]
            let transcription = input?["transcription"] as? [String: Any]
            XCTAssertEqual(transcription?["language_hint"] as? String, tag)
        }
    }

    // MARK: - SessionUpdatedResponse Decoding

    func testSessionUpdatedResponseDecodesFullPayload() throws {
        let json = """
        {
            "type": "session.updated",
            "replace": {"Acme Mobile": "Acme Mobull"},
            "session": {
                "audio": {
                    "input": {
                        "transcription": {
                            "language_hint": "ja",
                            "keyterms": ["Acme Mobile", "NovaSonic"]
                        }
                    }
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(SessionUpdatedResponse.self, from: data)

        XCTAssertEqual(response.type, "session.updated")
        XCTAssertEqual(response.replace, ["Acme Mobile": "Acme Mobull"])
        XCTAssertEqual(response.session?.audio?.input?.transcription?.languageHint, "ja")
        XCTAssertEqual(response.session?.audio?.input?.transcription?.keyterms, ["Acme Mobile", "NovaSonic"])
    }

    func testSessionUpdatedResponseDecodesPartialPayload() throws {
        let json = """
        {
            "type": "session.updated",
            "replace": {"Hello": "Hi"}
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(SessionUpdatedResponse.self, from: data)

        XCTAssertEqual(response.type, "session.updated")
        XCTAssertEqual(response.replace, ["Hello": "Hi"])
        XCTAssertNil(response.session)
    }

    func testSessionUpdatedResponseDecodesMinimalPayload() throws {
        let json = """
        {"type": "session.updated"}
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(SessionUpdatedResponse.self, from: data)

        XCTAssertEqual(response.type, "session.updated")
        XCTAssertNil(response.replace)
        XCTAssertNil(response.session)
    }
}
