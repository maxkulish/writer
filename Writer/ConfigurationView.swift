//
//  ConfigurationView.swift
//  Writer
//
//  Created by Max Kul on 24.12.2024.
//

import SwiftUI

// Settings storage class
class LlamaSettings: ObservableObject {
    @Published var endpointURL: String {
        didSet {
            UserDefaults.standard.set(endpointURL, forKey: "llamaEndpoint")
        }
    }
    
    @Published var promptTemplate: String {
        didSet {
            UserDefaults.standard.set(promptTemplate, forKey: "promptTemplate")
        }
    }
    
    @Published var hotkey: String {
        didSet {
            UserDefaults.standard.set(hotkey, forKey: "hotkey")
        }
    }
    
    init() {
        self.endpointURL = UserDefaults.standard.string(forKey: "llamaEndpoint") ?? "http://localhost:11434/api/generate"
        self.promptTemplate = UserDefaults.standard.string(forKey: "promptTemplate") ?? """
        {
            "model": "llama2",
            "prompt": "{{text}}",
            "temperature": 0.7,
            "max_tokens": 2000
        }
        """
        self.hotkey = UserDefaults.standard.string(forKey: "hotkey") ?? "⌃⇧Space"
    }
}

struct ConfigurationView: View {
    @EnvironmentObject var settings: LlamaSettings
    @State private var isRecordingHotkey = false
    
    var body: some View {
        Form {
            Section("Endpoint Configuration") {
                TextField("Llama API Endpoint", text: $settings.endpointURL)
                    .textFieldStyle(.roundedBorder)
                    .help("The URL of your Llama API endpoint")
                
                Text("Current: \(settings.endpointURL)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Hotkey Configuration") {
                HStack {
                    Text("Current Hotkey: \(settings.hotkey)")
                    
                    Button(isRecordingHotkey ? "Press your hotkey..." : "Record Hotkey") {
                        isRecordingHotkey.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
                
                Text("Click 'Record Hotkey' and press your desired key combination")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Prompt Template") {
                TextEditor(text: $settings.promptTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                
                Text("Use {{text}} as placeholder for selected text")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button("Save Changes") {
                    // Save will happen automatically through @Published properties
                    // You might want to add validation here
                    
                    // Example validation
                    guard URL(string: settings.endpointURL) != nil else {
                        // Handle invalid URL
                        return
                    }
                    
                    // Verify JSON template is valid
                    guard let jsonData = settings.promptTemplate.data(using: .utf8),
                          (try? JSONSerialization.jsonObject(with: jsonData)) != nil else {
                        // Handle invalid JSON
                        return
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 600)
    }
}

// Preview provider for SwiftUI canvas
struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationView()
    }
}
