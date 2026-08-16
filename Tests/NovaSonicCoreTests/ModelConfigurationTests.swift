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

// MARK: - Pronunciation, Language Hint, and Keyterms Tests

final class SessionUpdateConfigurationTests: XCTestCase {

    // FR-011.1: replace with multiple entries serializes correctly
    func testReplaceMultipleEntriesSerializes() {
        let json = BedrockEvents.sessionUpdate(
            voice: "tiffany",
            instructions: "You are a helpful assistant.",
            replace: ["AWS": "amazon web services", "NovaSonic": "Nova Sonic"]
        )
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = obj["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let replace = session["replace"] as! [String: String]
        XCTAssertEqual(replace["AWS"], "amazon web services")
        XCTAssertEqual(replace["NovaSonic"], "Nova Sonic")
    }

    // FR-011.2: replace: nil results in field omission
    func testReplaceNilOmitsField() {
        let json = BedrockEvents.sessionUpdate(
            voice: "tiffany",
            instructions: "You are a helpful assistant.",
            replace: nil
        )
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = obj["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        XCTAssertNil(session["replace"])
    }

    // FR-011.3: languageHint: "ja" serializes to correct path with correct key
    func testLanguageHintSerializesToCorrectPath() {
        let json = BedrockEvents.sessionUpdate(
            voice: "tiffany",
            instructions: "Test",
            languageHint: "ja"
        )
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = obj["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertEqual(transcription["language_hint"] as? String, "ja")
    }

    // FR-011.4: languageHint: "es" throws with descriptive error
    func testLanguageHintBareEsThrows() {
        let cfg = NovaSonicConfiguration(languageHint: "es")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("es-ES") || msg.contains("es-MX"), "Error should suggest regional variants")
        }
    }

    // FR-011.5: languageHint: "PT" (uppercase) throws (case-insensitive)
    func testLanguageHintUppercasePTThrows() {
        let cfg = NovaSonicConfiguration(languageHint: "PT")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("pt-BR") || msg.contains("pt-PT"), "Error should suggest regional variants")
        }
    }

    // FR-011.6: languageHint: "es-MX" passes validation
    func testLanguageHintRegionalVariantPasses() {
        let cfg = NovaSonicConfiguration(languageHint: "es-MX")
        XCTAssertNoThrow(try cfg.validate())
    }

    // FR-011.7: keyterms with 100 items passes validation
    func testKeyterms100ItemsPasses() {
        let terms = (1...100).map { "term\($0)" }
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertNoThrow(try cfg.validate())
    }

    // FR-011.8: keyterms with 101 items throws
    func testKeyterms101ItemsThrows() {
        let terms = (1...101).map { "term\($0)" }
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("101"), "Error should mention actual count")
            XCTAssertTrue(msg.contains("100"), "Error should mention maximum")
        }
    }

    // FR-011.9: keyterms with a 51-character term throws
    func testKeyterms51CharTermThrows() {
        let longTerm = String(repeating: "a", count: 51)
        let cfg = NovaSonicConfiguration(keyterms: [longTerm])
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                XCTFail("Expected validationError, got \(error)")
                return
            }
            XCTAssertTrue(msg.contains("51") || msg.contains("50"), "Error should mention character limit")
        }
    }

    // FR-011.10: keyterms with a 50-character term passes
    func testKeyterms50CharTermPasses() {
        let term = String(repeating: "a", count: 50)
        let cfg = NovaSonicConfiguration(keyterms: [term])
        XCTAssertNoThrow(try cfg.validate())
    }

    // FR-011.11: combined serialization with all three fields set
    func testCombinedSerializationAllFields() {
        let json = BedrockEvents.sessionUpdate(
            voice: "tiffany",
            instructions: "You are a helpful assistant.",
            replace: ["Acme": "Ak-mee"],
            languageHint: "ja",
            keyterms: ["Kubernetes", "EKS"]
        )
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]

        let event = obj["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]

        XCTAssertEqual(session["voice"] as? String, "tiffany")
        XCTAssertEqual(session["instructions"] as? String, "You are a helpful assistant.")

        // replace at session level
        let replace = session["replace"] as! [String: String]
        XCTAssertEqual(replace["Acme"], "Ak-mee")

        // language_hint + keyterms under audio.input.transcription
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertEqual(transcription["language_hint"] as? String, "ja")
        XCTAssertEqual(transcription["keyterms"] as? [String], ["Kubernetes", "EKS"])
    }

    // FR-011.12: partial combinations (only one or two fields set)
    func testPartialCombinationOnlyKeyterms() {
        let json = BedrockEvents.sessionUpdate(
            voice: "tiffany",
            instructions: "Test",
            keyterms: ["term1"]
        )
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = obj["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]
        let session = sessionUpdate["session"] as! [String: Any]

        // No replace
        XCTAssertNil(session["replace"])

        // keyterms present, no language_hint
        let audio = session["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertNil(transcription["language_hint"])
        XCTAssertEqual(transcription["keyterms"] as? [String], ["term1"])
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
