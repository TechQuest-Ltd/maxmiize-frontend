//
//  SettingsManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 23/12/2025.
//

import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - General Settings

    @AppStorage("autoSaveEnabled") var autoSaveEnabled: Bool = true
    @AppStorage("autoSaveInterval") var autoSaveInterval: Double = 30.0
    @AppStorage("defaultProjectLocation") var defaultProjectLocation: String = ""
    @AppStorage("showWelcomeScreen") var showWelcomeScreen: Bool = true
    @AppStorage("confirmBeforeDelete") var confirmBeforeDelete: Bool = true
    @AppStorage("defaultExportFormat") var defaultExportFormat: String = "mp4"
    @AppStorage("defaultExportQuality") var defaultExportQuality: String = "high"

    // MARK: - Appearance Settings

    @AppStorage("themeMode") var themeMode: String = "dark"
    @AppStorage("accentColor") var accentColor: String = "2979ff"
    @AppStorage("uiScale") var uiScale: Double = 1.0
    @AppStorage("showGridOverlay") var showGridOverlay: Bool = false
    @AppStorage("gridOpacity") var gridOpacity: Double = 0.3
    @AppStorage("timelineThumbnailSize") var timelineThumbnailSize: String = "medium"
    @AppStorage("fontSizeAdjustment") var fontSizeAdjustment: Double = 0.0
    @AppStorage("showFrameNumbers") var showFrameNumbers: Bool = false
    @AppStorage("timelineHeight") var timelineHeight: Double = 120.0

    // MARK: - Performance Settings

    @AppStorage("videoPlaybackQuality") var videoPlaybackQuality: String = "high"
    @AppStorage("cacheSize") var cacheSize: Double = 2048.0 // MB
    @AppStorage("maxRAMUsage") var maxRAMUsage: Double = 4096.0 // MB
    @AppStorage("hardwareAcceleration") var hardwareAcceleration: Bool = true
    @AppStorage("backgroundRendering") var backgroundRendering: Bool = true
    @AppStorage("preloadNextFrames") var preloadNextFrames: Int = 60
    @AppStorage("multiAngleSyncQuality") var multiAngleSyncQuality: String = "high"
    @AppStorage("enableGPUAcceleration") var enableGPUAcceleration: Bool = true

    // MARK: - Video Settings

    @AppStorage("defaultFrameRate") var defaultFrameRate: Double = 60.0
    @AppStorage("seekSensitivity") var seekSensitivity: Double = 1.0
    @AppStorage("playbackSpeed") var playbackSpeed: Double = 1.0
    @AppStorage("loopPlayback") var loopPlayback: Bool = false
    @AppStorage("audioEnabled") var audioEnabled: Bool = true
    @AppStorage("audioVolume") var audioVolume: Double = 0.7

    // MARK: - Annotation Settings

    @AppStorage("defaultAnnotationColor") var defaultAnnotationColor: String = "ff0000"
    @AppStorage("defaultStrokeWidth") var defaultStrokeWidth: Double = 3.0
    @AppStorage("annotationOpacity") var annotationOpacity: Double = 1.0
    @AppStorage("autoHideAnnotations") var autoHideAnnotations: Bool = false
    @AppStorage("annotationDuration") var annotationDuration: Double = 3.0 // seconds

    // MARK: - Storage Settings

    @AppStorage("storageLocation") var storageLocation: String = ""
    @AppStorage("autoCleanupEnabled") var autoCleanupEnabled: Bool = false
    @AppStorage("cleanupDaysThreshold") var cleanupDaysThreshold: Int = 30
    @AppStorage("compressOldProjects") var compressOldProjects: Bool = false

    private init() {
        // Set default storage location if not set
        if storageLocation.isEmpty {
            storageLocation = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        }

        if defaultProjectLocation.isEmpty {
            defaultProjectLocation = storageLocation
        }

        // Sync with AutoSaveManager
        syncWithAutoSaveManager()
    }

    // MARK: - Computed Properties

    var autoSaveIntervalFormatted: String {
        if autoSaveInterval < 60 {
            return "\(Int(autoSaveInterval)) seconds"
        } else {
            let minutes = Int(autoSaveInterval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    var cacheSizeFormatted: String {
        if cacheSize < 1024 {
            return "\(Int(cacheSize)) MB"
        } else {
            let gb = cacheSize / 1024
            return String(format: "%.1f GB", gb)
        }
    }

    var maxRAMUsageFormatted: String {
        if maxRAMUsage < 1024 {
            return "\(Int(maxRAMUsage)) MB"
        } else {
            let gb = maxRAMUsage / 1024
            return String(format: "%.1f GB", gb)
        }
    }

    // MARK: - Methods

    func resetToDefaults() {
        autoSaveEnabled = true
        autoSaveInterval = 30.0
        showWelcomeScreen = true
        confirmBeforeDelete = true
        defaultExportFormat = "mp4"
        defaultExportQuality = "high"

        themeMode = "dark"
        accentColor = "2979ff"
        uiScale = 1.0
        showGridOverlay = false
        gridOpacity = 0.3
        timelineThumbnailSize = "medium"
        fontSizeAdjustment = 0.0
        showFrameNumbers = false
        timelineHeight = 120.0

        videoPlaybackQuality = "high"
        cacheSize = 2048.0
        maxRAMUsage = 4096.0
        hardwareAcceleration = true
        backgroundRendering = true
        preloadNextFrames = 60
        multiAngleSyncQuality = "high"
        enableGPUAcceleration = true

        defaultFrameRate = 60.0
        seekSensitivity = 1.0
        playbackSpeed = 1.0
        loopPlayback = false
        audioEnabled = true
        audioVolume = 0.7

        defaultAnnotationColor = "ff0000"
        defaultStrokeWidth = 3.0
        annotationOpacity = 1.0
        autoHideAnnotations = false
        annotationDuration = 3.0

        autoCleanupEnabled = false
        cleanupDaysThreshold = 30
        compressOldProjects = false

        syncWithAutoSaveManager()
    }

    func syncWithAutoSaveManager() {
        Task { @MainActor in
            AutoSaveManager.shared.setAutoSaveEnabled(autoSaveEnabled)
            AutoSaveManager.shared.setAutoSaveInterval(autoSaveInterval)
        }
    }

    func clearCache() {
        // Implementation for clearing cache
        print("🗑️ Clearing cache...")
        // TODO: Implement actual cache clearing logic
    }

    func calculateStorageUsage() -> String {
        guard let url = URL(string: storageLocation) else {
            return "Unknown"
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let capacity = resourceValues.volumeAvailableCapacity {
                let gb = Double(capacity) / 1_073_741_824 // Convert bytes to GB
                return String(format: "%.1f GB available", gb)
            }
        } catch {
            print("❌ Error calculating storage: \(error)")
        }

        return "Unknown"
    }
}

// MARK: - Enums

enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"
    
    var id: String { self.rawValue }
    
    var systemValue: String {
        switch self {
        case .light: return "light"
        case .dark: return "dark"
        case .auto: return "auto"
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case mp4 = "MP4"
    case mov = "MOV"
    case avi = "AVI"
}

enum ExportQuality: String, CaseIterable {
    case low = "Low (720p)"
    case medium = "Medium (1080p)"
    case high = "High (1440p)"
    case ultra = "Ultra (4K)"
}

enum PlaybackQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case ultra = "Ultra"
}

enum ThumbnailSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
}

enum SyncQuality: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}
