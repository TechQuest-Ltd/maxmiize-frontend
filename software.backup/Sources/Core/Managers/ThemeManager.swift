//
//  ThemeManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 04/01/2026.
//

import SwiftUI
import Combine
import AppKit

/// Centralized theme manager that provides colors based on the current theme mode
///
/// IMPORTANT: When creating new SwiftUI views/components:
/// 1. Add `@EnvironmentObject var themeManager: ThemeManager` to your view
/// 2. Access colors via: `var theme: ThemeColors { themeManager.colors }`
/// 3. DO NOT use `ThemeManager.shared.colors` directly (won't update reactively)
/// 4. ThemeManager is already injected at app root - no need to pass it explicitly
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    private let settings = SettingsManager.shared
    private var themeModeObserver: NSObjectProtocol?
    
    private init() {
        // Listen for UserDefaults changes to update theme immediately
        themeModeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
    
    deinit {
        if let observer = themeModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    var colors: ThemeColors {
        currentTheme.colors
    }
    
    var currentTheme: Theme {
        switch settings.themeMode.lowercased() {
        case "light":
            return .light
        case "dark":
            return .dark
        case "auto":
            return .systemTheme
        default:
            return .dark
        }
    }
    
    /// Returns true if the current effective theme is light mode
    var isLightMode: Bool {
        switch settings.themeMode.lowercased() {
        case "light":
            return true
        case "dark":
            return false
        case "auto":
            // Check system appearance
            return NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
        default:
            return false
        }
    }
}

// MARK: - Theme

enum Theme {
    case light
    case dark
    case auto
    
    static var systemTheme: Theme {
        // Check system appearance
        if NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return .dark
        } else {
            return .light
        }
    }
    
    var colors: ThemeColors {
        switch self {
        case .light:
            return ThemeColors.light
        case .dark:
            return ThemeColors.dark
        case .auto:
            return Theme.systemTheme.colors
        }
    }
}

// MARK: - ThemeColors

struct ThemeColors {
    // Background colors (from darkest to lightest)
    let primaryBackground: Color      // Main app background
    let secondaryBackground: Color    // Panels and containers
    let tertiaryBackground: Color     // Elevated surfaces
    let surfaceBackground: Color      // Cards and sections
    let cardBackground: Color         // Individual items
    let inputBackground: Color        // Text fields, inputs
    
    // Text colors (from most prominent to subtle)
    let primaryText: Color            // Main headings, important text
    let secondaryText: Color          // Body text, labels
    let tertiaryText: Color           // Muted text, placeholders
    let quaternaryText: Color         // Very subtle text, disabled
    
    // Border colors
    let primaryBorder: Color          // Main dividers
    let secondaryBorder: Color        // Subtle borders
    
    // Accent colors
    let accent: Color                 // Primary blue
    let accentSecondary: Color        // Muted blue background
    let accentLight: Color            // Light blue for hover states
    
    // Status colors
    let error: Color                  // Red for errors/delete
    let success: Color                // Green for success/complete
    let warning: Color                // Orange/Yellow for warnings
    
    // Special UI colors
    let hover: Color                  // Hover state background
    let selected: Color               // Selected item background
    let disabled: Color               // Disabled state
    
    // Overlay colors
    let overlayDark: Color
    let overlayLight: Color
    
    // MARK: - Preset Themes
    
