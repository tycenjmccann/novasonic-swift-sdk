//
//  EventSupportingTypes.swift
//  NovaSonic Package
//
//  Types still referenced after EventBuilder.swift was removed:
//  BedrockEvents.sessionStartEvent uses SessionStartEvent, and
//  NovaSonicToolRegistry.getToolSpecs returns [NovaSonicToolSpec].
//  These were dropped when the dead EventBuilder duplicate was deleted,
//  which broke the build; restored here without the unused duplicates.
//
import Foundation

// MARK: - Event Builder Protocol

public protocol EventBuilder {
    static func buildEvent() -> String
}

// MARK: - Session Start

public struct SessionStartEvent: EventBuilder {
    public let maxTokens: Int
    public let topP: Double
    public let temperature: Double
    public let endpointingSensitivity: String?  // Nova 2.0

    public init(maxTokens: Int = 1024, topP: Double = 0.9, temperature: Double = 0.7, endpointingSensitivity: String? = nil) {
        self.maxTokens = maxTokens
        self.topP = topP
        self.temperature = temperature
        self.endpointingSensitivity = endpointingSensitivity
    }

    public static func buildEvent() -> String {
        SessionStartEvent().buildEvent()
    }

    public func buildEvent() -> String {
        var json = """
        {
            "event": {
                "sessionStart": {
                    "inferenceConfiguration": {
                        "maxTokens": \(maxTokens),
                        "topP": \(topP),
                        "temperature": \(temperature)
                    }
        """

        // Add turn detection configuration if provided (Nova 2.0)
        if let sensitivity = endpointingSensitivity {
            json += """
            ,
                    "turnDetectionConfiguration": {
                        "endpointingSensitivity": "\(sensitivity)"
                    }
            """
        }

        json += """

                }
            }
        }
        """

        return json
    }
}

// MARK: - Supporting Types

public struct NovaSonicToolSpec {
    public let name: String
    public let description: String
    public let schema: String

    public init(name: String, description: String, schema: String) {
        self.name = name
        self.description = description
        self.schema = schema
    }
}

// MARK: - Session Update

/// Builds the JSON payload for a `session.update` event.
///
/// The payload structure wraps everything in `event.sessionUpdate.session`:
/// - `replace` at `session.replace` (inside session object)
/// - `languageHint` at `session.audio.input.transcription.language_hint`
/// - `keyterms` at `session.audio.input.transcription.keyterms`
/// Only non-nil fields are included (sparse update semantics).
public struct SessionUpdateEvent {
    public let replace: [String: String]?
    public let languageHint: String?
    public let keyterms: [String]?

    public init(replace: [String: String]? = nil, languageHint: String? = nil, keyterms: [String]? = nil) {
        self.replace = replace
        self.languageHint = languageHint
        self.keyterms = keyterms
    }

    /// Serializes the event to a JSON string with correct nesting.
    /// Full path: event.sessionUpdate.session.replace
    /// Full path: event.sessionUpdate.session.audio.input.transcription.language_hint
    /// Full path: event.sessionUpdate.session.audio.input.transcription.keyterms
    public func buildEvent() -> String {
        var session: [String: Any] = [:]

        if let replace = replace, !replace.isEmpty {
            session["replace"] = replace
        }

        var transcription: [String: Any] = [:]
        if let languageHint = languageHint {
            transcription["language_hint"] = languageHint
        }
        if let keyterms = keyterms, !keyterms.isEmpty {
            transcription["keyterms"] = keyterms
        }

        if !transcription.isEmpty {
            session["audio"] = [
                "input": [
                    "transcription": transcription
                ]
            ]
        }

        let payload: [String: Any] = [
            "event": [
                "sessionUpdate": [
                    "session": session
                ]
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"event\":{\"sessionUpdate\":{\"session\":{}}}}"
        }
        return string
    }
}
