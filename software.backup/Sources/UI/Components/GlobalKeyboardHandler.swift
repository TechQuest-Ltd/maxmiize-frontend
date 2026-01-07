//
//  GlobalKeyboardHandler.swift
//  maxmiize-v1
//
//  Created by TechQuest on 23/12/2025.
//

import SwiftUI
import AppKit

/// View modifier for handling global keyboard shortcuts
struct GlobalKeyboardHandler: ViewModifier {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject var playerManager = SyncedVideoPlayerManager.shared
    @ObservedObject var focusManager = VideoPlayerFocusManager.shared
    let onEscapePressed: () -> Void
    @State private var keyboardMonitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    handleKeyPress(event: event)
                }
                print("🎹 GlobalKeyboardHandler keyboard monitor setup")
            }
            .onDisappear {
                if let monitor = keyboardMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyboardMonitor = nil
                    print("🔌 Removed GlobalKeyboardHandler keyboard monitor")
                }
            }
    }

    private func handleKeyPress(event: NSEvent) -> NSEvent? {
        // Space bar - Play/Pause (only if context is appropriate)
        if event.keyCode == 49 && !event.modifierFlags.contains(.command) {
            // Check if we should handle spacebar in current context
            if shouldHandleSpacebar() {
                print("⌨️ Space pressed - toggling play/pause")
                playerManager.togglePlayPause()
                return nil // Consume the event
            }
            // Let spacebar pass through (e.g., for text fields)
            return event
        }

        // ESC - Deactivate active moments
        if event.keyCode == 53 {
            print("⌨️ ESC pressed - deactivating moments")
            onEscapePressed()
            return nil // Consume the event
        }

        return event // Pass through other events
    }

    /// Determines if spacebar should trigger play/pause
    private func shouldHandleSpacebar() -> Bool {
        guard let window = NSApp.keyWindow else {
            print("⚠️ [GlobalKeyboard] No key window")
            return false
        }

        // Check if first responder is a text input field
        if let firstResponder = window.firstResponder {
            if firstResponder is NSTextView ||
               firstResponder is NSTextField ||
               String(describing: type(of: firstResponder)).contains("TextField") ||
               String(describing: type(of: firstResponder)).contains("TextEditor") {
                print("⚠️ [GlobalKeyboard] Text field focused - ignoring spacebar")
                return false
            }
        }

        // Check if main player has focus (not a popup)
        if !focusManager.shouldHandle(.mainPlayer) {
            print("⚠️ [GlobalKeyboard] Another player has focus (current: \(focusManager.focusedPlayer))")
            return false
        }

        // IMPORTANT: Only handle spacebar on Moments screen (where this handler is used)
        // Other screens (Playback, MaxView, Annotation) have their own keyboard handlers
        guard navigationState.currentScreen == .moments else {
            print("⚠️ [GlobalKeyboard] Not on Moments screen (current: \(navigationState.currentScreen))")
            return false
        }

        print("✅ [GlobalKeyboard] Has focus - handling spacebar on Moments screen")
        return true
    }
}

extension View {
    func globalKeyboardShortcuts(onEscape: @escaping () -> Void) -> some View {
        self.modifier(GlobalKeyboardHandler(onEscapePressed: onEscape))
    }
}
