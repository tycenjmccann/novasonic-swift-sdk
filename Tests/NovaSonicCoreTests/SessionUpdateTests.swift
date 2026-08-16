import XCTest
@testable import NovaSonicCore

// MARK: - BedrockEvents.sessionUpdate Serialization

final class SessionUpdateSerializationTests: XCTestCase {

    func testAllFieldsProvided() throws {
        let json = BedrockEvents.sessionUpdate(
            voice: "tiffany",
            instructions: "Be helpful",
            replace: ["NovaSonic": "Nova Sonic"],
            languageHint: "en-US",
            keyterms: ["Bedrock", "Lambda"]
        )
        let dict = try deserialize(json)

        XCTAssertEqual(dict["type"] as? String, "session.update")

        let session = try XCTUnwrap(dict["session"] as? [String: Any])
        XCTAssertEqual(session["voice"] as? String, "tiffany")
        XCTAssertEqual(session["instructions"] as? String, "Be helpful")
        XCTAssertEqual(session["replace"] as? [String: String], ["NovaSonic": "Nova Sonic"])

        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])
        XCTAssertEqual(transcription["language_hint"] as? String, "en-US")
        XCTAssertEqual(transcription["keyterms"] as? [String], ["Bedrock", "Lambda"])
    }

    func testOnlyReplaceProvided() throws {
        let json = BedrockEvents.sessionUpdate(
            voice: "matthew",
            instructions: "Speak clearly",
            replace: ["AWS": "Amazon Web Services"]
        )
        let dict = try deserialize(json)
        let session = try XCTUnwrap(dict["session"] as? [String: Any])

        XCTAssertNotNil(session["replace"])
        XCTAssertNil(session["audio"])
    }

    func testOnlyLanguageHintProvided() throws {
        let json = BedrockEvents.sessionUpdate(
            voice: "amy",
            instructions: "Hi",
            languageHint: "ja"
        )
        let dict = try deserialize(json)
        let session = try XCTUnwrap(dict["session"] as? [String: Any])

        XCTAssertNil(session["replace"])

        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])
        XCTAssertEqual(transcription["language_hint"] as? String, "ja")
        XCTAssertNil(transcription["keyterms"])
    }

    func testOnlyKeytermsProvided() throws {
        let json = BedrockEvents.sessionUpdate(
            voice: "tiffany",
            instructions: "Hello",
            keyterms: ["S3", "EC2"]
        )
        let dict = try deserialize(json)
        let session = try XCTUnwrap(dict["session"] as? [String: Any])

        XCTAssertNil(session["replace"])

        let audio = try XCTUnwrap(session["audio"] as? [String: Any])
        let input = try XCTUnwrap(audio["input"] as? [String: Any])
        let transcription = try XCTUnwrap(input["transcription"] as? [String: Any])
        XCTAssertNil(transcription["language_hint"])
        XCTAssertEqual(transcription["keyterms"] as? [String], ["S3", "EC2"])
    }

    func testNoOptionalFields() throws {
        let json = BedrockEvents.sessionUpdate(
            voice: "carlos",
            instructions: "Hola"
        )
        let dict = try deserialize(json)
        let session = try XCTUnwrap(dict["session"] as? [String: Any])

        XCTAssertNil(session["replace"])
        XCTAssertNil(session["audio"])
    }

    func testNilFieldsNeverProduceNullValues() throws {
        let json = BedrockEvents.sessionUpdate(
            voice: "lupe",
            instructions: "Test"
        )
        XCTAssertFalse(json.contains("null"), "nil fields must not serialize as JSON null")
    }

    // MARK: - Helpers

    private func deserialize(_ jsonString: String) throws -> [String: Any] {
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(obj as? [String: Any])
    }
}

// MARK: - NovaSonicConfiguration Validation

final class SessionUpdateValidationTests: XCTestCase {

    // MARK: - Keyterms

