import XCTest
@testable import NovaSonicCore

final class SampleRateTests: XCTestCase {

    // MARK: - NovaSonicSampleRate

    func testAllSampleRateRawValues() {
        XCTAssertEqual(NovaSonicSampleRate.rate8kHz.rawValue, 8000)
        XCTAssertEqual(NovaSonicSampleRate.rate16kHz.rawValue, 16000)
        XCTAssertEqual(NovaSonicSampleRate.rate22kHz.rawValue, 22050)
        XCTAssertEqual(NovaSonicSampleRate.rate24kHz.rawValue, 24000)
        XCTAssertEqual(NovaSonicSampleRate.rate32kHz.rawValue, 32000)
        XCTAssertEqual(NovaSonicSampleRate.rate44kHz.rawValue, 44100)
        XCTAssertEqual(NovaSonicSampleRate.rate48kHz.rawValue, 48000)
    }

    func testHertzMatchesRawValue() {
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertEqual(rate.hertz, rate.rawValue)
        }
    }

    func testSampleRateCount() {
        XCTAssertEqual(NovaSonicSampleRate.allCases.count, 7)
    }

    func testBytesPerFrame() {
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertEqual(rate.bytesPerFrame, 2, "16-bit mono PCM = 2 bytes per frame for \(rate)")
        }
    }

    func testDisplayNameNotEmpty() {
        for rate in NovaSonicSampleRate.allCases {
            XCTAssertFalse(rate.displayName.isEmpty)
        }
    }

    // MARK: - AudioMediaType

    func testAudioMediaTypeWireValues() {
        XCTAssertEqual(AudioMediaType.lpcm.wireValue, "audio/lpcm")
        XCTAssertEqual(AudioMediaType.pcm.wireValue, "audio/pcm")
        XCTAssertEqual(AudioMediaType.pcmu.wireValue, "audio/pcmu")
        XCTAssertEqual(AudioMediaType.pcma.wireValue, "audio/pcma")
    }

    func testAudioMediaTypeRawValues() {
        XCTAssertEqual(AudioMediaType.lpcm.rawValue, "audio/lpcm")
        XCTAssertEqual(AudioMediaType.pcm.rawValue, "audio/pcm")
        XCTAssertEqual(AudioMediaType.pcmu.rawValue, "audio/pcmu")
        XCTAssertEqual(AudioMediaType.pcma.rawValue, "audio/pcma")
    }

    func testSupportsSampleRate() {
        XCTAssertTrue(AudioMediaType.pcm.supportsSampleRate)
        XCTAssertFalse(AudioMediaType.lpcm.supportsSampleRate)
        XCTAssertFalse(AudioMediaType.pcmu.supportsSampleRate)
        XCTAssertFalse(AudioMediaType.pcma.supportsSampleRate)
    }

    func testAudioMediaTypeCaseCount() {
        XCTAssertEqual(AudioMediaType.allCases.count, 4)
    }
}
