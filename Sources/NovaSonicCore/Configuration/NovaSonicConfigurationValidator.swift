import Foundation

/// Validates audio configuration combinations.
internal enum NovaSonicConfigurationValidator {

    static func validate(codec: AudioCodec, sampleRate: NovaSonicSampleRate) throws {
        let allowed: Set<NovaSonicSampleRate>
        switch codec {
        case .pcm:
            allowed = Set(NovaSonicSampleRate.allCases)
        case .pcmu, .pcma:
            allowed = Set<NovaSonicSampleRate>([.rate8kHz])
        }

        guard allowed.contains(sampleRate) else {
            throw NovaSonicConfigurationError.invalidSampleRateForCodec(
                codec: codec,
                requested: sampleRate,
                allowed: allowed.sorted { $0.rawValue < $1.rawValue }
            )
        }
    }

    static func validate(codec: AudioCodec, transport: AudioTransport) throws {
        if transport == .binary && codec != .pcm {
            throw NovaSonicConfigurationError.binaryTransportRequiresPCM(codec: codec)
        }
    }

    static func validateAudioConfiguration(
        inputCodec: AudioCodec,
        outputCodec: AudioCodec,
        inputSampleRate: NovaSonicSampleRate,
        outputSampleRate: NovaSonicSampleRate,
        inputTransport: AudioTransport,
        outputTransport: AudioTransport
    ) throws {
        try validate(codec: inputCodec, sampleRate: inputSampleRate)
        try validate(codec: outputCodec, sampleRate: outputSampleRate)
        try validate(codec: inputCodec, transport: inputTransport)
        try validate(codec: outputCodec, transport: outputTransport)
    }
}
