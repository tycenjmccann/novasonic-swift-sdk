import XCTest
@testable import NovaSonicCore

/// Tests for SessionUpdateConfiguration validation and BedrockEvents.sessionUpdateEvent JSON output.
final class SessionUpdateTests: XCTestCase {

    // MARK: - Validation: languageHint

    func testNilLanguageHintIsValid() {
        let config = SessionUpdateConfiguration(languageHint: nil)
        XCTAssertNoThrow(try config.validate())
    }

    func testRegionalSpanishIsValid() {
        let config = SessionUpdateConfiguration(languageHint: "es-MX")
        XCTAssertNoThrow(try config.validate())
    }

    func testRegionalPortugueseIsValid() {
        let config = SessionUpdateConfiguration(languageHint: "pt-BR")
        XCTAssertNoThrow(try config.validate())
    }

    func testBareEsIsRejected() {
        let config = SessionUpdateConfiguration(languageHint: "es")
        XCTAssertThrowsError(try config.validate())
    }

    func testBarePtIsRejected() {
        let config = SessionUpdateConfiguration(languageHint: "pt")
        XCTAssertThrowsError(try config.validate())
    }

    func testBareEsCaseInsensitiveIsRejected() {
        let config = SessionUpdateConfiguration(languageHint: "ES")
        XCTAssertThrowsError(try config.validate())
    }

    func testBarePtCaseInsensitiveIsRejected() {
        let config = SessionUpdateConfiguration(languageHint: "PT")
        XCTAssertThrowsError(try config.validate())
    }

    func testUnrecognizedLanguageCodePassesThrough() {
        let config = SessionUpdateConfiguration(languageHint: "xx-YY")
        XCTAssertNoThrow(try config.validate())
    }

