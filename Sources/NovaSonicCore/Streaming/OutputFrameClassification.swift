//
//  OutputFrameClassification.swift
//  NovaSonicCore
//
//  Frame classification logic for testable output routing.
//

import Foundation

/// Classification result for a received stream output frame.
public enum OutputFrameClassification {
    /// Successfully parsed as a JSON event dict.
    case jsonEvent([String: Any])
    /// Raw PCM audio data from a .chunk payload in binary mode.
    case binaryAudio(Data)
    /// Frame should be skipped (e.g. sdkUnknown or unparseable in JSON mode).
    case skipped(String)
}

extension NovaSonicStreamManager {
    /// Classify an output frame for routing decisions.
    ///
    /// - Parameters:
    ///   - bytes: The raw bytes extracted from the output frame.
    ///   - isChunkOutput: Whether the frame originated from a `.chunk` union case.
    ///   - outputTransport: The configured output transport mode.
    /// - Returns: Classification indicating how the frame should be handled.
    @MainActor
    internal static func classifyOutputFrame(
        bytes: Data,
        isChunkOutput: Bool,
        outputTransport: AudioTransportMode
    ) -> OutputFrameClassification {
        // Attempt JSON parsing first
        let jsonString = String(decoding: bytes, as: UTF8.self)
        if let jsonData = jsonString.data(using: .utf8),
           let topLevel = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let event = topLevel["event"] as? [String: Any] {
            return .jsonEvent(event)
        }

        // Non-JSON: only .chunk payloads in binary transport mode are raw audio
        if outputTransport == .binary && isChunkOutput {
            return .binaryAudio(bytes)
        }

        // Everything else should be skipped
        let reason = isChunkOutput ? "unparseable chunk in JSON mode" : "sdkUnknown"
        return .skipped(reason)
    }
}
