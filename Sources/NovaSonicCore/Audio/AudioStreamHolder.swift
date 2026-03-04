#if os(iOS)
//
//  AudioStreamHolder.swift
//  NovaSonic Package
//
//  Audio stream management for iOS Nova Sonic integration
//

import Foundation

// Thread-safe container for audio stream references.
public actor AudioStreamHolder {
    private var inputStream: AudioInputStream?
    private var outputStream: AudioOutputStream?
    
    public init() {}
    
    public func setStreams(input: AudioInputStream?, output: AudioOutputStream?) {
        self.inputStream = input
        self.outputStream = output
    }
    
    public func getInputStream() -> AudioInputStream? {
        return inputStream
    }
    
    public func getOutputStream() -> AudioOutputStream? {
        return outputStream
    }
    
    public func clearStreams() -> (AudioInputStream?, AudioOutputStream?) {
        let oldInput = inputStream
        let oldOutput = outputStream
        inputStream = nil
        outputStream = nil
        return (oldInput, oldOutput)
    }
}
#endif
