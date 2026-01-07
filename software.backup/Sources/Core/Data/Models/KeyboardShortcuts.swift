//
//  KeyboardShortcuts.swift
//  maxmiize-v1
//
//  Created by TechQuest on 14/12/2025.
//

import Foundation
import SwiftUI
import Combine

/// Keyboard shortcut action types
enum ShortcutAction: String, CaseIterable, Codable {
    // Playback
    case playPause = "Play/Pause"
    case skipForward = "Skip Forward 5s"
    case skipBackward = "Skip Backward 5s"
    case speedUp = "Speed Up"
    case speedDown = "Speed Down"

    // Clip Marking
    case markIn = "Mark In Point"
    case markOut = "Mark Out Point"
    case createClip = "Create Clip"
    case clearMarks = "Clear In/Out Points"

    // Navigation
    case previousClip = "Previous Clip"
    case nextClip = "Next Clip"
    case goToClipStart = "Go to Clip Start"

    // View
    case toggleTimeline = "Toggle Timeline"
    case toggleClipsPanel = "Toggle Clips Panel"
    case focusVideo = "Focus Video"

    // Tagging - Shots
    case tagShotPaint = "Tag Shot - Paint"
    case tagShotMidRange = "Tag Shot - Mid-Range"
    case tagShotThree = "Tag Shot - Three-Point"
    case tagFreeThrow = "Tag Free Throw"

    // Tagging - Offensive Actions
    case tagAssist = "Tag Assist"
    case tagOffensiveRebound = "Tag Offensive Rebound"
    case tagTurnover = "Tag Turnover"

    // Tagging - Defensive Actions
    case tagDefensiveRebound = "Tag Defensive Rebound"
    case tagSteal = "Tag Steal"
    case tagBlock = "Tag Block"

    var category: ShortcutCategory {
        switch self {
        case .playPause, .skipForward, .skipBackward, .speedUp, .speedDown:
            return .playback
        case .markIn, .markOut, .createClip, .clearMarks:
            return .clipping
        case .previousClip, .nextClip, .goToClipStart:
            return .navigation
        case .toggleTimeline, .toggleClipsPanel, .focusVideo:
            return .view
        case .tagShotPaint, .tagShotMidRange, .tagShotThree, .tagFreeThrow,
             .tagAssist, .tagOffensiveRebound, .tagTurnover,
             .tagDefensiveRebound, .tagSteal, .tagBlock:
            return .tagging
        }
    }
}

enum ShortcutCategory: String, CaseIterable {
    case playback = "Playback"
    case clipping = "Clipping"
    case navigation = "Navigation"
    case view = "View"
    case tagging = "Moments"
}

/// Represents a keyboard shortcut with modifiers
struct KeyboardShortcut: Codable, Equatable {
    let key: String
    let modifiers: Set<ShortcutModifier>

    init(key: String, modifiers: Set<ShortcutModifier> = []) {
        self.key = key.uppercased()
        self.modifiers = modifiers
    }

    /// Display string for UI (e.g., "⌘⇧I")
    var displayString: String {
        let modifierSymbols = modifiers.sorted { $0.rawValue < $1.rawValue }
            .map { $0.symbol }
            .joined()
        return modifierSymbols + key
    }

    /// Human-readable string (e.g., "Command+Shift+I")
    var readableString: String {
        let modifierNames = modifiers.sorted { $0.rawValue < $1.rawValue }
            .map { $0.name }
        return (modifierNames + [key]).joined(separator: "+")
    }
}