    static let dark = ThemeColors(
        // Backgrounds - Consistent hierarchy (user specified: #0D0D0D, #151619, #1A1B1D, #222329)
        primaryBackground: Color(hex: "0D0D0D"),        // Main app background - darkest (#0D0D0D)
        secondaryBackground: Color(hex: "151619"),      // Panels and containers (#151619)
        tertiaryBackground: Color(hex: "151619"),       // Elevated surfaces (same as panels)
        surfaceBackground: Color(hex: "1A1B1D"),        // Cards and collapsible sections inside panels (#1A1B1D)
        cardBackground: Color(hex: "1A1B1D"),           // Individual items (same as surface)
        inputBackground: Color(hex: "151619"),          // Text fields (same as panels)

        // Text - Clear hierarchy
        primaryText: Color.white,                       // #FFFFFF - Main headings
        secondaryText: Color(hex: "e4e4e6"),           // Body text, labels
        tertiaryText: Color(hex: "85868a"),            // Muted text, placeholders
        quaternaryText: Color(hex: "6a6a6a"),          // Very subtle, disabled

        // Borders - Using exact color specified by user
        primaryBorder: Color(hex: "222329"),           // Main dividers and borders everywhere (#222329)
        secondaryBorder: Color(hex: "222329"),         // Subtle borders (same as primary for consistency)
        
        // Accent - Using exact blue specified by user
        accent: Color(hex: "2979ff"),                  // Primary blue (user specified)
        accentSecondary: Color(hex: "1c283d"),         // Muted blue background
        accentLight: Color(hex: "5c9eff"),             // Light blue for hover
        
        // Status colors - Consistent
        error: Color(hex: "ff4b4b"),                   // Red for errors
        success: Color(hex: "27c46d"),                 // Green for success
        warning: Color(hex: "f5c14e"),                 // Yellow for warnings
        
        // Special UI states
        hover: Color(hex: "222329"),                   // Hover state
        selected: Color(hex: "202127"),                // Selected item
        disabled: Color(hex: "4a4a4a"),                // Disabled state
        
        // Overlays
        overlayDark: Color.black.opacity(0.6),
        overlayLight: Color.white.opacity(0.1)
    )
    
    static let light = ThemeColors(
        // Backgrounds - Clean light theme with consistent hierarchy
        primaryBackground: Color(hex: "ffffff"),        // Main app background (white)
        secondaryBackground: Color(hex: "f5f5f5"),      // Panels and containers
        tertiaryBackground: Color(hex: "f0f0f0"),       // Elevated surfaces
        surfaceBackground: Color(hex: "fafafa"),        // Cards and sections
        cardBackground: Color(hex: "ffffff"),           // Individual items (white)
        inputBackground: Color(hex: "f5f5f5"),          // Text fields
        
        // Text - Inverted from dark theme
        primaryText: Color(hex: "0d0d0d"),              // Main headings (dark)
        secondaryText: Color(hex: "424242"),            // Body text, labels
        tertiaryText: Color(hex: "757575"),             // Muted text, placeholders
        quaternaryText: Color(hex: "9a9a9a"),           // Very subtle, disabled
        
        // Borders - Light borders
        primaryBorder: Color(hex: "e0e0e0"),            // Main dividers
        secondaryBorder: Color(hex: "d0d0d0"),          // Subtle borders
        
        // Accent - Same blue for consistency (user specified)
        accent: Color(hex: "2979ff"),                   // Primary blue
        accentSecondary: Color(hex: "e3f2fd"),          // Light blue background
        accentLight: Color(hex: "64b5f6"),              // Light blue for hover
        
        // Status colors - Same as dark for consistency
        error: Color(hex: "ff4b4b"),                    // Red for errors
        success: Color(hex: "27c46d"),                  // Green for success
        warning: Color(hex: "f5c14e"),                  // Yellow for warnings
        
        // Special UI states
        hover: Color(hex: "f0f0f0"),                    // Hover state
        selected: Color(hex: "e3f2fd"),                 // Selected item (light blue)
        disabled: Color(hex: "bdbdbd"),                 // Disabled state
        
        // Overlays
        overlayDark: Color.black.opacity(0.3),
        overlayLight: Color.white.opacity(0.9)
    )
}

// MARK: - Environment Key

private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func themeAware() -> some View {
        self.environmentObject(ThemeManager.shared)
    }
    
    var appTheme: ThemeColors {
        ThemeManager.shared.colors
    }
}

