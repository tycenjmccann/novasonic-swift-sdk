//
//  NovaSonicToolRegistry.swift
//  NovaSonic Package
//
//  Global registry for Nova Sonic tools and function calling
//

import Foundation

/// Registry for managing Nova Sonic tools
public class NovaSonicToolRegistry {
    
    /// Shared singleton instance
    public static let shared = NovaSonicToolRegistry()
    
    /// Dictionary of registered tools by name
    private var tools: [String: NovaSonicTool.Type] = [:]
    
    /// Thread-safe access queue
    private let queue = DispatchQueue(label: "com.novasonic.toolregistry", attributes: .concurrent)
    
    private init() {}
    
    /// Register a tool in the registry
    /// - Parameter tool: The tool type to register
    public func register<T: NovaSonicTool>(_ tool: T.Type) {
        queue.async(flags: .barrier) {
            self.tools[tool.name] = tool
            NovaSonicLogger.standard("Registered tool: \(tool.name)")
        }
    }
    
    /// Unregister a tool from the registry
    /// - Parameter toolName: Name of the tool to unregister
    public func unregister(_ toolName: String) {
        queue.async(flags: .barrier) {
            self.tools.removeValue(forKey: toolName)
            NovaSonicLogger.standard("Unregistered tool: \(toolName)")
        }
    }
    
    /// Get all registered tool names
    /// - Returns: Array of tool names
    public func getRegisteredToolNames() -> [String] {
        return queue.sync {
            return Array(tools.keys)
        }
    }
    
    /// Get tool specifications for Nova Sonic configuration
    /// - Returns: Array of tool specifications
    public func getToolSpecs() -> [NovaSonicToolSpec] {
        return queue.sync {
            return tools.values.map { tool in
                NovaSonicToolSpec(
                    name: tool.name,
                    description: tool.description,
                    schema: tool.schema
                )
            }
        }
    }
    
    /// Execute a tool call
    /// - Parameters:
    ///   - toolName: Name of the tool to execute
    ///   - parameters: Parameters to pass to the tool
    ///   - toolUseId: Unique identifier for this tool use
    /// - Returns: Tool execution result
    public func executeToolCall(_ toolName: String, parameters: [String: Any], toolUseId: String) async -> [String: Any] {
        
        // Get the tool type from registry
        let toolType = queue.sync { tools[toolName] }
        
        guard let tool = toolType else {
            NovaSonicLogger.error("Tool not found: \(toolName)")
            return createErrorResult(message: "Tool '\(toolName)' not found in registry")
        }
        
        NovaSonicLogger.standard("Executing tool: \(toolName) with ID: \(toolUseId)")
        
        // Execute tool with async completion
        return await withCheckedContinuation { continuation in
            tool.handle(parameters) { result in
                NovaSonicLogger.standard("Tool \(toolName) completed with result: \(result)")
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Check if a tool is registered
    /// - Parameter toolName: Name of the tool to check
    /// - Returns: True if the tool is registered
    public func isToolRegistered(_ toolName: String) -> Bool {
        return queue.sync {
            return tools[toolName] != nil
        }
    }
    
    /// Clear all registered tools
    public func clearAll() {
        queue.async(flags: .barrier) {
            self.tools.removeAll()
            NovaSonicLogger.standard("Cleared all registered tools")
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Create an error result for tool execution failures
    private func createErrorResult(message: String, data: [String: Any] = [:]) -> [String: Any] {
        return NovaSonicToolResult(success: false, data: data, error: message).toDictionary()
    }
}

/// Extension for convenient tool registration
public extension NovaSonicToolRegistry {
    
    /// Register multiple tools at once
    /// - Parameter tools: Array of tool types to register
    func registerTools(_ tools: [NovaSonicTool.Type]) {
        for tool in tools {
            register(tool)
        }
    }
}
