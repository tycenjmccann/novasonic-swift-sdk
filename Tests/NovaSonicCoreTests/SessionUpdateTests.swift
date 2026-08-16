import XCTest
@testable import NovaSonicCore

final class SessionUpdateTests: XCTestCase {

    // MARK: - Configuration Acceptance

    func testConfigurationAcceptsNewProperties() {
        let config = NovaSonicConfiguration(
            pronunciationReplacements: ["Acme Mobile": "Acme Mobull"],
            languageHint: "es-MX",
            keyterms: ["NovaSonic", "Bedrock"]
        )
        XCTAssertEqual(config.pronunciationReplacements, ["Acme Mobile": "Acme Mobull"])
        XCTAssertEqual(config.languageHint, "es-MX")
        XCTAssertEqual(config.keyterms, ["NovaSonic", "Bedrock"])
    }

    func testConfigurationDefaultsToNil() {
        let config = NovaSonicConfiguration()
        XCTAssertNil(config.pronunciationReplacements)
        XCTAssertNil(config.languageHint)
        XCTAssertNil(config.keyterms)
    }

    // MARK: - Validation: Language Hint

    func testValidateRejectsBareEs() {
        let config = NovaSonicConfiguration(languageHint: "es")
        XCTAssertThrowsError(try config.validate(), "Bare 'es' must be rejected")
    }

    func testValidateRejectsBarePt() {
        let config = NovaSonicConfiguration(languageHint: "pt")
        XCTAssertThrowsError(try config.validate(), "Bare 'pt' must be rejected")
    }

    func testValidateRejectsBareEsUppercase() {
        let config = NovaSonicConfiguration(languageHint: "ES")
        XCTAssertThrowsError(try config.validate(), "Bare 'ES' (uppercase) must be rejected")
    }

    func testValidateRejectsBarePtUppercase() {
        let config = NovaSonicConfiguration(languageHint: "PT")
        XCTAssertThrowsError(try config.validate(), "Bare 'PT' (uppercase) must be rejected")
    }

    func testValidateAcceptsRegionalEs() {
        let config = NovaSonicConfiguration(languageHint: "es-MX")
        XCTAssertNoThrow(try config.validate())
    }

    func testValidateAcceptsRegionalPt() {
        let config = NovaSonicConfiguration(languageHint: "pt-BR")
        XCTAssertNoThrow(try config.validate())
    }

    func testValidateAcceptsEnglish() {
        let config = NovaSonicConfiguration(languageHint: "en")
        XCTAssertNoThrow(try config.validate())
    }

    func testValidateAcceptsNilLanguageHint() {
        let config = NovaSonicConfiguration(languageHint: nil)
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - Validation: Keyterms

    func testValidateRejectsMoreThan100Keyterms() {
        let terms = (0...100).map { "term\($0)" } // 101 items
        let config = NovaSonicConfiguration(keyterms: terms)
        XCTAssertThrowsError(try config.validate(), "More than 100 keyterms must be rejected")
    }

    func testValidateAccepts100Keyterms() {
        let terms = (0..<100).map { "term\($0)" } // exactly 100
        let config = NovaSonicConfiguration(keyterms: terms)
        XCTAssertNoThrow(try config.validate())
    }

    func testValidateRejectsKeytermOver50Chars() {
        let longTerm = String(repeating: "a", count: 51)
        let config = NovaSonicConfiguration(keyterms: [longTerm])
        XCTAssertThrowsError(try config.validate(), "Keyterm over 50 chars must be rejected")
    }

    func testValidateAcceptsKeytermExactly50Chars() {
        let term = String(repeating: "a", count: 50)
        let config = NovaSonicConfiguration(keyterms: [term])
        XCTAssertNoThrow(try config.validate())
    }

    func testValidateAcceptsNilKeyterms() {
        let config = NovaSonicConfiguration(keyterms: nil)
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - BedrockEvents.sessionUpdateEvent

    func testSessionUpdateEventProducesCorrectJSON() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            pronunciationReplacements: ["Acme Mobile": "Acme Mobull"],
            languageHint: "es-MX",
            keyterms: ["NovaSonic", "Bedrock"]
        )

        XCTAssertNotNil(json)

        let data = json!.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]

        // Check replace
        let replace = sessionUpdate["replace"] as! [String: String]
        XCTAssertEqual(replace["Acme Mobile"], "Acme Mobull")

        // Check nested audio.input.transcription
        let audio = sessionUpdate["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertEqual(transcription["language_hint"] as? String, "es-MX")
        let keyterms = transcription["keyterms"] as! [String]
        XCTAssertEqual(keyterms, ["NovaSonic", "Bedrock"])
    }

    func testSessionUpdateEventReturnsNilWhenAllNil() {
        let json = BedrockEvents.sessionUpdateEvent(
            pronunciationReplacements: nil,
            languageHint: nil,
            keyterms: nil
        )
        XCTAssertNil(json, "When all fields are nil, no sessionUpdate event should be generated")
    }

    func testSessionUpdateEventOnlyIncludesNonNilKeys() throws {
        // Only language hint
        let json = BedrockEvents.sessionUpdateEvent(
            pronunciationReplacements: nil,
            languageHint: "en-US",
            keyterms: nil
        )

        XCTAssertNotNil(json)
        let data = json!.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]

        // Should NOT have replace key
        XCTAssertNil(sessionUpdate["replace"])

        // Should have audio.input.transcription.language_hint
        let audio = sessionUpdate["audio"] as! [String: Any]
        let input = audio["input"] as! [String: Any]
        let transcription = input["transcription"] as! [String: Any]
        XCTAssertEqual(transcription["language_hint"] as? String, "en-US")
        XCTAssertNil(transcription["keyterms"])
    }

    func testSessionUpdateEventWithOnlyReplacements() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            pronunciationReplacements: ["AI": "A.I."],
            languageHint: nil,
            keyterms: nil
        )

        XCTAssertNotNil(json)
        let data = json!.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let event = parsed["event"] as! [String: Any]
        let sessionUpdate = event["sessionUpdate"] as! [String: Any]

        let replace = sessionUpdate["replace"] as! [String: String]
        XCTAssertEqual(replace["AI"], "A.I.")
        XCTAssertNil(sessionUpdate["audio"])
    }
}
