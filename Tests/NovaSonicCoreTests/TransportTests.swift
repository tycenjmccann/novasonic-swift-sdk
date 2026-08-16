import XCTest
@testable import NovaSonicCore

final class TransportTests: XCTestCase {

    // MARK: - AudioTransport

    func testFrameOverheadValues() {
        XCTAssertEqual(AudioTransport.json.frameOverhead, 0)
        XCTAssertEqual(AudioTransport.binary.frameOverhead, 4)
    }

    // MARK: - Configuration Validation

    func testBinaryTransportWithBedrockSDKThrows() {
        XCTAssertThrowsError(
            try NovaSonicConfiguration(
                audioTransport: .binary,
                connectionMode: .bedrockSDK
            ) as NovaSonicConfiguration
        ) { error in
            guard let novaSonicError = error as? NovaSonicError else {
                XCTFail("Expected NovaSonicError")
                return
            }
            if case .binaryTransportRequiresWebSocket = novaSonicError {
                // expected
            } else {
                XCTFail("Expected binaryTransportRequiresWebSocket, got \(novaSonicError)")
            }
        }
    }

    func testBinaryTransportWithWebSocketSucceeds() {
        let endpoint = URL(string: "wss://example.com/stream")!
        XCTAssertNoThrow(
            try NovaSonicConfiguration(
                audioTransport: .binary,
                connectionMode: .webSocket(endpoint: endpoint)
            ) as NovaSonicConfiguration
        )
    }

    func testLpcmWithNonDefaultInputRateThrows() {
        XCTAssertThrowsError(
            try NovaSonicConfiguration(
                inputSampleRate: .rate48kHz,
                inputMediaType: .lpcm
            ) as NovaSonicConfiguration
        ) { error in
            guard let novaSonicError = error as? NovaSonicError else {
                XCTFail("Expected NovaSonicError")
                return
            }
            if case .sampleRateNotApplicable(let direction, let mediaType) = novaSonicError {
                XCTAssertEqual(direction, .input)
                XCTAssertEqual(mediaType, .lpcm)
            } else {
                XCTFail("Expected sampleRateNotApplicable, got \(novaSonicError)")
            }
        }
    }

    func testLpcmWithNonDefaultOutputRateThrows() {
        XCTAssertThrowsError(
            try NovaSonicConfiguration(
                outputSampleRate: .rate48kHz,
                outputMediaType: .lpcm
            ) as NovaSonicConfiguration
        ) { error in
            guard let novaSonicError = error as? NovaSonicError else {
                XCTFail("Expected NovaSonicError")
                return
            }
            if case .sampleRateNotApplicable(let direction, let mediaType) = novaSonicError {
                XCTAssertEqual(direction, .output)
                XCTAssertEqual(mediaType, .lpcm)
            } else {
                XCTFail("Expected sampleRateNotApplicable, got \(novaSonicError)")
            }
        }
    }

    func testPcmWithAnyRateIsValid() {
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertNoThrow(
                try NovaSonicConfiguration(
                    inputSampleRate: rate,
                    outputSampleRate: rate,
                    inputMediaType: .pcm,
                    outputMediaType: .pcm
                ) as NovaSonicConfiguration,
                "PCM should accept any sample rate, failed for \(rate)"
            )
        }
    }

    func testDefaultConfigProducesCorrectDefaults() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.inputMediaType, .lpcm)
        XCTAssertEqual(config.outputMediaType, .lpcm)
        if case .json = config.audioTransport {
            // expected
        } else {
            XCTFail("Expected .json transport")
        }
        if case .bedrockSDK = config.connectionMode {
            // expected
        } else {
            XCTFail("Expected .bedrockSDK connection mode")
        }
    }

    func testDefaultConfigPreservesExistingBehavior() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.inputSampleRate, .rate16kHz)
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
        XCTAssertEqual(config.region, "us-east-1")
        XCTAssertEqual(config.model, .novaSonic2)
    }

    // MARK: - ConnectionMode

    func testConnectionModeWebSocketEndpoint() {
        let url = URL(string: "wss://nova-sonic.example.com/v1/stream")!
        let mode = ConnectionMode.webSocket(endpoint: url)
        if case .webSocket(let endpoint) = mode {
            XCTAssertEqual(endpoint, url)
        } else {
            XCTFail("Expected webSocket mode")
        }
    }

    // MARK: - AudioDirection

    func testAudioDirectionRawValues() {
        XCTAssertEqual(AudioDirection.input.rawValue, "input")
        XCTAssertEqual(AudioDirection.output.rawValue, "output")
    }

    // MARK: - Error properties

    func testNewErrorsAreNotRetryable() {
        let errors: [NovaSonicError] = [
            .sampleRateNotApplicable(direction: .input, mediaType: .lpcm),
            .binaryTransportRequiresWebSocket,
            .audioFrameSizeExceeded(expected: 320, actual: 640),
            .sessionUpdateRejected(field: "voice", reason: "invalid"),
        ]
        for error in errors {
            XCTAssertFalse(error.isRetryable, "\(error) should not be retryable")
        }
    }

    func testWebSocketConnectionFailedIsRetryable() {
        let error = NovaSonicError.webSocketConnectionFailed(underlying: nil)
        XCTAssertTrue(error.isRetryable)
    }

    func testNewErrorsHaveDescriptions() {
        let errors: [NovaSonicError] = [
            .sampleRateNotApplicable(direction: .input, mediaType: .lpcm),
            .binaryTransportRequiresWebSocket,
            .sessionUpdateRejected(field: "voice", reason: "invalid"),
            .webSocketConnectionFailed(underlying: nil),
            .audioFrameSizeExceeded(expected: 320, actual: 640),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
}
