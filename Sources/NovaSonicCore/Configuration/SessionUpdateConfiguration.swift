//
//  SessionUpdateConfiguration.swift
//  NovaSonic Package
//
//  Configuration for session.update events sent mid-session
//
import Foundation

/// Configuration for a `session.update` event that modifies pronunciation replacements,
/// language hint, or keyterms on an active streaming session.
public struct SessionUpdateConfiguration {

    /// Pronunciation replacement map for TTS substitution (case-insensitive, whole-word).
    public let replace: [String: String]?

    /// BCP-47 language code to bias transcription (e.g., "es-MX", "pt-BR").
    public let languageHint: String?

    /// Domain-specific vocabulary to bias transcription (max 100 items, each ≤ 50 chars).
    public let keyterms: [String]?

    public init(replace: [String: String]? = nil, languageHint: String? = nil, keyterms: [String]? = nil) {
        self.replace = replace
        self.languageHint = languageHint
        self.keyterms = keyterms
    }

    /// Validates the configuration, throwing `NovaSonicError.invalidConfiguration` on failure.
    public func validate() throws {
        // languageHint: reject bare "es" and "pt" (must use regional variants)
        if let hint = languageHint {
            let lower = hint.lowercased()
            if lower == "es" || lower == "pt" {
                throw NovaSonicError.invalidConfiguration
            }
        }

        // keyterms: max 100 items, each item ≤ 50 characters
        if let terms = keyterms {
            if terms.count > 100 {
                throw NovaSonicError.invalidConfiguration
            }
            for term in terms {
                if term.count > 50 {
                    throw NovaSonicError.invalidConfiguration
                }
            }
        }
    }
}
