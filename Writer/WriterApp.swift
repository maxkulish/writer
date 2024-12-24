//
//  WriterApp.swift
//  Writer
//
//  Created by Max Kul on 24.12.2024.
//

import Cocoa
import Foundation
import Carbon.HIToolbox
import SwiftUI
import AppKit

// MARK: - Main App Delegate
@main
struct WriterApp: App {
    @StateObject private var settings = LlamaSettings()
    @StateObject private var textProcessor = TextProcessingService()
    @StateObject private var windowManager = WindowManager()
    
    init() {
        let textProcessor = TextProcessingService()
        _textProcessor = StateObject(wrappedValue: textProcessor)
        textProcessor.setup()
    }
    
    var body: some Scene {
        Settings {
            ConfigurationView()
                .environmentObject(settings)
                .environmentObject(windowManager)
                .frame(minWidth: 500, minHeight: 600)
                .onAppear {
                    windowManager.configureWindow()
                }
        }
        .windowResizability(.contentMinSize)
        
        WindowGroup(id: "dummy") { EmptyView() }
            .defaultSize(width: 0, height: 0)
            .windowStyle(.hiddenTitleBar)
        
        MenuBarExtra {
            Group {
                SettingsLink {
                    Text("Configuration...")
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Divider()
                
                Button("Quit Writer") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        } label: {
            Image(systemName: "text.bubble")
        }
    }
}

class WindowManager: ObservableObject {
    @Published var isConfigurationVisible = false
    private var windowDelegate: WindowDelegate?
    private var observationToken: NSObjectProtocol?
    
    init() {
        setupNotificationObserver()
    }
    
    deinit {
        if let token = observationToken {
            NotificationCenter.default.removeObserver(token)
        }
    }
    
    private func setupNotificationObserver() {
        observationToken = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let window = notification.object as? NSWindow,
               window.title == "Settings" {
                self?.isConfigurationVisible = false
            }
        }
    }
    
    func configureWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let window = NSApp.windows.first(where: { $0.title == "Settings" }) {
                self.windowDelegate = WindowDelegate(windowManager: self)
                window.delegate = self.windowDelegate
                
                window.title = "Writer Configuration"
                window.center()
                
                if !self.isConfigurationVisible {
                    window.orderOut(nil)
                }
            }
        }
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    weak var windowManager: WindowManager?
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        windowManager?.isConfigurationVisible = false
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        windowManager?.isConfigurationVisible = false
        return false
    }
}

extension NSWindow {
    func center() {
        guard let screen = NSScreen.main else { return }
        let rect = screen.frame
        let newX = rect.midX - frame.width/2
        let newY = rect.midY - frame.height/2
        setFrameOrigin(NSPoint(x: newX, y: newY))
    }
}

class TextProcessingService: ObservableObject {
    private var eventTap: CFMachPort?
    @Published var isProcessing = false
    let defaults = UserDefaults.standard
    
    func setup() {
        registerGlobalHotkey()
    }
    
