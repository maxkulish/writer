//
//  ConfigurationViewModel.swift
//  Writer
//
//  Created by Max Kul on 24.12.2024.
//

import SwiftUI
import Combine

class ConfigurationViewModel: ObservableObject {
    @Published var isShowingAlert = false
    @Published var alertMessage = ""
    
    // Validation methods
    func validateEndpointURL(_ url: String) -> Bool {
        guard let url = URL(string: url) else {
            showAlert(message: "Invalid URL format")
            return false
        }
        
        guard url.scheme == "http" || url.scheme == "https" else {
            showAlert(message: "URL must start with http:// or https://")
            return false
        }
        
        return true
    }
    
    func validatePromptTemplate(_ template: String) -> Bool {
        guard let jsonData = template.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
            showAlert(message: "Invalid JSON format in prompt template")
            return false
        }
        
        guard template.contains("{{text}}") else {
            showAlert(message: "Prompt template must contain {{text}} placeholder")
            return false
        }
        
        return true
    }
    
    private func showAlert(message: String) {
        alertMessage = message
        isShowingAlert = true
    }
    
    // Convert hotkey event to string representation
    func hotkeyToString(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var hotkeyString = ""
        
        if modifiers.contains(.control) { hotkeyString += "⌃" }
        if modifiers.contains(.option) { hotkeyString += "⌥" }
        if modifiers.contains(.shift) { hotkeyString += "⇧" }
        if modifiers.contains(.command) { hotkeyString += "⌘" }
        
        // Convert keyCode to character
        switch keyCode {
        case 49: hotkeyString += "Space"
        case 123: hotkeyString += "←"
        case 124: hotkeyString += "→"
        case 125: hotkeyString += "↓"
        case 126: hotkeyString += "↑"
        default:
            if let character = String(format: "%c", keyCode).uppercased().first {
                hotkeyString += String(character)
            }
        }
        
        return hotkeyString
    }
}
