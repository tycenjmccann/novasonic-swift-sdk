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

/// Builds the sparse JSON payload for a `session.update` event.
///
/// The payload structure places `replace` at the top level alongside `type`,
/// while `languageHint` and `keyterms` are nested under
/// `session.audio.input.transcription` with snake_case keys.
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
    public func buildEvent() -> String {
        var payload: [String: Any] = ["type": "session.update"]

        // replace at top level (nil omits key; empty dict serializes as {})
        if let replace = replace {
            payload["replace"] = replace
        }

        // Build nested session.audio.input.transcription
        var transcription: [String: Any] = [:]
        if let languageHint = languageHint {
            transcription["language_hint"] = languageHint
        }
        if let keyterms = keyterms, !keyterms.isEmpty {
            transcription["keyterms"] = keyterms
        }

        if !transcription.isEmpty {
            payload["session"] = [
                "audio": [
                    "input": [
                        "transcription": transcription
                    ]
                ]
            ]
        }

        let envelope: [String: Any] = ["event": ["sessionUpdate": payload]]

        guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"event\":{\"sessionUpdate\":{\"type\":\"session.update\"}}}"
        }
        return string
    }
}
