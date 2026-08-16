import XCTest
@testable import NovaSonicCore

final class SessionUpdateTests: XCTestCase {

    // MARK: - TranscriptionConfig Validation

    func testNilKeytermsIsValid() {
        let config = TranscriptionConfig(languageHint: "en-US")
        XCTAssertNoThrow(try config.validate())
    }

    func testKeytermsWithinLimitsIsValid() {
        let terms = (1...100).map { "term\($0)" }
        let config = TranscriptionConfig(keyterms: terms)
        XCTAssertNoThrow(try config.validate())
    }

    func testKeytermsExceeding100ItemsThrows() {
        let terms = (1...101).map { "term\($0)" }
        let config = TranscriptionConfig(keyterms: terms)
        XCTAssertThrowsError(try config.validate())
    }

    func testKeytermExceeding50CharsThrows() {
        let longTerm = String(repeating: "a", count: 51)
        let config = TranscriptionConfig(keyterms: [longTerm])
        XCTAssertThrowsError(try config.validate())
    }

    func testKeytermExactly50CharsIsValid() {
        let term = String(repeating: "a", count: 50)
        let config = TranscriptionConfig(keyterms: [term])
        XCTAssertNoThrow(try config.validate())
    }

    func testKeytermExactly100ItemsIsValid() {
        let terms = (1...100).map { String(format: "t%02d", $0) }
        let config = TranscriptionConfig(keyterms: terms)
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - TranscriptionConfig Defaults

    func testTranscriptionConfigDefaults() {
        let config = TranscriptionConfig()
        XCTAssertNil(config.languageHint)
        XCTAssertNil(config.keyterms)
    }

    func testTranscriptionConfigEquatable() {
        let a = TranscriptionConfig(languageHint: "en-US", keyterms: ["one"])
        let b = TranscriptionConfig(languageHint: "en-US", keyterms: ["one"])
        let c = TranscriptionConfig(languageHint: "es-MX", keyterms: ["one"])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - NovaSonicConfiguration with Transcription

    func testConfigurationWithTranscriptionValidates() {
        let transcription = TranscriptionConfig(keyterms: ["hello", "world"])
        let config = NovaSonicConfiguration(transcription: transcription)
        XCTAssertNoThrow(try config.validate())
    }

    func testConfigurationWithInvalidTranscriptionThrows() {
        let terms = (1...101).map { "term\($0)" }
        let transcription = TranscriptionConfig(keyterms: terms)
        let config = NovaSonicConfiguration(transcription: transcription)
        XCTAssertThrowsError(try config.validate())
    }

    func testConfigurationWithoutTranscriptionValidates() {
        let config = NovaSonicConfiguration()
        XCTAssertNil(config.transcription)
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - NovaSonicConfiguration with Replace

    func testConfigurationWithReplace() {
        let config = NovaSonicConfiguration(replace: ["oldWord": "newWord"])
        XCTAssertEqual(config.replace, ["oldWord": "newWord"])
        XCTAssertNoThrow(try config.validate())
    }

    func testConfigurationWithoutReplace() {
        let config = NovaSonicConfiguration()
        XCTAssertNil(config.replace)
    }

    // MARK: - requiresSessionUpdate

    func testRequiresSessionUpdateWhenTranscriptionPresent() {
        let config = NovaSonicConfiguration(transcription: TranscriptionConfig())
        XCTAssertTrue(config.requiresSessionUpdate)
    }

    func testRequiresSessionUpdateWhenReplacePresent() {
        let config = NovaSonicConfiguration(replace: ["a": "b"])
        XCTAssertTrue(config.requiresSessionUpdate)
    }

    func testRequiresSessionUpdateWhenBothPresent() {
        let config = NovaSonicConfiguration(
            transcription: TranscriptionConfig(languageHint: "en-US"),
            replace: ["a": "b"]
        )
        XCTAssertTrue(config.requiresSessionUpdate)
    }

    func testDoesNotRequireSessionUpdateWhenNeitherPresent() {
        let config = NovaSonicConfiguration()
        XCTAssertFalse(config.requiresSessionUpdate)
    }

    // MARK: - BedrockEvents.sessionUpdateEvent JSON structure

    func testSessionUpdateEventHasCorrectTopLevelType() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            voice: "tiffany",
            replace: ["hello": "hi"],
            transcription: TranscriptionConfig(languageHint: "en-US", keyterms: ["AWS", "Bedrock"])
        )

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(parsed["type"] as? String, "session.update")
    }

    func testSessionUpdateEventHasSessionObject() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            voice: "tiffany",
            replace: ["hello": "hi"],
            transcription: TranscriptionConfig(languageHint: "en-US", keyterms: ["AWS", "Bedrock"])
        )

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(parsed["session"] as? [String: Any])

        XCTAssertEqual(session["voice"] as? String, "tiffany")

        let replace = try XCTUnwrap(session["replace"] as? [String: String])
        XCTAssertEqual(replace, ["hello": "hi"])
    }

    func testSessionUpdateEventTranscriptionNested() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            transcription: TranscriptionConfig(languageHint: "es-MX", keyterms: ["Bedrock"])
        )

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(parsed["session"] as? [String: Any])
        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])

        XCTAssertEqual(transcription["language_hint"] as? String, "es-MX")
        let keyterms = try XCTUnwrap(transcription["keyterms"] as? [String])
        XCTAssertEqual(keyterms, ["Bedrock"])
    }

    func testSessionUpdateEventOmitsNilFields() throws {
        let json = BedrockEvents.sessionUpdateEvent(replace: ["a": "b"])

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(parsed["session"] as? [String: Any])

        XCTAssertNil(session["voice"])
        XCTAssertNil(session["audio"])
        XCTAssertNotNil(session["replace"])
    }

    func testSessionUpdateEventOmitsEmptyKeyterms() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            transcription: TranscriptionConfig(languageHint: "pt-BR", keyterms: [])
        )

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(parsed["session"] as? [String: Any])
        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])

        XCTAssertEqual(transcription["language_hint"] as? String, "pt-BR")
        XCTAssertNil(transcription["keyterms"])
    }

    func testSessionUpdateEventUsesSnakeCaseKeys() throws {
        let json = BedrockEvents.sessionUpdateEvent(
            transcription: TranscriptionConfig(languageHint: "en-US", keyterms: ["test"])
        )

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let session = try XCTUnwrap(parsed["session"] as? [String: Any])
        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])

        XCTAssertNotNil(transcription["language_hint"])
        XCTAssertNotNil(transcription["keyterms"])
        XCTAssertNil(transcription["languageHint"])
    }
}
