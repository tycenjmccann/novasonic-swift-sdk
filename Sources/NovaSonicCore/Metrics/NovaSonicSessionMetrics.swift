//
//  NovaSonicSessionMetrics.swift
//  NovaSonic Package
//
//  Latency and turn-level instrumentation for comparing Nova Sonic model versions.
//  All TimeInterval values are seconds elapsed since session start, measured on a
//  monotonic clock (DispatchTime) so they are unaffected by wall-clock changes.
//

import Foundation

/// Timing for a single tool round-trip: from the model's `toolUse` request to the
/// moment the SDK finishes sending the tool result back into the stream.
public struct ToolCallMetric: Codable, Equatable {
    public var toolName: String
    public var toolUseId: String
    public var requestedAt: TimeInterval
    public var resultSentAt: TimeInterval?

    /// Seconds between request and result being sent back, if completed.
    public var roundTripSeconds: TimeInterval? {
        guard let resultSentAt else { return nil }
        return resultSentAt - requestedAt
    }

    public init(toolName: String, toolUseId: String, requestedAt: TimeInterval, resultSentAt: TimeInterval? = nil) {
        self.toolName = toolName
        self.toolUseId = toolUseId
        self.requestedAt = requestedAt
        self.resultSentAt = resultSentAt
    }
}

/// Timing for one assistant turn (one user utterance → assistant response).
public struct TurnMetric: Codable, Equatable {
    public var turnIndex: Int
    /// First FINAL user transcription for this turn.
    public var userTranscriptAt: TimeInterval?
    /// First SPECULATIVE assistant text of the turn.
    public var firstSpeculativeTextAt: TimeInterval?
    /// First audio chunk of the turn — primary "latency feel" signal (time-to-first-audio).
    public var firstAudioChunkAt: TimeInterval?
    public var toolCalls: [ToolCallMetric]
    public var bargeIn: Bool

    /// Seconds from user transcript to first audio, if both are known and ordered correctly.
    /// Returns nil when audio predates the transcript (e.g. a barge-in turn whose first
    /// audio chunk belongs to the previous response) — such a value isn't a real latency.
    public var timeToFirstAudioSeconds: TimeInterval? {
        guard let userTranscriptAt, let firstAudioChunkAt,
              firstAudioChunkAt >= userTranscriptAt else { return nil }
        return firstAudioChunkAt - userTranscriptAt
    }

    public init(turnIndex: Int) {
        self.turnIndex = turnIndex
        self.userTranscriptAt = nil
        self.firstSpeculativeTextAt = nil
        self.firstAudioChunkAt = nil
        self.toolCalls = []
        self.bargeIn = false
    }
}

/// All timing captured for a single streaming session against one model.
public struct NovaSonicSessionMetrics: Codable, Equatable {
    public var modelId: String
    /// Wall-clock start of the session (for human-readable correlation only).
    public var startedAt: Date
    /// Seconds from session start until the Bedrock stream reported connected.
    public var connectionReadyAt: TimeInterval?
    public var turns: [TurnMetric]

    public init(modelId: String, startedAt: Date) {
        self.modelId = modelId
        self.startedAt = startedAt
        self.connectionReadyAt = nil
        self.turns = []
    }

    /// Median time-to-first-audio across turns that recorded it (seconds).
    public var medianTimeToFirstAudio: TimeInterval? {
        let values = turns.compactMap { $0.timeToFirstAudioSeconds }.sorted()
        guard !values.isEmpty else { return nil }
        let mid = values.count / 2
        return values.count % 2 == 0 ? (values[mid - 1] + values[mid]) / 2 : values[mid]
    }
}
