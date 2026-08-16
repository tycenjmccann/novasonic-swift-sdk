#if IOS_AUDIO
import AVFAudio
import Foundation

/// Factory for creating AVAudioFormat and AVAudioConverter instances for codec conversion.
internal enum AudioFormatFactory {

    /// Creates the AVAudioFormat for PCM Int16 mono at the specified rate.
    static func pcmFormat(rate: NovaSonicSampleRate) -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(rate.rawValue),
            channels: 1,
            interleaved: true
        )
    }

    /// Creates the AVAudioFormat for G.711 wire encoding (µ-law or A-law at 8kHz).
    static func g711Format(codec: AudioCodec) -> AVAudioFormat? {
        guard codec == .pcmu || codec == .pcma else { return nil }
        let formatID: AudioFormatID = (codec == .pcmu) ? kAudioFormatULaw : kAudioFormatALaw
        var asbd = AudioStreamBasicDescription(
            mSampleRate: 8000,
            mFormatID: formatID,
            mFormatFlags: 0,
            mBytesPerPacket: 1,
            mFramesPerPacket: 1,
            mBytesPerFrame: 1,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 8,
            mReserved: 0
        )
        return AVAudioFormat(streamDescription: &asbd)
    }

    /// AVAudioConverter from PCM Int16 @ 8kHz → G.711.
    static func makeEncoder(codec: AudioCodec) -> AVAudioConverter? {
        guard let src = pcmFormat(rate: .rate8kHz),
              let dst = g711Format(codec: codec) else { return nil }
        return AVAudioConverter(from: src, to: dst)
    }

    /// AVAudioConverter from G.711 → PCM Int16 @ 8kHz.
    static func makeDecoder(codec: AudioCodec) -> AVAudioConverter? {
        guard let src = g711Format(codec: codec),
              let dst = pcmFormat(rate: .rate8kHz) else { return nil }
        return AVAudioConverter(from: src, to: dst)
    }
}
#endif
