import XCTest
@testable import NovaSonicCore

final class SessionUpdateTests: XCTestCase {

    // MARK: - Helper

    /// Parse a JSON string into a nested dictionary for assertion.
    private func parseJSON(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj
    }

    // MARK: - Serialization Tests

    func testReplaceSerializationWithMultipleEntries() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: ["AWS": "A W S", "SDK": "S D K"],
            languageHint: nil,
            keyterms: nil,
            voice: "tiffany",
            instructions: "You are a helpful assistant."
        )
        guard let parsed = parseJSON(json),
              let event = parsed["event"] as? [String: Any],
              let sessionUpdate = event["sessionUpdate"] as? [String: Any],
              let session = sessionUpdate["session"] as? [String: Any],
              let replace = session["replace"] as? [String: String] else {
            XCTFail("Failed to parse session update JSON")
            return
        }
        XCTAssertEqual(replace["AWS"], "A W S")
        XCTAssertEqual(replace["SDK"], "S D K")
        XCTAssertEqual(replace.count, 2)
    }

    func testLanguageHintNestedPath() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: nil,
            languageHint: "ja",
            keyterms: nil,
            voice: "tiffany",
            instructions: "You are a helpful assistant."
        )
        guard let parsed = parseJSON(json),
              let event = parsed["event"] as? [String: Any],
              let sessionUpdate = event["sessionUpdate"] as? [String: Any],
              let session = sessionUpdate["session"] as? [String: Any],
              let audio = session["audio"] as? [String: Any],
              let input = audio["input"] as? [String: Any],
              let transcription = input["transcription"] as? [String: Any] else {
            XCTFail("Failed to parse nested audio.input.transcription path")
            return
        }
        XCTAssertEqual(transcription["language_hint"] as? String, "ja")
    }

    func testKeytermsSerializationAsArray() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: nil,
            languageHint: nil,
            keyterms: ["NovaSonic", "Bedrock", "AWS"],
            voice: "tiffany",
            instructions: "You are a helpful assistant."
        )
        guard let parsed = parseJSON(json),
              let event = parsed["event"] as? [String: Any],
              let sessionUpdate = event["sessionUpdate"] as? [String: Any],
              let session = sessionUpdate["session"] as? [String: Any],
              let audio = session["audio"] as? [String: Any],
              let input = audio["input"] as? [String: Any],
              let transcription = input["transcription"] as? [String: Any],
              let keyterms = transcription["keyterms"] as? [String] else {
            XCTFail("Failed to parse keyterms array")
            return
        }
        XCTAssertEqual(keyterms, ["NovaSonic", "Bedrock", "AWS"])
    }

    func testNilFieldsOmittedFromPayload() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: nil,
            languageHint: nil,
            keyterms: nil,
            voice: "tiffany",
            instructions: "You are a helpful assistant."
        )
        guard let parsed = parseJSON(json),
              let event = parsed["event"] as? [String: Any],
              let sessionUpdate = event["sessionUpdate"] as? [String: Any],
              let session = sessionUpdate["session"] as? [String: Any] else {
            XCTFail("Failed to parse JSON")
            return
        }
        XCTAssertNil(session["replace"])
        XCTAssertNil(session["audio"])
    }

    func testEmptyReplaceOmitted() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: [:],
            languageHint: nil,
            keyterms: nil,
            voice: "tiffany",
            instructions: "You are a helpful assistant."
        )
        guard let parsed = parseJSON(json),
              let event = parsed["event"] as? [String: Any],
              let sessionUpdate = event["sessionUpdate"] as? [String: Any],
              let session = sessionUpdate["session"] as? [String: Any] else {
            XCTFail("Failed to parse JSON")
            return
        }
        XCTAssertNil(session["replace"])
    }

    func testEmptyKeytermsOmitted() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: nil,
            languageHint: nil,
            keyterms: [],
            voice: "tiffany",
            instructions: "You are a helpful assistant."
        )
        guard let parsed = parseJSON(json),
              let event = parsed["event"] as? [String: Any],
              let sessionUpdate = event["sessionUpdate"] as? [String: Any],
              let session = sessionUpdate["session"] as? [String: Any] else {
            XCTFail("Failed to parse JSON")
            return
        }
        XCTAssertNil(session["audio"])
    }

    func testAllFieldsPopulated() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: ["Acme Mobile": "Acme Mobull"],
            languageHint: "ja",
            keyterms: ["Acme Mobile", "NovaSonic"],
            voice: "tiffany",
            instructions: "You are a helpful assistant."
        )
        guard let parsed = parseJSON(json),
              let event = parsed["event"] as? [String: Any],
              let sessionUpdate = event["sessionUpdate"] as? [String: Any],
              let session = sessionUpdate["session"] as? [String: Any] else {
            XCTFail("Failed to parse JSON")
            return
        }

        // Voice and instructions at top level
        XCTAssertEqual(session["voice"] as? String, "tiffany")
        XCTAssertEqual(session["instructions"] as? String, "You are a helpful assistant.")

        // Replace at session level
        let replace = session["replace"] as? [String: String]
        XCTAssertEqual(replace?["Acme Mobile"], "Acme Mobull")

        // Transcription nested
        let audio = session["audio"] as? [String: Any]
        let input = audio?["input"] as? [String: Any]
        let transcription = input?["transcription"] as? [String: Any]
        XCTAssertEqual(transcription?["language_hint"] as? String, "ja")
        XCTAssertEqual(transcription?["keyterms"] as? [String], ["Acme Mobile", "NovaSonic"])
    }

    func testOnlyReplaceSetOmitsTranscription() {
        let json = BedrockEvents.sessionUpdateEvent(
            replace: ["hello": "hola"],
            languageHint: nil,
            keyterms: nil,
            voice: "tiffany",
            instructions: "Test"
        )
        guard let parsed = parseJSON(json),
              let event = parsed["event"] as? [String: Any],
              let sessionUpdate = event["sessionUpdate"] as? [String: Any],
              let session = sessionUpdate["session"] as? [String: Any] else {
            XCTFail("Failed to parse JSON")
            return
        }
        XCTAssertNotNil(session["replace"])
        XCTAssertNil(session["audio"])
    }

    // MARK: - Validation Tests

    func testLanguageHintBareEsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "es")
        XCTAssertThrowsError(try cfg.validate(), "Bare 'es' must require a regional variant")
    }

    func testLanguageHintBarePtRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "pt")
        XCTAssertThrowsError(try cfg.validate(), "Bare 'pt' must require a regional variant")
    }

    func testLanguageHintRegionalVariantsAccepted() {
        let validCodes = ["es-MX", "es-ES", "pt-BR", "pt-PT", "ja", "en-US", "fr-FR", "de-DE"]
        for code in validCodes {
            let cfg = NovaSonicConfiguration(languageHint: code)
            XCTAssertNoThrow(try cfg.validate(), "\(code) should be accepted as valid language hint")
        }
    }

    func testLanguageHintNilAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: nil)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermsOver100Rejected() {
        let tooMany = Array(repeating: "term", count: 101)
        let cfg = NovaSonicConfiguration(keyterms: tooMany)
        XCTAssertThrowsError(try cfg.validate(), "More than 100 keyterms must be rejected")
    }

    func testKeytermsExactly100Accepted() {
        let exactly100 = Array(repeating: "term", count: 100)
        let cfg = NovaSonicConfiguration(keyterms: exactly100)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermOver50CharsRejected() {
        let longTerm = String(repeating: "a", count: 51)
        let cfg = NovaSonicConfiguration(keyterms: [longTerm])
        XCTAssertThrowsError(try cfg.validate(), "Term with >50 characters must be rejected")
    }

    func testKeytermExactly50CharsAccepted() {
        let exactTerm = String(repeating: "a", count: 50)
        let cfg = NovaSonicConfiguration(keyterms: [exactTerm])
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermsNilAccepted() {
        let cfg = NovaSonicConfiguration(keyterms: nil)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeytermsEmptyAccepted() {
        let cfg = NovaSonicConfiguration(keyterms: [])
        XCTAssertNoThrow(try cfg.validate())
    }

    // MARK: - Configuration Property Tests

    func testConfigurationDefaultsAreNil() {
        let cfg = NovaSonicConfiguration()
        XCTAssertNil(cfg.replace)
        XCTAssertNil(cfg.languageHint)
        XCTAssertNil(cfg.keyterms)
    }

    func testConfigurationStoresValues() {
        let cfg = NovaSonicConfiguration(
            replace: ["test": "tset"],
            languageHint: "ja",
            keyterms: ["NovaSonic"]
        )
        XCTAssertEqual(cfg.replace, ["test": "tset"])
        XCTAssertEqual(cfg.languageHint, "ja")
        XCTAssertEqual(cfg.keyterms, ["NovaSonic"])
    }
}
