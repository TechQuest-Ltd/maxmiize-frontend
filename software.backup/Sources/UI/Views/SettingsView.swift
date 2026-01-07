//
//  SettingsView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 14/12/2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var shortcutsManager = KeyboardShortcutsManager.shared
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case appearance = "Appearance"
        case performance = "Performance"
        case shortcuts = "Shortcuts"

        var icon: String {
            switch self {
            case .shortcuts: return "keyboard"
            case .general: return "gearshape"
            case .appearance: return "paintpalette"
            case .performance: return "speedometer"
            }
        }
    }

    var body: some View {
        ZStack {
            themeManager.colors.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar
                HStack(spacing: 0) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(themeManager.colors.primaryText)

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.colors.tertiaryText)
                            .frame(width: 28, height: 28)
                            .background(themeManager.colors.surfaceBackground)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(themeManager.colors.secondaryBackground)

                Rectangle()
                    .fill(themeManager.colors.primaryBorder)
                    .frame(height: 1)

                HStack(spacing: 0) {
                    // Sidebar Navigation
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(spacing: 6) {
                            ForEach(SettingsTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    selectedTab = tab
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 13))
                                            .frame(width: 18)
                                            .foregroundColor(
                                                selectedTab == tab
                                                    ? themeManager.colors.accent
                                                    : themeManager.colors.tertiaryText
                                            )

                                        Text(tab.rawValue)
                                            .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                            .foregroundColor(
                                                selectedTab == tab
                                                    ? themeManager.colors.primaryText
                                                    : themeManager.colors.tertiaryText
                                            )

                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedTab == tab
                                            ? themeManager.colors.accent.opacity(0.15)
                                            : Color.clear
                                    )
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 16)

                        Spacer()
                    }
                    .frame(width: 200)
                    .background(themeManager.colors.tertiaryBackground)

                    Rectangle()
                        .fill(themeManager.colors.primaryBorder)
                        .frame(width: 1)

                    // Content Area
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .shortcuts:
                            KeyboardShortcutsSettings()
                        case .general:
                            GeneralSettings()
                        case .appearance:
                            AppearanceSettings()
                        case .performance:
                            PerformanceSettings()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.colors.secondaryBackground)
                }
            }
        }
        .frame(width: 1100, height: 650)
    }
}

// MARK: - Keyboard Shortcuts Settings

struct KeyboardShortcutsSettings: View {
    @ObservedObject var manager = KeyboardShortcutsManager.shared
    @State private var editingAction: ShortcutAction?
    @State private var editingShortcut: KeyboardShortcut?
    
    @ObservedObject private var themeManagerForTheme = ThemeManager.shared
    
