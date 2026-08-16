import XCTest
@testable import NovaSonicCore

final class SessionUpdateTests: XCTestCase {

    // MARK: - TranscriptionConfig Validation

    func testEmptyKeytermsIsValid() {
        let config = TranscriptionConfig(partialResultsEnabled: true, keyterms: [])
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

    func testRequiresSessionUpdateWhenTranscriptionPresent() {
        let config = NovaSonicConfiguration(transcription: TranscriptionConfig())
        XCTAssertTrue(config.requiresSessionUpdate)
    }

    func testDoesNotRequireSessionUpdateWhenNoTranscription() {
        let config = NovaSonicConfiguration()
        XCTAssertFalse(config.requiresSessionUpdate)
    }

    // MARK: - BedrockEvents.sessionUpdateEvent

    func testSessionUpdateEventContainsExpectedStructure() throws {
        let transcription = TranscriptionConfig(partialResultsEnabled: true, keyterms: ["AWS", "Bedrock"])
        let json = BedrockEvents.sessionUpdateEvent(transcription: transcription)

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let event = try XCTUnwrap(parsed["event"] as? [String: Any])
        let sessionUpdate = try XCTUnwrap(event["sessionUpdate"] as? [String: Any])
        let inputTranscription = try XCTUnwrap(sessionUpdate["inputTranscription"] as? [String: Any])

        XCTAssertEqual(inputTranscription["partialResultsEnabled"] as? Bool, true)
        let keyterms = try XCTUnwrap(inputTranscription["keyterms"] as? [String])
        XCTAssertEqual(keyterms, ["AWS", "Bedrock"])
    }

    func testSessionUpdateEventOmitsKeytermsWhenEmpty() throws {
        let transcription = TranscriptionConfig(partialResultsEnabled: false, keyterms: [])
        let json = BedrockEvents.sessionUpdateEvent(transcription: transcription)

        let data = try XCTUnwrap(json.data(using: .utf8))
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let event = try XCTUnwrap(parsed["event"] as? [String: Any])
        let sessionUpdate = try XCTUnwrap(event["sessionUpdate"] as? [String: Any])
        let inputTranscription = try XCTUnwrap(sessionUpdate["inputTranscription"] as? [String: Any])

        XCTAssertEqual(inputTranscription["partialResultsEnabled"] as? Bool, false)
        XCTAssertNil(inputTranscription["keyterms"])
    }

    // MARK: - TranscriptionConfig Defaults

    func testTranscriptionConfigDefaultPartialResultsEnabled() {
        let config = TranscriptionConfig()
        XCTAssertTrue(config.partialResultsEnabled)
        XCTAssertTrue(config.keyterms.isEmpty)
    }

    func testTranscriptionConfigEquatable() {
        let a = TranscriptionConfig(partialResultsEnabled: true, keyterms: ["one"])
        let b = TranscriptionConfig(partialResultsEnabled: true, keyterms: ["one"])
        let c = TranscriptionConfig(partialResultsEnabled: false, keyterms: ["one"])
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
