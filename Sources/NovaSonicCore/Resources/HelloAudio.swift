//
//  HelloAudio.swift
//  NovaSonicCore
//
//  Public accessor for hello.wav resource
//

import Foundation

/// Public accessor for bundled hello.wav audio resource.
/// Returns nil when the resource is absent rather than crashing —
/// the speakFirst feature degrades gracefully to the text-prompt path.
public enum HelloAudio {
    /// Returns hello.wav audio data from the NovaSonicCore bundle, or nil if not found.
    public static func data() -> Data? {
        guard let url = Bundle.module.url(forResource: "hello", withExtension: "wav"),
              let bytes = try? Data(contentsOf: url) else {
            return nil
        }
        return bytes
    }

    /// Returns hello.wav URL from the NovaSonicCore bundle, or nil if not found.
    public static func url() -> URL? {
        return Bundle.module.url(forResource: "hello", withExtension: "wav")
    }
}
