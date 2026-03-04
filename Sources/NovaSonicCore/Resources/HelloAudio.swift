//
//  HelloAudio.swift
//  NovaSonicCore
//
//  Public accessor for hello.wav resource
//

import Foundation

/// Public accessor for bundled hello.wav audio resource
public enum HelloAudio {
    /// Returns hello.wav audio data from the NovaSonicCore bundle
    public static func data() -> Data {
        guard let url = Bundle.module.url(forResource: "hello", withExtension: "wav"),
              let bytes = try? Data(contentsOf: url) else {
            fatalError("hello.wav not found in NovaSonicCore bundle")
        }
        return bytes
    }
    
    /// Returns hello.wav URL from the NovaSonicCore bundle
    public static func url() -> URL {
        guard let url = Bundle.module.url(forResource: "hello", withExtension: "wav") else {
            fatalError("hello.wav not found in NovaSonicCore bundle")
        }
        return url
    }
}
