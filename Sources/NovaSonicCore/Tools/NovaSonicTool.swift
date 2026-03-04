//
//  NovaSonicTool.swift
//  NovaSonic Package
//
//  Protocol for Nova Sonic tool integration and function calling
//

import Foundation

/// Protocol that defines a Nova Sonic tool for function calling
public protocol NovaSonicTool {
    /// Unique name identifier for the tool
    static var name: String { get }
    
    /// Human-readable description of what the tool does
    static var description: String { get }
    
    /// JSON schema defining the tool's input parameters
    static var schema: String { get }
    
    /// Handle tool execution with async completion
    /// - Parameters:
    ///   - input: Dictionary containing the tool parameters
    ///   - completion: Completion handler with the tool result
    static func handle(_ input: [String: Any], completion: @escaping ([String: Any]) -> Void)
}

/// Result wrapper for tool execution
public struct NovaSonicToolResult {
    public let success: Bool
    public let data: [String: Any]
    public let error: String?
    
    public init(success: Bool, data: [String: Any], error: String? = nil) {
        self.success = success
        self.data = data
        self.error = error
    }
    
    /// Convert to dictionary for JSON serialization
    public func toDictionary() -> [String: Any] {
        var result: [String: Any] = [
            "success": success,
            "data": data
        ]
        
        if let error = error {
            result["error"] = error
        }
        
        return result
    }
}

/// Convenience extensions for common tool patterns
public extension NovaSonicTool {
    /// Create a success result
    static func successResult(data: [String: Any]) -> [String: Any] {
        return NovaSonicToolResult(success: true, data: data).toDictionary()
    }
    
    /// Create an error result
    static func errorResult(message: String, data: [String: Any] = [:]) -> [String: Any] {
        return NovaSonicToolResult(success: false, data: data, error: message).toDictionary()
    }
}