enum ShortcutModifier: String, Codable, Comparable, Hashable {
    case command = "command"
    case shift = "shift"
    case option = "option"
    case control = "control"

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }

    var name: String {
        switch self {
        case .command: return "Cmd"
        case .shift: return "Shift"
        case .option: return "Option"
        case .control: return "Ctrl"
        }
    }

    static func < (lhs: ShortcutModifier, rhs: ShortcutModifier) -> Bool {
        let order: [ShortcutModifier] = [.control, .option, .shift, .command]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Manages keyboard shortcuts configuration
@MainActor
class KeyboardShortcutsManager: ObservableObject {
    static let shared = KeyboardShortcutsManager()

    @Published private(set) var shortcuts: [ShortcutAction: KeyboardShortcut]

    private let userDefaultsKey = "keyboardShortcuts"

    private init() {
        // Load saved shortcuts or use defaults
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ShortcutAction: KeyboardShortcut].self, from: savedData) {
            self.shortcuts = decoded
        } else {
            self.shortcuts = Self.defaultShortcuts
        }
    }

    /// Default keyboard shortcuts (sports analysis industry standard)
    static var defaultShortcuts: [ShortcutAction: KeyboardShortcut] {
        [
            // Playback
            .playPause: KeyboardShortcut(key: "Space"),
            .skipForward: KeyboardShortcut(key: "→"),
            .skipBackward: KeyboardShortcut(key: "←"),
            .speedUp: KeyboardShortcut(key: "]"),
            .speedDown: KeyboardShortcut(key: "["),

            // Clip Marking (industry standard: I/O for In/Out)
            .markIn: KeyboardShortcut(key: "I"),
            .markOut: KeyboardShortcut(key: "O"),
            .createClip: KeyboardShortcut(key: "C"),
            .clearMarks: KeyboardShortcut(key: "X", modifiers: [.shift]),

            // Navigation
            .previousClip: KeyboardShortcut(key: "↑"),
            .nextClip: KeyboardShortcut(key: "↓"),
            .goToClipStart: KeyboardShortcut(key: "Home"),

            // View
            .toggleTimeline: KeyboardShortcut(key: "T", modifiers: [.command]),
            .toggleClipsPanel: KeyboardShortcut(key: "L", modifiers: [.command]),
            .focusVideo: KeyboardShortcut(key: "F"),

            // Tagging - Shots (matching BasketballTagTemplates)
            .tagShotPaint: KeyboardShortcut(key: "1"),
            .tagShotMidRange: KeyboardShortcut(key: "2"),
            .tagShotThree: KeyboardShortcut(key: "3"),
            .tagFreeThrow: KeyboardShortcut(key: "F", modifiers: [.shift]),

            // Tagging - Offensive Actions
            .tagAssist: KeyboardShortcut(key: "A"),
            .tagOffensiveRebound: KeyboardShortcut(key: "R"),
            .tagTurnover: KeyboardShortcut(key: "T"),

            // Tagging - Defensive Actions
            .tagDefensiveRebound: KeyboardShortcut(key: "D"),
            .tagSteal: KeyboardShortcut(key: "S"),
            .tagBlock: KeyboardShortcut(key: "B"),
        ]
    }

    /// Update a shortcut
    func setShortcut(_ shortcut: KeyboardShortcut, for action: ShortcutAction) {
        shortcuts[action] = shortcut
        save()
    }

    /// Reset to defaults
    func resetToDefaults() {
        shortcuts = Self.defaultShortcuts
        save()
    }

    /// Reset specific category to defaults
    func resetCategory(_ category: ShortcutCategory) {
        for action in ShortcutAction.allCases where action.category == category {
            shortcuts[action] = Self.defaultShortcuts[action]
        }
        save()
    }

    /// Get shortcut for action
    func shortcut(for action: ShortcutAction) -> KeyboardShortcut? {
        return shortcuts[action]
    }

    /// Check if a shortcut is already used
    func isShortcutInUse(_ shortcut: KeyboardShortcut, excluding action: ShortcutAction? = nil) -> ShortcutAction? {
        return shortcuts.first { (existingAction, existingShortcut) in
            guard existingAction != action else { return false }
            return existingShortcut == shortcut
        }?.key
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
        objectWillChange.send()
    }
}
