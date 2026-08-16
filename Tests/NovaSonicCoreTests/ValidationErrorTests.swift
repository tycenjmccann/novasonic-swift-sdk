import XCTest
@testable import NovaSonicCore

final class ValidationErrorTests: XCTestCase {

    // MARK: - Region Validation

    func testUnsupportedRegionGivesDescriptiveError() {
        let cfg = NovaSonicConfiguration(region: "eu-west-1", model: .novaSonic2)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationFailed(let field, let reason) = error as? NovaSonicError else {
                XCTFail("Expected .validationFailed, got \(error)")
                return
            }
            XCTAssertEqual(field, "region")
            XCTAssertTrue(reason.contains("eu-west-1"), "Reason should mention the invalid value")
            XCTAssertTrue(reason.contains("us-east-1"), "Reason should suggest valid regions")
        }
    }

    // MARK: - Voice + Model Compatibility

    func testNova2OnlyVoiceOnV1GivesDescriptiveError() {
        let cfg = NovaSonicConfiguration(region: "us-east-1", model: .novaSonic1, voice: .olivia)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationFailed(let field, let reason) = error as? NovaSonicError else {
                XCTFail("Expected .validationFailed, got \(error)")
                return
            }
            XCTAssertEqual(field, "voice")
            XCTAssertTrue(reason.contains("olivia"), "Reason should mention the invalid voice")
            XCTAssertTrue(reason.contains("Nova Sonic 2.0"), "Reason should mention required model version")
        }
    }

    // MARK: - Temperature Validation

    func testTemperatureTooHighGivesDescriptiveError() {
        let cfg = NovaSonicConfiguration(temperature: 1.5)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationFailed(let field, let reason) = error as? NovaSonicError else {
                XCTFail("Expected .validationFailed, got \(error)")
                return
            }
            XCTAssertEqual(field, "temperature")
            XCTAssertTrue(reason.contains("1.5"), "Reason should mention the invalid value")
            XCTAssertTrue(reason.contains("0.0") && reason.contains("1.0"), "Reason should mention valid range")
        }
    }

    func testTemperatureNegativeGivesDescriptiveError() {
        let cfg = NovaSonicConfiguration(temperature: -0.1)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationFailed(let field, let reason) = error as? NovaSonicError else {
                XCTFail("Expected .validationFailed, got \(error)")
                return
            }
            XCTAssertEqual(field, "temperature")
            XCTAssertTrue(reason.contains("-0.1"), "Reason should mention the invalid value")
        }
    }

    // MARK: - TopP Validation

    func testTopPOutOfRangeGivesDescriptiveError() {
        let cfg = NovaSonicConfiguration(topP: 2.0)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationFailed(let field, let reason) = error as? NovaSonicError else {
                XCTFail("Expected .validationFailed, got \(error)")
                return
            }
            XCTAssertEqual(field, "topP")
            XCTAssertTrue(reason.contains("2.0"), "Reason should mention the invalid value")
        }
    }

    // MARK: - MaxTokens Validation

    func testMaxTokensZeroGivesDescriptiveError() {
        let cfg = NovaSonicConfiguration(maxTokens: 0)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationFailed(let field, let reason) = error as? NovaSonicError else {
                XCTFail("Expected .validationFailed, got \(error)")
                return
            }
            XCTAssertEqual(field, "maxTokens")
            XCTAssertTrue(reason.contains("0"), "Reason should mention the invalid value")
        }
    }

    func testMaxTokensExceedsLimitGivesDescriptiveError() {
        let cfg = NovaSonicConfiguration(maxTokens: 5000)
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationFailed(let field, let reason) = error as? NovaSonicError else {
                XCTFail("Expected .validationFailed, got \(error)")
                return
            }
            XCTAssertEqual(field, "maxTokens")
            XCTAssertTrue(reason.contains("5000"), "Reason should mention the invalid value")
            XCTAssertTrue(reason.contains("4096"), "Reason should mention the max allowed")
        }
    }

    // MARK: - System Prompt Validation

    func testEmptySystemPromptGivesDescriptiveError() {
        let cfg = NovaSonicConfiguration(systemPrompt: "   ")
        XCTAssertThrowsError(try cfg.validate()) { error in
            guard case NovaSonicError.validationFailed(let field, let reason) = error as? NovaSonicError else {
                XCTFail("Expected .validationFailed, got \(error)")
                return
            }
            XCTAssertEqual(field, "systemPrompt")
            XCTAssertTrue(reason.contains("empty"), "Reason should explain the constraint")
        }
    }

    // MARK: - Valid Configuration Still Passes

    func testValidConfigurationDoesNotThrow() {
        let cfg = NovaSonicConfiguration(
            region: "us-east-1",
            model: .novaSonic2,
            voice: .tiffany,
            temperature: 0.7,
            topP: 0.9,
            maxTokens: 1024,
            systemPrompt: "You are a helpful assistant."
        )
        XCTAssertNoThrow(try cfg.validate())
    }

    // MARK: - Error Properties

    func testValidationFailedIsNotRetryable() {
        let error = NovaSonicError.validationFailed(field: "temperature", reason: "out of range")
        XCTAssertFalse(error.isRetryable)
    }

    func testValidationFailedHasDescriptiveMessage() {
        let error = NovaSonicError.validationFailed(field: "region", reason: "'eu-west-1' is not supported")
        XCTAssertTrue(error.localizedDescription.contains("region"))
        XCTAssertTrue(error.localizedDescription.contains("eu-west-1"))
    }

    func testValidationFailedHasRecoverySuggestion() {
        let error = NovaSonicError.validationFailed(field: "temperature", reason: "out of range")
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("temperature"))
    }
}