    private func registerGlobalHotkey() {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                let service = Unmanaged<TextProcessingService>.fromOpaque(refcon!).takeUnretainedValue()
                return service.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }
        
        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .keyDown {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            if keycode == kVK_Space &&
                flags.contains(.maskControl) &&
                flags.contains(.maskShift) {
                DispatchQueue.main.async {
                    self.processSelectedText()
                }
                return nil
            }
        }
        return Unmanaged.passRetained(event)
    }
    
    private func processSelectedText() {
        print("🔍 [DEBUG] Starting text processing...")
        isProcessing = true
        let pasteboard = NSPasteboard.general
        
        // Save the original clipboard content
        let originalContent = pasteboard.string(forType: .string)
        print("📋 [DEBUG] Original clipboard content:", originalContent ?? "empty")
        
        // Clear the clipboard to ensure we can detect new content
        pasteboard.clearContents()
        print("🗑️ [DEBUG] Cleared clipboard")
        
        // Simulate CMD+C to copy selected text
        simulateCopyKeyPress()
        print("⌨️ [DEBUG] Simulated CMD+C keypress")
        
        // Increase delay to allow clipboard to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Adjust delay if needed
            guard let selectedText = pasteboard.string(forType: .string),
                  !selectedText.isEmpty,
                  selectedText != originalContent else {
                print("⚠️ [DEBUG] No new text was copied to clipboard")
                self.isProcessing = false
                return
            }
            
            print("✂️ [DEBUG] Selected text:", selectedText)
            self.sendToLlama(text: selectedText) { response in
                if let response = response {
                    print("🤖 [DEBUG] Received response from Llama")
                    pasteboard.clearContents()
                    pasteboard.setString(response, forType: .string)
                    
                    self.simulatePasteKeyPress()
                    print("📝 [DEBUG] Simulated paste with response")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let original = originalContent {
                            pasteboard.clearContents()
                            pasteboard.setString(original, forType: .string)
                            print("🔄 [DEBUG] Restored original clipboard content")
                        }
                        self.isProcessing = false
                    }
                } else {
                    print("❌ [DEBUG] Failed to get response from Llama")
                }
            }
        }
    }

    
    
    private func simulateCopyKeyPress() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func simulatePasteKeyPress() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func sendToLlama(text: String, completion: @escaping (String?) -> Void) {
        guard let promptTemplate = defaults.string(forKey: "promptTemplate"),
              let endpoint = defaults.string(forKey: "llamaEndpoint"),
              let url = URL(string: endpoint) else {
            print("❌ [DEBUG] Invalid configuration for LLaMA endpoint or prompt template.")
            completion(nil)
            return
        }

        let prompt = promptTemplate.replacingOccurrences(of: "{{text}}", with: text)
        print("📤 [DEBUG] Sending request to: \(endpoint)")
        print("📋 [DEBUG] Request payload: \(prompt)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = prompt.data(using: .utf8)

        var accumulatedResponse = ""

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [DEBUG] Network error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data,
                  let responseString = String(data: data, encoding: .utf8) else {
                print("❌ [DEBUG] No data received or invalid encoding")
                completion(nil)
                return
            }

            print("📥 [DEBUG] Raw response: \(responseString)")

            // Split response into individual JSON lines
            let jsonLines = responseString.split(separator: "\n")
            for line in jsonLines {
                if let lineData = line.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                   let responsePart = jsonObject["response"] as? String {
                    accumulatedResponse += responsePart
                } else {
                    print("⚠️ [DEBUG] Failed to parse JSON line: \(line)")
                }
            }

            print("✅ [DEBUG] Final accumulated response: \(accumulatedResponse)")
            completion(accumulatedResponse)
        }.resume()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: NSStatusBar!
    var statusItem: NSStatusItem!
    var configWindow: ConfigurationWindow?
    private var eventTap: CFMachPort?
    
    // Configuration storage
    let defaults = UserDefaults.standard
    var llamaEndpoint: String {
        get { defaults.string(forKey: "llamaEndpoint") ?? "http://localhost:11434" }
        set { defaults.set(newValue, forKey: "llamaEndpoint") }
    }
    var promptTemplate: String {
        get { defaults.string(forKey: "promptTemplate") ?? "{\"prompt\": \"{{text}}\"}" }
        set { defaults.set(newValue, forKey: "promptTemplate") }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        registerGlobalHotkey()
    }
    
    private func setupStatusBar() {
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Llama Text Processor")
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Configuration", action: #selector(showConfig), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    @objc func showConfig() {
        if configWindow == nil {
            configWindow = ConfigurationWindow()
        }
        configWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Hotkey Management
    private func registerGlobalHotkey() {
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                return delegate.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }
        
        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .keyDown {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // Check for Control + Shift + Space (example hotkey)
            if keycode == kVK_Space &&
                flags.contains(.maskControl) &&
                flags.contains(.maskShift) {
                DispatchQueue.main.async {
                    self.processSelectedText()
                }
                return nil // Consume the event
            }
        }
        return Unmanaged.passRetained(event)
    }
    
    // MARK: - Text Processing
    private func processSelectedText() {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let originalContent = pasteboard.string(forType: .string)
        
        // Simulate CMD+C to copy selected text
        simulateCopyKeyPress()
        
        // Small delay to ensure clipboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let selectedText = pasteboard.string(forType: .string) {
                self.sendToLlama(text: selectedText) { response in
                    if let response = response {
                        // Set response to clipboard
                        pasteboard.clearContents()
                        pasteboard.setString(response, forType: .string)
                        
                        // Simulate paste
                        self.simulatePasteKeyPress()
                        
                        // Restore original clipboard after a small delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if let original = originalContent {
                                pasteboard.clearContents()
                                pasteboard.setString(original, forType: .string)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func simulateCopyKeyPress() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)  // 'c' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func simulatePasteKeyPress() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)  // 'v' key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // MARK: - API Communication
    private func sendToLlama(text: String, completion: @escaping (String?) -> Void) {
        guard let promptTemplate = defaults.string(forKey: "promptTemplate"),
              let endpoint = defaults.string(forKey: "llamaEndpoint"),
              let url = URL(string: endpoint) else {
            print("Invalid configuration for LLaMA endpoint or prompt template.")
            completion(nil)
            return
        }

        let prompt = promptTemplate.replacingOccurrences(of: "{{text}}", with: text)
        print("Sending prompt: \(prompt) to \(endpoint)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = prompt.data(using: .utf8)

        // Create a data accumulator to handle streaming output
        var accumulatedResponse = ""

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request failed: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("No data received")
                completion(nil)
                return
            }

            if let responseFragment = String(data: data, encoding: .utf8) {
                // Accumulate the response fragments
                accumulatedResponse += responseFragment
                
                // Attempt to parse the `response` field from the last fragment
                if let jsonData = responseFragment.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let responseText = jsonObject["response"] as? String {
                    accumulatedResponse += responseText
                }
            }

            // Check if the response is marked as "done"
            if accumulatedResponse.contains("\"done\":true") {
                completion(accumulatedResponse)
            }
        }.resume()
    }


}

// MARK: - Configuration Window
class ConfigurationWindow: NSWindowController {
    let defaults = UserDefaults.standard
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Llama Text Processor Configuration"
        super.init(window: window)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentView!.bounds)
        window.contentView = contentView
        
        // Endpoint URL
        let endpointLabel = NSTextField(labelWithString: "Llama Endpoint URL:")
        endpointLabel.frame = NSRect(x: 20, y: 260, width: 150, height: 20)
        contentView.addSubview(endpointLabel)
        
        let endpointField = NSTextField(frame: NSRect(x: 20, y: 230, width: 360, height: 24))
        endpointField.stringValue = defaults.string(forKey: "llamaEndpoint") ?? "http://localhost:11434"
        endpointField.target = self
        endpointField.action = #selector(endpointChanged(_:))
        contentView.addSubview(endpointField)
        
        // Prompt Template
        let promptLabel = NSTextField(labelWithString: "Prompt Template (JSON):")
        promptLabel.frame = NSRect(x: 20, y: 190, width: 150, height: 20)
        contentView.addSubview(promptLabel)
        
        let promptField = NSTextView(frame: NSRect(x: 20, y: 90, width: 360, height: 90))
        promptField.string = defaults.string(forKey: "promptTemplate") ?? "{\"prompt\": \"{{text}}\"}"
        promptField.isEditable = true
        promptField.isRichText = false
        let scrollView = NSScrollView(frame: promptField.frame)
        scrollView.documentView = promptField
        scrollView.hasVerticalScroller = true
        contentView.addSubview(scrollView)
        
        // Hotkey info (static for now)
        let hotkeyLabel = NSTextField(labelWithString: "Hotkey: Control + Shift + Space")
        hotkeyLabel.frame = NSRect(x: 20, y: 50, width: 360, height: 20)
        contentView.addSubview(hotkeyLabel)
    }
    
    @objc func endpointChanged(_ sender: NSTextField) {
        defaults.set(sender.stringValue, forKey: "llamaEndpoint")
    }
    
    @objc func promptChanged(_ sender: NSTextView) {
        defaults.set(sender.string, forKey: "promptTemplate")
    }
}


