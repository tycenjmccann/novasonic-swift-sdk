import NovaSonicCore
import SwiftUI
import Foundation

/// Simple tool to change the color of a heart in the UI
public struct ChangeMyHeartTool: NovaSonicTool {
    
    // MARK: - NovaSonicTool Protocol
    
    public static let name = "changeMyHeart"
    
    public static let description = "Change the color of the heart displayed on screen"
    
    public static let schema = """
    {
      "type": "object",
      "properties": {
        "color": { 
          "type": "string", 
          "description": "The color to change the heart to (red, blue, green, purple, orange, pink, yellow, black, brown, grey, teal)" 
        }
      },
      "required": ["color"]
    }
    """
    
    // MARK: - UI Callback
    
    /// Callback to update the UI when heart color changes
    public static var onColorChange: ((Color) -> Void)?
    
    // MARK: - Tool Implementation
    
    public static func handle(_ input: [String: Any], completion: @escaping ([String: Any]) -> Void) {
        guard let colorString = input["color"] as? String, !colorString.isEmpty else {
            completion(errorResult(message: "Color parameter is required and cannot be empty"))
            return
        }
        
        print("💖 Changing heart color to: \(colorString)")
        
        // Convert string to SwiftUI Color
        let color = parseColor(from: colorString.lowercased())
        
        // Update the UI
        onColorChange?(color)
        
        let resultData: [String: Any] = [
            "color": colorString,
            "message": "Heart color changed to \(colorString)"
        ]
        
        print("✅ Heart color changed successfully to \(colorString)")
        completion(successResult(data: resultData))
    }
    
    // MARK: - Helper Methods
    
    private static func parseColor(from colorString: String) -> Color {
        switch colorString {
        case "red":
            return .red
        case "blue":
            return .blue
        case "green":
            return .green
        case "purple":
            return .purple
        case "orange":
            return .orange
        case "pink":
            return .pink
        case "yellow":
            return .yellow
        case "black":
            return .black
        case "brown":
            return .brown
        case "grey", "gray":
            return .gray
        case "teal":
            return .teal
        default:
            print("⚠️ Unknown color '\(colorString)', defaulting to red")
            return .red
        }
    }
}