    var theme: ThemeColors {
        themeManagerForTheme.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("Customize keyboard shortcuts for video analysis")
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)
                }

                Spacer()

                Button("Reset All") {
                    manager.resetToDefaults()
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.primaryBorder)
                .foregroundColor(theme.secondaryText)
                .cornerRadius(6)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Rectangle()
                .fill(theme.primaryBorder)
                .frame(height: 1)

            // Shortcuts List
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(ShortcutCategory.allCases, id: \.self) { category in
                        shortcutCategory(category)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
    }

    @ViewBuilder
    private func shortcutCategory(_ category: ShortcutCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.secondaryText)

                Spacer()

                Button("Reset Category") {
                    manager.resetCategory(category)
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
            }

            VStack(spacing: 8) {
                ForEach(ShortcutAction.allCases.filter { $0.category == category }, id: \.self) { action in
                    shortcutRow(action: action)
                }
            }
        }
    }

    @ViewBuilder
    private func shortcutRow(action: ShortcutAction) -> some View {
        HStack {
            Text(action.rawValue)
                .font(.system(size: 13))
                .foregroundColor(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let shortcut = manager.shortcut(for: action) {
                Button(action: {
                    editingAction = action
                    editingShortcut = shortcut
                }) {
                    Text(shortcut.displayString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.cardBackground)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    editingAction == action
                                        ? theme.accent
                                        : theme.secondaryBorder,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.cardBackground)
        .cornerRadius(6)
    }
}

// MARK: - General Settings

struct GeneralSettings: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var showFileImporter = false
    @ObservedObject private var themeManagerForTheme = ThemeManager.shared

    var theme: ThemeColors {
        themeManagerForTheme.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Settings List
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Auto-Save Section
                    settingsSection(title: "Auto-Save") {
                        VStack(spacing: 12) {
                            toggleRow(
                                title: "Enable Auto-Save",
                                description: "Automatically save your work at regular intervals",
                                isOn: $settings.autoSaveEnabled
                            )
                            .onChange(of: settings.autoSaveEnabled) { _, newValue in
                                settings.syncWithAutoSaveManager()
                            }

                            if settings.autoSaveEnabled {
                                sliderRow(
                                    title: "Auto-Save Interval",
                                    description: settings.autoSaveIntervalFormatted,
                                    value: $settings.autoSaveInterval,
                                    range: 10...300,
                                    step: 10
                                )
                                .onChange(of: settings.autoSaveInterval) { _, _ in
                                    settings.syncWithAutoSaveManager()
                                }
                            }
                        }
                    }

                    // Project Settings Section
                    settingsSection(title: "Project Settings") {
                        VStack(spacing: 12) {
                            toggleRow(
                                title: "Show Welcome Screen",
                                description: "Display welcome screen on app launch",
                                isOn: $settings.showWelcomeScreen
                            )

                            toggleRow(
                                title: "Confirm Before Delete",
                                description: "Ask for confirmation before deleting items",
                                isOn: $settings.confirmBeforeDelete
                            )

                            pickerRow(
                                title: "Default Export Format",
                                description: "Format used when exporting videos",
                                selection: $settings.defaultExportFormat,
                                options: ExportFormat.allCases.map { $0.rawValue }
                            )

                            pickerRow(
                                title: "Default Export Quality",
                                description: "Quality preset for video exports",
                                selection: $settings.defaultExportQuality,
                                options: ExportQuality.allCases.map { $0.rawValue }
                            )
                        }
                    }

                    // Video Settings Section
                    settingsSection(title: "Video Settings") {
                        VStack(spacing: 12) {
                            toggleRow(
                                title: "Audio Enabled",
                                description: "Enable audio playback for videos",
                                isOn: $settings.audioEnabled
                            )

                            if settings.audioEnabled {
                                sliderRow(
                                    title: "Audio Volume",
                                    description: "\(Int(settings.audioVolume * 100))%",
                                    value: $settings.audioVolume,
                                    range: 0...1,
                                    step: 0.1
                                )
                            }

                            toggleRow(
                                title: "Loop Playback",
                                description: "Automatically loop video playback",
                                isOn: $settings.loopPlayback
                            )

                            sliderRow(
                                title: "Seek Sensitivity",
                                description: String(format: "%.1fx", settings.seekSensitivity),
                                value: $settings.seekSensitivity,
                                range: 0.5...2.0,
                                step: 0.1
                            )
                        }
                    }

                    // Annotation Settings Section
                    settingsSection(title: "Annotation Settings") {
                        VStack(spacing: 12) {
                            sliderRow(
                                title: "Default Stroke Width",
                                description: "\(Int(settings.defaultStrokeWidth))pt",
                                value: $settings.defaultStrokeWidth,
                                range: 1...10,
                                step: 1
                            )

                            sliderRow(
                                title: "Annotation Opacity",
                                description: "\(Int(settings.annotationOpacity * 100))%",
                                value: $settings.annotationOpacity,
                                range: 0.1...1.0,
                                step: 0.1
                            )

                            toggleRow(
                                title: "Auto-Hide Annotations",
                                description: "Automatically hide annotations after duration",
                                isOn: $settings.autoHideAnnotations
                            )

                            if settings.autoHideAnnotations {
                                sliderRow(
                                    title: "Annotation Duration",
                                    description: "\(Int(settings.annotationDuration))s",
                                    value: $settings.annotationDuration,
                                    range: 1...10,
                                    step: 1
                                )
                            }
                        }
                    }

                    // Storage Section
                    settingsSection(title: "Storage") {
                        VStack(spacing: 12) {
                            toggleRow(
                                title: "Auto-Cleanup Old Projects",
                                description: "Automatically remove old project files",
                                isOn: $settings.autoCleanupEnabled
                            )

                            if settings.autoCleanupEnabled {
                                sliderRow(
                                    title: "Cleanup Threshold",
                                    description: "\(settings.cleanupDaysThreshold) days",
                                    value: Binding(
                                        get: { Double(settings.cleanupDaysThreshold) },
                                        set: { settings.cleanupDaysThreshold = Int($0) }
                                    ),
                                    range: 7...365,
                                    step: 7
                                )

                                toggleRow(
                                    title: "Compress Old Projects",
                                    description: "Compress projects before cleanup",
                                    isOn: $settings.compressOldProjects
                                )
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Storage Usage")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(theme.primaryText)

                                    Text(settings.calculateStorageUsage())
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.tertiaryText)
                                }

                                Spacer()

                                Button("Clear Cache") {
                                    settings.clearCache()
                                }
                                .buttonStyle(PlainButtonStyle())
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(theme.surfaceBackground)
                                .foregroundColor(theme.primaryText)
                                .cornerRadius(6)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(theme.tertiaryBackground)
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
    }
}

struct AppearanceSettings: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject private var themeManagerForTheme = ThemeManager.shared

    var theme: ThemeColors {
        themeManagerForTheme.colors
    }

    let accentColors = [
        ("Blue", "2979ff"),
        ("Purple", "9c27b0"),
        ("Green", "4caf50"),
        ("Orange", "ff9800"),
        ("Red", "f44336"),
        ("Teal", "009688")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Settings List
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Theme Section
                    settingsSection(title: "Theme") {
                        VStack(spacing: 12) {
                            pickerRow(
                                title: "Theme Mode",
                                description: "Choose application theme",
                                selection: $settings.themeMode,
                                options: ThemeMode.allCases.map { $0.rawValue }
                            )
                        }
                    }

                    // Accent Color Section
                    settingsSection(title: "Accent Color") {
                        HStack(spacing: 10) {
                            ForEach(accentColors, id: \.1) { color in
                                Button(action: {
                                    settings.accentColor = color.1
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: color.1))
                                            .frame(width: 32, height: 32)

                                        if settings.accentColor == color.1 {
                                            Circle()
                                                .stroke(theme.primaryText, lineWidth: 2.5)
                                                .frame(width: 32, height: 32)

                                            Circle()
                                                .stroke(Color(hex: color.1), lineWidth: 1)
                                                .frame(width: 40, height: 40)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(theme.tertiaryBackground)
                        .cornerRadius(6)
                    }

                    // Interface Section
                    settingsSection(title: "Interface") {
                        VStack(spacing: 12) {
                            sliderRow(
                                title: "UI Scale",
                                description: String(format: "%.0f%%", settings.uiScale * 100),
                                value: $settings.uiScale,
                                range: 0.8...1.2,
                                step: 0.1
                            )

                            sliderRow(
                                title: "Font Size Adjustment",
                                description: settings.fontSizeAdjustment == 0
                                    ? "Default"
                                    : String(format: "%+.0fpt", settings.fontSizeAdjustment),
                                value: $settings.fontSizeAdjustment,
                                range: -2...4,
                                step: 1
                            )
                        }
                    }

                    // Grid Overlay Section
                    settingsSection(title: "Grid Overlay") {
                        VStack(spacing: 12) {
                            toggleRow(
                                title: "Show Grid Overlay",
                                description: "Display grid lines on video canvas",
                                isOn: $settings.showGridOverlay
                            )

                            if settings.showGridOverlay {
                                sliderRow(
                                    title: "Grid Opacity",
                                    description: "\(Int(settings.gridOpacity * 100))%",
                                    value: $settings.gridOpacity,
                                    range: 0.1...1.0,
                                    step: 0.1
                                )
                            }
                        }
                    }

                    // Timeline Section
                    settingsSection(title: "Timeline") {
                        VStack(spacing: 12) {
                            pickerRow(
                                title: "Thumbnail Size",
                                description: "Size of timeline thumbnails",
                                selection: $settings.timelineThumbnailSize,
                                options: ThumbnailSize.allCases.map { $0.rawValue }
                            )

                            sliderRow(
                                title: "Timeline Height",
                                description: "\(Int(settings.timelineHeight))px",
                                value: $settings.timelineHeight,
                                range: 80...200,
                                step: 10
                            )

                            toggleRow(
                                title: "Show Frame Numbers",
                                description: "Display frame numbers on timeline",
                                isOn: $settings.showFrameNumbers
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
    }
}

struct PerformanceSettings: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var showClearCacheAlert = false
    @ObservedObject private var themeManagerForTheme = ThemeManager.shared

    var theme: ThemeColors {
        themeManagerForTheme.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Settings List
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Video Playback Section
                    settingsSection(title: "Video Playback") {
                        VStack(spacing: 12) {
                            pickerRow(
                                title: "Playback Quality",
                                description: "Video rendering quality",
                                selection: $settings.videoPlaybackQuality,
                                options: PlaybackQuality.allCases.map { $0.rawValue }
                            )

                            sliderRow(
                                title: "Preload Frames",
                                description: "\(settings.preloadNextFrames) frames",
                                value: Binding(
                                    get: { Double(settings.preloadNextFrames) },
                                    set: { settings.preloadNextFrames = Int($0) }
                                ),
                                range: 30...120,
                                step: 30
                            )

                            sliderRow(
                                title: "Default Frame Rate",
                                description: "\(Int(settings.defaultFrameRate)) fps",
                                value: $settings.defaultFrameRate,
                                range: 24...120,
                                step: 6
                            )
                        }
                    }

                    // Multi-Angle Section
                    settingsSection(title: "Multi-Angle Sync") {
                        VStack(spacing: 12) {
                            pickerRow(
                                title: "Sync Quality",
                                description: "Quality of multi-angle synchronization",
                                selection: $settings.multiAngleSyncQuality,
                                options: SyncQuality.allCases.map { $0.rawValue }
                            )
                        }
                    }

                    // Hardware Acceleration Section
                    settingsSection(title: "Hardware Acceleration") {
                        VStack(spacing: 12) {
                            toggleRow(
                                title: "Enable Hardware Acceleration",
                                description: "Use GPU for video decoding and rendering",
                                isOn: $settings.hardwareAcceleration
                            )

                            toggleRow(
                                title: "GPU Acceleration",
                                description: "Enable GPU-accelerated processing",
                                isOn: $settings.enableGPUAcceleration
                            )

                            toggleRow(
                                title: "Background Rendering",
                                description: "Render videos in background for faster playback",
                                isOn: $settings.backgroundRendering
                            )
                        }
                    }

                    // Memory Management Section
                    settingsSection(title: "Memory Management") {
                        VStack(spacing: 12) {
                            sliderRow(
                                title: "Cache Size",
                                description: settings.cacheSizeFormatted,
                                value: $settings.cacheSize,
                                range: 512...8192,
                                step: 512
                            )

                            sliderRow(
                                title: "Maximum RAM Usage",
                                description: settings.maxRAMUsageFormatted,
                                value: $settings.maxRAMUsage,
                                range: 1024...16384,
                                step: 1024
                            )

                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Clear Cache")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(theme.primaryText)

                                    Text("Free up disk space by clearing cached data")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.tertiaryText)
                                }

                                Spacer()

                                Button("Clear") {
                                    showClearCacheAlert = true
                                }
                                .buttonStyle(PlainButtonStyle())
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(theme.error)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(theme.tertiaryBackground)
                            .cornerRadius(6)
                        }
                    }

                    // Performance Info Section
                    settingsSection(title: "Performance Info") {
                        VStack(spacing: 12) {
                            infoRow(
                                title: "Current Memory Usage",
                                value: getCurrentMemoryUsage()
                            )

                            infoRow(
                                title: "Cache Usage",
                                value: getCacheUsage()
                            )

                            infoRow(
                                title: "GPU Status",
                                value: settings.enableGPUAcceleration ? "Enabled" : "Disabled"
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                settings.clearCache()
            }
        } message: {
            Text("This will clear all cached data. The cache will be rebuilt automatically as needed.")
        }
    }

    private func getCurrentMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1_048_576
            return String(format: "%.0f MB", usedMB)
        }
        return "Unknown"
    }

    private func getCacheUsage() -> String {
        return String(format: "%.0f MB", settings.cacheSize * 0.3)
    }
}

// MARK: - Helper View Components

@ViewBuilder
private func settingsSection<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
) -> some View {
    let theme = ThemeManager.shared
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(theme.colors.tertiaryText)
            .textCase(.uppercase)
            .tracking(0.8)

        content()
    }
}

@ViewBuilder
private func toggleRow(
    title: String,
    description: String,
    isOn: Binding<Bool>
) -> some View {
    let theme = ThemeManager.shared
    HStack {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.colors.primaryText)

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(theme.colors.tertiaryText)
        }

        Spacer()

        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(CustomToggleStyle())
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(theme.colors.tertiaryBackground)
    .cornerRadius(6)
}

