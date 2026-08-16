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
    public let replace: [String: String]?
    public let languageHint: String?
    public let keyterms: [String]?

    public init(maxTokens: Int = 1024, topP: Double = 0.9, temperature: Double = 0.7, endpointingSensitivity: String? = nil, replace: [String: String]? = nil, languageHint: String? = nil, keyterms: [String]? = nil) {
        self.maxTokens = maxTokens
        self.topP = topP
        self.temperature = temperature
        self.endpointingSensitivity = endpointingSensitivity
        self.replace = replace
        self.languageHint = languageHint
        self.keyterms = keyterms
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

        // Add replace dictionary if provided
        if let replace = replace, !replace.isEmpty {
            if let replaceData = try? JSONSerialization.data(withJSONObject: replace),
               let replaceString = String(data: replaceData, encoding: .utf8) {
                json += ",\n                \"replace\": \(replaceString)"
            }
        }

        // Add transcription configuration (language_hint, keyterms)
        var transcription: [String: Any] = [:]
        if let languageHint = languageHint {
            transcription["language_hint"] = languageHint
        }
        if let keyterms = keyterms, !keyterms.isEmpty {
            transcription["keyterms"] = keyterms
        }
        if !transcription.isEmpty {
            let audio: [String: Any] = ["input": ["transcription": transcription]]
            if let audioData = try? JSONSerialization.data(withJSONObject: audio),
               let audioString = String(data: audioData, encoding: .utf8) {
                json += ",\n                \"audio\": \(audioString)"
            }
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
