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

        // Add pronunciation replacements if provided (non-nil and non-empty)
        if let replaceDict = replace, !replaceDict.isEmpty {
            if let data = try? JSONSerialization.data(withJSONObject: replaceDict, options: [.sortedKeys]),
               let replaceJSON = String(data: data, encoding: .utf8) {
                json += """
                ,
                        "replace": \(replaceJSON)
                """
            }
        }

        // Add audio input configuration (language_hint and/or keyterms)
        let hasLanguageHint = languageHint != nil
        let hasKeyterms = keyterms != nil && !(keyterms?.isEmpty ?? true)

        if hasLanguageHint || hasKeyterms {
            json += """
            ,
                    "audioInputConfiguration": {
                        "transcription": {
            """

            var transcriptionFields: [String] = []

            if let hint = languageHint {
                transcriptionFields.append("""
                            "language_hint": "\(hint)"
                """)
            }

            if let terms = keyterms, !terms.isEmpty {
                if let data = try? JSONSerialization.data(withJSONObject: terms),
                   let termsJSON = String(data: data, encoding: .utf8) {
                    transcriptionFields.append("""
                            "keyterms": \(termsJSON)
                    """)
                }
            }

            json += transcriptionFields.joined(separator: ",\n")

            json += """

                        }
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