    func testKeyterms100ItemsPasses() {
        let terms = (1...100).map { "term\($0)" }
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeyterms101ItemsThrows() {
        let terms = (1...101).map { "term\($0)" }
        let cfg = NovaSonicConfiguration(keyterms: terms)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                return XCTFail("Expected validationError, got \(error)")
            }
            XCTAssertTrue(msg.contains("101"), "Error should mention count: \(msg)")
        }
    }

    func testKeyterm50CharsPasses() {
        let term = String(repeating: "a", count: 50)
        let cfg = NovaSonicConfiguration(keyterms: [term])
        XCTAssertNoThrow(try cfg.validate())
    }

    func testKeyterm51CharsThrows() {
        let term = String(repeating: "a", count: 51)
        let cfg = NovaSonicConfiguration(keyterms: [term])
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                return XCTFail("Expected validationError, got \(error)")
            }
            XCTAssertTrue(msg.contains("51") || msg.contains("maximum is 50"), "Error should mention length: \(msg)")
        }
    }

    func testEmptyKeytermThrows() {
        let cfg = NovaSonicConfiguration(keyterms: ["valid", ""])
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                return XCTFail("Expected validationError, got \(error)")
            }
            XCTAssertTrue(msg.contains("empty"), "Error should mention empty: \(msg)")
        }
    }

    // MARK: - Language Hint

    func testLanguageHintBareEsThrows() {
        for variant in ["es", "ES", "Es"] {
            let cfg = NovaSonicConfiguration(languageHint: variant)
            XCTAssertThrowsError(try cfg.validate(), "'\(variant)' should be rejected") { error in
                guard case NovaSonicError.validationError(let msg) = error else {
                    return XCTFail("Expected validationError for '\(variant)', got \(error)")
                }
                XCTAssertTrue(msg.lowercased().contains("es"), "Error should reference 'es': \(msg)")
            }
        }
    }

    func testLanguageHintBarePtThrows() {
        for variant in ["pt", "PT", "Pt"] {
            let cfg = NovaSonicConfiguration(languageHint: variant)
            XCTAssertThrowsError(try cfg.validate(), "'\(variant)' should be rejected") { error in
                guard case NovaSonicError.validationError(let msg) = error else {
                    return XCTFail("Expected validationError for '\(variant)', got \(error)")
                }
                XCTAssertTrue(msg.lowercased().contains("pt"), "Error should reference 'pt': \(msg)")
            }
        }
    }

    func testLanguageHintEsMXPasses() {
        let cfg = NovaSonicConfiguration(languageHint: "es-MX")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testLanguageHintPtBRPasses() {
        let cfg = NovaSonicConfiguration(languageHint: "pt-BR")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testLanguageHintJaPasses() {
        let cfg = NovaSonicConfiguration(languageHint: "ja")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testLanguageHintEnUSPasses() {
        let cfg = NovaSonicConfiguration(languageHint: "en-US")
        XCTAssertNoThrow(try cfg.validate())
    }

    // MARK: - Replace

    func testEmptyReplaceKeyThrows() {
        let cfg = NovaSonicConfiguration(replace: ["": "something"])
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                return XCTFail("Expected validationError, got \(error)")
            }
            XCTAssertTrue(msg.contains("empty key"), "Error should mention empty key: \(msg)")
        }
    }

    func testEmptyReplaceValueThrows() {
        let cfg = NovaSonicConfiguration(replace: ["hello": ""])
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationError(let msg) = error else {
                return XCTFail("Expected validationError, got \(error)")
            }
            XCTAssertTrue(msg.contains("empty"), "Error should mention empty: \(msg)")
        }
    }

    func testValidReplacePasses() {
        let cfg = NovaSonicConfiguration(replace: ["NovaSonic": "Nova Sonic", "AWS": "Amazon Web Services"])
        XCTAssertNoThrow(try cfg.validate())
    }
}

// MARK: - Backward Compatibility

final class SessionUpdateBackwardCompatibilityTests: XCTestCase {

    func testDefaultInitWithNoNewParamsCompilesAndValidates() {
        let cfg = NovaSonicConfiguration()
        XCTAssertNoThrow(try cfg.validate())
    }

    func testExistingConfigPatternStillWorks() {
        let cfg = NovaSonicConfiguration(
            region: "us-east-1",
            model: .novaSonic2,
            voice: .tiffany,
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 1024,
            systemPrompt: "You are helpful."
        )
        XCTAssertNoThrow(try cfg.validate())
    }

    func testNewFieldsDefaultToNil() {
        let cfg = NovaSonicConfiguration()
        XCTAssertNil(cfg.replace)
        XCTAssertNil(cfg.languageHint)
        XCTAssertNil(cfg.keyterms)
    }
}

// MARK: - SessionUpdatedEvent Decoding

final class SessionUpdatedEventDecodingTests: XCTestCase {

    func testDecodeFullResponse() throws {
        let json = """
        {
            "type": "session.updated",
            "session": {
                "voice": "tiffany",
                "instructions": "Be helpful",
                "replace": {"NovaSonic": "Nova Sonic"},
                "audio": {
                    "input": {
                        "transcription": {
                            "language_hint": "en-US",
                            "keyterms": ["Bedrock", "Lambda"]
                        }
                    }
                }
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let event = try JSONDecoder().decode(SessionUpdatedEvent.self, from: data)

        XCTAssertEqual(event.type, "session.updated")
        XCTAssertEqual(event.session.voice, "tiffany")
        XCTAssertEqual(event.session.instructions, "Be helpful")
        XCTAssertEqual(event.session.replace, ["NovaSonic": "Nova Sonic"])
        XCTAssertEqual(event.session.audio?.input?.transcription?.languageHint, "en-US")
        XCTAssertEqual(event.session.audio?.input?.transcription?.keyterms, ["Bedrock", "Lambda"])
    }

    func testDecodeMinimalResponse() throws {
        let json = """
        {
            "type": "session.updated",
            "session": {
                "voice": "matthew"
            }
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let event = try JSONDecoder().decode(SessionUpdatedEvent.self, from: data)

        XCTAssertEqual(event.type, "session.updated")
        XCTAssertEqual(event.session.voice, "matthew")
        XCTAssertNil(event.session.instructions)
        XCTAssertNil(event.session.replace)
        XCTAssertNil(event.session.audio)
    }
}

// MARK: - NovaSonicError New Cases

final class SessionUpdateErrorTests: XCTestCase {

    func testValidationErrorDescription() {
        let error = NovaSonicError.validationError("test")
        XCTAssertEqual(error.errorDescription, "Validation failed: test")
    }

    func testSessionNotActiveDescription() {
        let error = NovaSonicError.sessionNotActive
        XCTAssertEqual(error.errorDescription, "Cannot update session: no active streaming session")
    }

    func testValidationErrorIsNotRetryable() {
        let error = NovaSonicError.validationError("anything")
        XCTAssertFalse(error.isRetryable)
    }

    func testSessionNotActiveIsNotRetryable() {
        let error = NovaSonicError.sessionNotActive
        XCTAssertFalse(error.isRetryable)
    }
}
