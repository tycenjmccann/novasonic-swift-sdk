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

// MARK: - Session Update (Nova 2.0)

/// Builds the `session.update` event payload for mid-session configuration changes
/// (pronunciation replacements, language hint, key terms).
public struct SessionUpdateEvent {
    public let replace: [String: String]?
    public let languageHint: String?
    public let keyterms: [String]?

    public init(replace: [String: String]? = nil, languageHint: String? = nil, keyterms: [String]? = nil) {
        self.replace = replace
        self.languageHint = languageHint
        self.keyterms = keyterms
    }

    public func buildEvent() -> String {
        var sessionUpdate: [String: Any] = [:]

        if let replace = replace {
            sessionUpdate["replace"] = replace
        }
        if let languageHint = languageHint {
            sessionUpdate["inputTranscriptConfiguration"] = [
                "languageHint": languageHint
            ]
        }
        if let keyterms = keyterms {
            sessionUpdate["inputTranscriptConfiguration"] = {
                var config = sessionUpdate["inputTranscriptConfiguration"] as? [String: Any] ?? [:]
                config["keyterms"] = keyterms
                return config
            }()
        }

        let event: [String: Any] = [
            "event": [
                "sessionUpdate": sessionUpdate
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: event),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
