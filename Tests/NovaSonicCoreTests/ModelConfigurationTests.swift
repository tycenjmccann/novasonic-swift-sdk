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

/// Tests for session.update feature: pronunciation replacements, language hint, and keyterms.
final class SessionUpdateTests: XCTestCase {

    // MARK: - Serialization Tests

    func testSessionUpdateEventWithReplace() {
        let json = BedrockEvents.sessionUpdateEvent(replace: ["Acme Mobile": "Acme Mobull"], languageHint: nil, keyterms: nil)
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let replaceDict = session["replace"] as! [String: String]
        XCTAssertEqual(replaceDict["Acme Mobile"], "Acme Mobull")
        // Should NOT have audio key when languageHint and keyterms are nil
        XCTAssertNil(session["audio"])
    }

    func testSessionUpdateEventWithNilReplace() {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: "ja", keyterms: nil)
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        XCTAssertNil(session["replace"])
    }

    func testSessionUpdateEventWithEmptyReplace() {
        let json = BedrockEvents.sessionUpdateEvent(replace: [:], languageHint: nil, keyterms: nil)
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let replaceDict = session["replace"] as! [String: String]
        XCTAssertTrue(replaceDict.isEmpty)
    }

    func testSessionUpdateEventWithLanguageHint() {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: "ja", keyterms: nil)
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertEqual(transcription["language_hint"] as? String, "ja")
    }

    func testSessionUpdateEventWithNilLanguageHint() {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: nil, keyterms: ["Kubernetes"])
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertNil(transcription["language_hint"])
    }

    func testSessionUpdateEventWithKeyterms() {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: nil, keyterms: ["Kubernetes", "gRPC"])
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        let keyterms = transcription["keyterms"] as! [String]
        XCTAssertEqual(keyterms, ["Kubernetes", "gRPC"])
    }

    func testSessionUpdateEventWithNilKeyterms() {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: "en", keyterms: nil)
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertNil(transcription["keyterms"])
    }

    func testSessionUpdateEventWithEmptyKeyterms() {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: nil, keyterms: [])
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        let keyterms = transcription["keyterms"] as! [String]
        XCTAssertTrue(keyterms.isEmpty)
    }

    func testSessionUpdateEventCombinedAllFields() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: ["AWS": "A W S"],
            languageHint: "en",
            keyterms: ["Kubernetes", "Lambda"]
        )
        let data = json.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]

        // Check replace
        let replaceDict = session["replace"] as! [String: String]
        XCTAssertEqual(replaceDict["AWS"], "A W S")

        // Check language_hint and keyterms
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertEqual(transcription["language_hint"] as? String, "en")
        let keyterms = transcription["keyterms"] as! [String]
        XCTAssertEqual(keyterms, ["Kubernetes", "Lambda"])
    }

    // MARK: - Language Hint Validation Tests

    func testBareEsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "es")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidLanguageHint = error else {
                XCTFail("Expected invalidLanguageHint, got \(error)")
                return
            }
        }
    }

    func testBarePtRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "pt")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidLanguageHint = error else {
                XCTFail("Expected invalidLanguageHint, got \(error)")
                return
            }
        }
    }

    func testBareEsCaseInsensitive() {
        let cfg = NovaSonicConfiguration(languageHint: "ES")
        XCTAssertThrowsError(try cfg.validate())
    }

    func testBarePtCaseInsensitive() {
        let cfg = NovaSonicConfiguration(languageHint: "PT")
        XCTAssertThrowsError(try cfg.validate())
    }

    func testValidLanguageCodes() {
        let validCodes = ["en", "ar-EG", "ar-SA", "ar-AE", "bn", "zh", "fr", "de", "hi", "id", "it", "ja", "ko", "pt-BR", "pt-PT", "ru", "es-MX", "es-ES", "tr", "vi"]
        for code in validCodes {
            let cfg = NovaSonicConfiguration(languageHint: code)
            XCTAssertNoThrow(try cfg.validate(), "Language code '\(code)' should be accepted")
        }
    }

    func testUnrecognizedLanguageCodePassesSilently() {
        let cfg = NovaSonicConfiguration(languageHint: "sw")
        XCTAssertNoThrow(try cfg.validate(), "Unrecognized code 'sw' should pass validation")

        let cfg2 = NovaSonicConfiguration(languageHint: "tlh")
        XCTAssertNoThrow(try cfg2.validate(), "Unrecognized code 'tlh' should pass validation")
    }

    // MARK: - Keyterms Validation Tests

    func testKeytermsTooManyRejected() {
        let terms = Array(repeating: "term", count: 101)
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidKeyterms = error else {
                XCTFail("Expected invalidKeyterms, got \(error)")
                return
            }
        }
    }

    func testKeytermsExactly100Accepted() {
        let terms = Array(repeating: "term", count: 100)
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermTooLongRejected() {
        let longTerm = String(repeating: "a", count: 51)
        let cfg = NovaSonicConfiguration(keyterms: [longTerm])
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidKeyterms = error else {
                XCTFail("Expected invalidKeyterms, got \(error)")
                return
            }
        }
    }

    func testKeytermExactly50Accepted() {
        let term = String(repeating: "a", count: 50)
        let cfg = NovaSonicConfiguration(keyterms: [term])
        XCTAssertNoThrow(try cfg.validate())
    }

    func testEmptyKeytermsAccepted() {
        let cfg = NovaSonicConfiguration(keyterms: [])
        XCTAssertNoThrow(try cfg.validate())
    }

    func testNilKeytermsAccepted() {
        let cfg = NovaSonicConfiguration(keyterms: nil)
        XCTAssertNoThrow(try cfg.validate())
    }

    // MARK: - Session Update Guard Test

    @MainActor
    func testSendSessionUpdateThrowsWhenNotActive() async {
        let manager = NovaSonicStreamManager()
        do {
            try await manager.sendSessionUpdate(languageHint: "en")
            XCTFail("Expected sessionNotActive error")
        } catch {
            guard case NovaSonicError.sessionNotActive = error else {
                XCTFail("Expected sessionNotActive, got \(error)")
                return
            }
        }
    }

    // MARK: - Response Parsing Test

    func testSessionUpdatedEventParsing() {
        let json = """
        {
            "event": {
                "sessionUpdated": {
                    "sessionId": "test-session-123"
                }
            }
        }
        """
        let event = EventParser.parse(json)
        guard case .sessionUpdated(let response) = event else {
            XCTFail("Expected sessionUpdated event, got \(String(describing: event))")
            return
        }
        XCTAssertEqual(response.sessionId, "test-session-123")
    }

    // MARK: - Configuration Backward Compatibility

    func testNewPropertiesDefaultToNil() {
        let cfg = NovaSonicConfiguration()
        XCTAssertNil(cfg.replace)
        XCTAssertNil(cfg.languageHint)
        XCTAssertNil(cfg.keyterms)
    }

    func testConfigurationWithAllNewFields() {
        let cfg = NovaSonicConfiguration(
            replace: ["hello": "heh-low"],
            languageHint: "fr",
            keyterms: ["bonjour", "merci"]
        )
        XCTAssertEqual(cfg.replace, ["hello": "heh-low"])
        XCTAssertEqual(cfg.languageHint, "fr")
        XCTAssertEqual(cfg.keyterms, ["bonjour", "merci"])
    }

    // MARK: - Auto-send at Session Start Tests

    func testAutoSendSessionUpdateEventProducedWhenConfigured() {
        let cfg = NovaSonicConfiguration(
            replace: ["Acme": "Ack-me"],
            languageHint: "ja",
            keyterms: ["Kubernetes", "gRPC"]
        )

        let shouldAutoSend = cfg.replace != nil || cfg.languageHint != nil || cfg.keyterms != nil
        XCTAssertTrue(shouldAutoSend, "Should auto-send when configuration has session-update values")

        let eventJson = BedrockEvents.sessionUpdateEvent(
            replace: cfg.replace,
            languageHint: cfg.languageHint,
            keyterms: cfg.keyterms
        )

        let data = eventJson.data(using: .utf8)!
        let parsed = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]

        let replaceDict = session["replace"] as! [String: String]
        XCTAssertEqual(replaceDict["Acme"], "Ack-me")

        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertEqual(transcription["language_hint"] as? String, "ja")
        let keyterms = transcription["keyterms"] as! [String]
        XCTAssertEqual(keyterms, ["Kubernetes", "gRPC"])
    }

    func testNoAutoSendWhenAllNil() {
        let cfg = NovaSonicConfiguration()
        let shouldAutoSend = cfg.replace != nil || cfg.languageHint != nil || cfg.keyterms != nil
        XCTAssertFalse(shouldAutoSend, "Should NOT auto-send when no session-update values configured")
    }

    func testAutoSendWithOnlyReplace() {
        let cfg = NovaSonicConfiguration(replace: ["Hello": "Heh-low"])
        let shouldAutoSend = cfg.replace != nil || cfg.languageHint != nil || cfg.keyterms != nil
        XCTAssertTrue(shouldAutoSend, "Should auto-send when only replace is configured")
    }

    func testAutoSendWithOnlyLanguageHint() {
        let cfg = NovaSonicConfiguration(languageHint: "fr")
        let shouldAutoSend = cfg.replace != nil || cfg.languageHint != nil || cfg.keyterms != nil
        XCTAssertTrue(shouldAutoSend, "Should auto-send when only languageHint is configured")
    }

    func testAutoSendWithOnlyKeyterms() {
        let cfg = NovaSonicConfiguration(keyterms: ["AI", "ML"])
        let shouldAutoSend = cfg.replace != nil || cfg.languageHint != nil || cfg.keyterms != nil
        XCTAssertTrue(shouldAutoSend, "Should auto-send when only keyterms is configured")
    }
}
