import XCTest
@testable import NovaSonicCore

final class AudioTransportTests: XCTestCase {

    func testEnumRawValues() {
        XCTAssertEqual(AudioTransport.json.rawValue, "json")
        XCTAssertEqual(AudioTransport.binary.rawValue, "binary")
    }

    func testCaseIterable() {
        let allCases = AudioTransport.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.json))
        XCTAssertTrue(allCases.contains(.binary))
    }

    func testCodableEncode() throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(AudioTransport.json)
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertEqual(jsonString, "\"json\"")

        let binaryData = try encoder.encode(AudioTransport.binary)
        let binaryString = String(data: binaryData, encoding: .utf8)
        XCTAssertEqual(binaryString, "\"binary\"")
    }

    func testCodableDecode() throws {
        let decoder = JSONDecoder()

        let jsonData = "\"json\"".data(using: .utf8)!
        let json = try decoder.decode(AudioTransport.self, from: jsonData)
        XCTAssertEqual(json, .json)

        let binaryData = "\"binary\"".data(using: .utf8)!
        let binary = try decoder.decode(AudioTransport.self, from: binaryData)
        XCTAssertEqual(binary, .binary)
    }

    func testEncodingValue() {
        XCTAssertEqual(AudioTransport.json.encodingValue, "base64")
        XCTAssertEqual(AudioTransport.binary.encodingValue, "none")
    }

    func testDisplayName() {
        XCTAssertEqual(AudioTransport.json.displayName, "JSON (base64)")
        XCTAssertEqual(AudioTransport.binary.displayName, "Binary (raw PCM)")
    }

    func testDefaultTransportIsJson() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.audioTransport, .json)
    }

    func testBinaryTransportCanBeConfigured() {
        let config = NovaSonicConfiguration(audioTransport: .binary)
        XCTAssertEqual(config.audioTransport, .binary)
    }

    func testSendableConformance() {
        // Verifies Sendable conformance by using in a Task (different isolation)
        let transport: AudioTransport = .binary
        let expectation = self.expectation(description: "sendable")
        Task {
            let _ = transport
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testCodableRoundTrip() throws {
        for transport in AudioTransport.allCases {
            let encoded = try JSONEncoder().encode(transport)
            let decoded = try JSONDecoder().decode(AudioTransport.self, from: encoded)
            XCTAssertEqual(transport, decoded)
        }
    }
}
