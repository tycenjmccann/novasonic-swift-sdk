import Foundation

/// Represents a mid-session update to be sent to the Nova Sonic service
public struct SessionUpdate: @unchecked Sendable {
    internal let fields: [String: Any]
    internal let type = "session.update"

    internal init(fields: [String: Any]) {
        self.fields = fields
    }

    /// Serializes the session update to JSON data for wire transmission
    public func toJSONData() -> Data? {
        let payload: [String: Any] = [
            "type": type,
            "session": fields
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }
}

/// Builder for constructing `SessionUpdate` instances with validated fields
public struct SessionUpdateBuilder {
    private var fields: [String: Any] = [:]

    public init() {}

    /// Set the voice for the session
    @discardableResult
    public mutating func voice(_ voice: NovaSonicVoice) -> SessionUpdateBuilder {
        fields["voiceId"] = voice.rawValue
        return self
    }

    /// Set the system prompt for the session
    @discardableResult
    public mutating func systemPrompt(_ prompt: String) -> SessionUpdateBuilder {
        fields["systemPrompt"] = prompt
        return self
    }

    /// Set the temperature for the session
    @discardableResult
    public mutating func temperature(_ value: Double) -> SessionUpdateBuilder {
        fields["temperature"] = value
        return self
    }

    /// Set the topP for the session
    @discardableResult
    public mutating func topP(_ value: Double) -> SessionUpdateBuilder {
        fields["topP"] = value
        return self
    }

    /// Build the session update, returning nil if no fields were set
    public func build() -> SessionUpdate? {
        guard !fields.isEmpty else { return nil }
        return SessionUpdate(fields: fields)
    }
}