    func testEnglishCodeIsValid() {
        let config = SessionUpdateConfiguration(languageHint: "en-US")
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - Validation: keyterms

    func testNilKeytermsIsValid() {
        let config = SessionUpdateConfiguration(keyterms: nil)
        XCTAssertNoThrow(try config.validate())
    }

    func testEmptyKeytermsArrayIsValid() {
        let config = SessionUpdateConfiguration(keyterms: [])
        XCTAssertNoThrow(try config.validate())
    }

    func testKeytermsWithinLimitsIsValid() {
        let terms = ["NovaSonic", "Bedrock", "AWS"]
        let config = SessionUpdateConfiguration(keyterms: terms)
        XCTAssertNoThrow(try config.validate())
    }

    func testKeytermsExceeding100ItemsIsRejected() {
        let terms = (0...100).map { "term\($0)" }
        let config = SessionUpdateConfiguration(keyterms: terms)
        XCTAssertThrowsError(try config.validate())
    }

    func testKeytermExceeding50CharsIsRejected() {
        let longTerm = String(repeating: "a", count: 51)
        let config = SessionUpdateConfiguration(keyterms: [longTerm])
        XCTAssertThrowsError(try config.validate())
    }

    func testKeytermExactly50CharsIsValid() {
        let term = String(repeating: "a", count: 50)
        let config = SessionUpdateConfiguration(keyterms: [term])
        XCTAssertNoThrow(try config.validate())
    }

    func testKeytermsExactly100ItemsIsValid() {
        let terms = (0..<100).map { "term\($0)" }
        let config = SessionUpdateConfiguration(keyterms: terms)
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - Validation: replace

    func testNilReplaceIsValid() {
        let config = SessionUpdateConfiguration(replace: nil)
        XCTAssertNoThrow(try config.validate())
    }

    func testReplaceWithArbitraryEntriesIsValid() {
        let config = SessionUpdateConfiguration(replace: ["AWS": "A.W.S.", "S3": "S three"])
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - JSON Output: sessionUpdateEvent

    func testSessionUpdateEventWithAllFields() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: ["AWS": "A.W.S."],
            languageHint: "es-MX",
            keyterms: ["NovaSonic"]
        )

        let parsed = try parseJSON(json)
        let event = try XCTUnwrap(parsed["event"] as? [String: Any])
        let sessionUpdate = try XCTUnwrap(event["sessionUpdate"] as? [String: Any])

        let replace = try XCTUnwrap(sessionUpdate["replace"] as? [String: String])
        XCTAssertEqual(replace["AWS"], "A.W.S.")

        let audio = try XCTUnwrap(sessionUpdate["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])
        XCTAssertEqual(transcription["language_hint"] as? String, "es-MX")
        XCTAssertEqual(transcription["keyterms"] as? [String], ["NovaSonic"])
    }

    func testSessionUpdateEventOmitsReplaceWhenNil() throws {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: "en-US", keyterms: nil)

        let parsed = try parseJSON(json)
        let event = try XCTUnwrap(parsed["event"] as? [String: Any])
        let sessionUpdate = try XCTUnwrap(event["sessionUpdate"] as? [String: Any])

        XCTAssertNil(sessionUpdate["replace"])
    }

    func testSessionUpdateEventOmitsAudioWhenBothNil() throws {
        let json = BedrockEvents.sessionUpdateEvent(replace: ["X": "Y"], languageHint: nil, keyterms: nil)

        let parsed = try parseJSON(json)
        let event = try XCTUnwrap(parsed["event"] as? [String: Any])
        let sessionUpdate = try XCTUnwrap(event["sessionUpdate"] as? [String: Any])

        XCTAssertNil(sessionUpdate["audio"])
        XCTAssertEqual(sessionUpdate["replace"] as? [String: String], ["X": "Y"])
    }

    func testSessionUpdateEventOmitsLanguageHintWhenNil() throws {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: nil, keyterms: ["term1"])

        let parsed = try parseJSON(json)
        let event = try XCTUnwrap(parsed["event"] as? [String: Any])
        let sessionUpdate = try XCTUnwrap(event["sessionUpdate"] as? [String: Any])
        let audio = try XCTUnwrap(sessionUpdate["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])

        XCTAssertNil(transcription["language_hint"])
        XCTAssertEqual(transcription["keyterms"] as? [String], ["term1"])
    }

    func testSessionUpdateEventOmitsKeytermsWhenNil() throws {
        let json = BedrockEvents.sessionUpdateEvent(replace: nil, languageHint: "fr-FR", keyterms: nil)

        let parsed = try parseJSON(json)
        let event = try XCTUnwrap(parsed["event"] as? [String: Any])
        let sessionUpdate = try XCTUnwrap(event["sessionUpdate"] as? [String: Any])
        let audio = try XCTUnwrap(sessionUpdate["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])

        XCTAssertNil(transcription["keyterms"])
        XCTAssertEqual(transcription["language_hint"] as? String, "fr-FR")
    }

    // MARK: - EventParser: sessionUpdated

    func testEventParserHandlesSessionUpdated() throws {
        let json = """
        {"event":{"sessionUpdated":{"sessionId":"abc-123","replace":{"AWS":"A.W.S."}}}}
        """

        let result = EventParser.parse(json)
        guard case .sessionUpdated(let response) = result else {
            XCTFail("Expected .sessionUpdated, got \(String(describing: result))")
            return
        }

        XCTAssertEqual(response.sessionId, "abc-123")
        XCTAssertEqual(response.replace?["AWS"], "A.W.S.")
    }

    func testEventParserHandlesSessionUpdatedWithoutReplace() throws {
        let json = """
        {"event":{"sessionUpdated":{"sessionId":"xyz-789"}}}
        """

        let result = EventParser.parse(json)
        guard case .sessionUpdated(let response) = result else {
            XCTFail("Expected .sessionUpdated, got \(String(describing: result))")
            return
        }

        XCTAssertEqual(response.sessionId, "xyz-789")
        XCTAssertNil(response.replace)
    }

    // MARK: - Helpers

    private func parseJSON(_ string: String) throws -> [String: Any] {
        let data = string.data(using: .utf8)!
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