@ViewBuilder
private func sliderRow(
    title: String,
    description: String,
    value: Binding<Double>,
    range: ClosedRange<Double>,
    step: Double
) -> some View {
    let theme = ThemeManager.shared
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.colors.primaryText)

            Spacer()

            Text(description)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.colors.accent)
        }

        Slider(value: value, in: range, step: step)
            .tint(theme.colors.accent)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(theme.colors.tertiaryBackground)
    .cornerRadius(6)
}

@ViewBuilder
private func pickerRow(
    title: String,
    description: String,
    selection: Binding<String>,
    options: [String]
) -> some View {
    let theme = ThemeManager.shared
    VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.colors.primaryText)

            Text(description)
                .font(.system(size: 11))
                .foregroundColor(theme.colors.tertiaryText)
        }

        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    selection.wrappedValue = option
                }) {
                    Text(option)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(
                            selection.wrappedValue == option
                                ? Color.white
                                : theme.colors.tertiaryText
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selection.wrappedValue == option
                                ? theme.colors.accent
                                : theme.colors.surfaceBackground
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(theme.colors.tertiaryBackground)
    .cornerRadius(6)
}

@ViewBuilder
private func infoRow(
    title: String,
    value: String
) -> some View {
    let theme = ThemeManager.shared
    HStack {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(theme.colors.primaryText)

        Spacer()

        Text(value)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(theme.colors.tertiaryText)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(theme.colors.tertiaryBackground)
    .cornerRadius(6)
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager.shared)
}
