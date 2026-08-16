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

// MARK: - Session Updated Event

public struct SessionUpdatedEvent: Decodable {
    public let session: SessionEcho

    public struct SessionEcho: Decodable {
        public let voice: String?
        public let instructions: String?
        public let replace: [String: String]?
        public let audio: AudioConfig?

        public struct AudioConfig: Decodable {
            public let input: InputConfig

            public struct InputConfig: Decodable {
                public let transcription: TranscriptionConfig

                public struct TranscriptionConfig: Decodable {
                    public let languageHint: String?
                    public let keyterms: [String]?

                    enum CodingKeys: String, CodingKey {
                        case languageHint = "language_hint"
                        case keyterms
                    }
                }
            }
        }
    }
}

// MARK: - Tool Spec

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
