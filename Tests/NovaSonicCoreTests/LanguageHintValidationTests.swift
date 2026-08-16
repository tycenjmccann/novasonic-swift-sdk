import XCTest
@testable import NovaSonicCore

/// Tests for FR-2.4 / FR-2.5 languageHint validation — bare "es" and "pt"
/// must be rejected; regional variants and other BCP-47 tags must pass.
final class LanguageHintValidationTests: XCTestCase {

    // MARK: - Rejected (bare "es" and "pt", case-insensitive)

    func testBareEsIsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "es")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidLanguageHint(let hint) = error else {
                XCTFail("Expected invalidLanguageHint, got \(error)")
                return
            }
            XCTAssertEqual(hint, "es")
        }
    }

    func testBarePtIsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "pt")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidLanguageHint(let hint) = error else {
                XCTFail("Expected invalidLanguageHint, got \(error)")
                return
            }
            XCTAssertEqual(hint, "pt")
        }
    }

    func testBareEsUppercaseIsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "ES")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidLanguageHint = error else {
                XCTFail("Expected invalidLanguageHint, got \(error)")
                return
            }
        }
    }

    func testBarePtUppercaseIsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "PT")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidLanguageHint = error else {
                XCTFail("Expected invalidLanguageHint, got \(error)")
                return
            }
        }
    }

    func testBarePtMixedCaseIsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "Pt")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidLanguageHint = error else {
                XCTFail("Expected invalidLanguageHint, got \(error)")
                return
            }
        }
    }

    func testBareEsMixedCaseIsRejected() {
        let cfg = NovaSonicConfiguration(languageHint: "Es")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.invalidLanguageHint = error else {
                XCTFail("Expected invalidLanguageHint, got \(error)")
                return
            }
        }
    }

    // MARK: - Accepted (regional variants per FR-2.5)

    func testEsMXIsAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "es-MX")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testEsESIsAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "es-ES")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testPtBRIsAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "pt-BR")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testPtPTIsAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "pt-PT")
        XCTAssertNoThrow(try cfg.validate())
    }

    // MARK: - Accepted (other BCP-47 codes per FR-2.6)

    func testJaIsAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "ja")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testEnUSIsAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "en-US")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testArbitraryXxYYIsAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: "xx-YY")
        XCTAssertNoThrow(try cfg.validate())
    }

    func testNilLanguageHintIsAccepted() {
        let cfg = NovaSonicConfiguration(languageHint: nil)
        XCTAssertNoThrow(try cfg.validate())
    }

    // MARK: - Static helper directly

    func testValidateLanguageHintStaticRejectsBareEs() {
        XCTAssertThrowsError(try NovaSonicConfiguration.validateLanguageHint("es"))
    }

    func testValidateLanguageHintStaticRejectsBarePt() {
        XCTAssertThrowsError(try NovaSonicConfiguration.validateLanguageHint("pt"))
    }

    func testValidateLanguageHintStaticAcceptsEsMX() {
        XCTAssertNoThrow(try NovaSonicConfiguration.validateLanguageHint("es-MX"))
    }

    func testValidateLanguageHintStaticAcceptsPtBR() {
        XCTAssertNoThrow(try NovaSonicConfiguration.validateLanguageHint("pt-BR"))
    }

    // MARK: - Error message content

    func testErrorDescriptionContainsHint() {
        let error = NovaSonicError.invalidLanguageHint("es")
        XCTAssertTrue(error.errorDescription?.contains("es") ?? false)
        XCTAssertTrue(error.errorDescription?.contains("regional variant") ?? false)
    }

    func testErrorIsNotRetryable() {
        let error = NovaSonicError.invalidLanguageHint("pt")
        XCTAssertFalse(error.isRetryable)
    }

    func testRecoverySuggestionContainsExamples() {
        let error = NovaSonicError.invalidLanguageHint("es")
        XCTAssertTrue(error.recoverySuggestion?.contains("es-MX") ?? false)
        XCTAssertTrue(error.recoverySuggestion?.contains("pt-BR") ?? false)
    }
}
