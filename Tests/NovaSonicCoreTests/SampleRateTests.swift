import XCTest
@testable import NovaSonicCore

final class SampleRateTests: XCTestCase {

    func testAllSevenRatesExist() {
        let allRates = NovaSonicSampleRate.allCases
        XCTAssertEqual(allRates.count, 7)
    }

    func testRawValuesMatchExpected() {
        XCTAssertEqual(NovaSonicSampleRate.rate8kHz.rawValue, 8000)
        XCTAssertEqual(NovaSonicSampleRate.rate16kHz.rawValue, 16000)
        XCTAssertEqual(NovaSonicSampleRate.rate22050Hz.rawValue, 22050)
        XCTAssertEqual(NovaSonicSampleRate.rate24kHz.rawValue, 24000)
        XCTAssertEqual(NovaSonicSampleRate.rate32kHz.rawValue, 32000)
        XCTAssertEqual(NovaSonicSampleRate.rate44100Hz.rawValue, 44100)
        XCTAssertEqual(NovaSonicSampleRate.rate48kHz.rawValue, 48000)
    }

    func testHertzPropertyMatchesRawValue() {
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertEqual(rate.hertz, rate.rawValue)
        }
    }

    func testBytesPerSecond() {
        XCTAssertEqual(NovaSonicSampleRate.rate16kHz.bytesPerSecond, 32000)
        XCTAssertEqual(NovaSonicSampleRate.rate48kHz.bytesPerSecond, 96000)
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertEqual(rate.bytesPerSecond, rate.rawValue * 2)
        }
    }

    func testDefaultInputRateIs16kHz() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.inputSampleRate, .rate16kHz)
    }

    func testDefaultOutputRateIs24kHz() {
        let config = NovaSonicConfiguration()
        XCTAssertEqual(config.outputSampleRate, .rate24kHz)
    }

    func testAllRatesCanBeUsedForInput() {
        for rate in NovaSonicSampleRate.allCases {
            let config = NovaSonicConfiguration(inputSampleRate: rate)
            XCTAssertEqual(config.inputSampleRate, rate)
        }
    }

    func testAllRatesCanBeUsedForOutput() {
        for rate in NovaSonicSampleRate.allCases {
            let config = NovaSonicConfiguration(outputSampleRate: rate)
            XCTAssertEqual(config.outputSampleRate, rate)
        }
    }

    func testDisplayNameNotEmpty() {
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertFalse(rate.displayName.isEmpty)
        }
    }

    func testRateOrdering() {
        let rates = NovaSonicSampleRate.allCases.map { $0.rawValue }
        XCTAssertEqual(rates, rates.sorted())
    }
}
