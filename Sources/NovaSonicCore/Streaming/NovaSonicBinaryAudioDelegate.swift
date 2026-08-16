//
//  NovaSonicBinaryAudioDelegate.swift
//  NovaSonic Package
//
//  Delegate protocol for receiving binary audio frames.
//
import Foundation

/// Called when a binary audio frame is received from the service.
/// Default implementation forwards to the internal audio pipeline.
@MainActor
public protocol NovaSonicBinaryAudioDelegate: AnyObject {
    /// Invoked for each binary audio frame received in `.binary` transport mode.
    /// - Parameter frame: Raw PCM16 LE audio data at the configured output sample rate.
    func novaSonicStreamManager(
        _ manager: NovaSonicStreamManager,
        didReceiveBinaryAudioFrame frame: Data
    )
}
