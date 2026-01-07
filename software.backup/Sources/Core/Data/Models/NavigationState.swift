//
//  NavigationState.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import Foundation
import Combine
import AppKit

enum AppScreen {
    case home
    case createAnalysisWizard
    case maxView
    case tagging
    case playback
    case notes
    case playlist
    case annotation
    case moments
    case sorter
    case codeWindow
    case blueprints
    case templates
    case rosterManagement
    case liveCapture
}

@MainActor
class NavigationState: ObservableObject {
    @Published var currentScreen: AppScreen = .home
    @Published var currentProject: OpenedProject?
    @Published var selectedAngleIndex: Int = 0 // Track selected video angle across views
    @Published var refreshTrigger: UUID = UUID() // Trigger to force view refresh

    func navigate(to screen: AppScreen) async {
        // Cleanup before navigation to prevent resource leaks
        await cleanupCurrentScreen()

        currentScreen = screen
        // Post notification to pause any playing videos
        NotificationCenter.default.post(name: NSNotification.Name("ScreenDidChange"), object: nil)
    }

    private func cleanupCurrentScreen() async {
        // Pause all video players and cleanup resources
        SyncedVideoPlayerManager.shared.pause()

        // Post notification for views to cleanup keyboard monitors
        NotificationCenter.default.post(
            name: NSNotification.Name("RemoveKeyboardMonitors"),
            object: nil
        )

        print("🧹 Navigation cleanup complete for screen: \(currentScreen)")
    }

    func refresh() {
        // Update the UUID to trigger view refresh
        refreshTrigger = UUID()
        print("🔄 Refreshing current view: \(currentScreen)")
    }

    func openProject(id: String) {
        // Use ProjectManager to find the project by ID from registry
        let bundleURL = ProjectManager.shared.findProjectBundlePath(projectId: id)

        guard let url = bundleURL else {
            print("❌ Project bundle not found for ID: \(id)")
            return
        }

        print("📂 Opening project bundle: \(url.lastPathComponent)")

        let result = ProjectManager.shared.openProject(at: url)

        switch result {
        case .success(let bundle):
            // Get thumbnail from bundle
            var thumbnailImage: NSImage?
            let fileManager = FileManager.default
            if let firstThumbnail = try? fileManager.contentsOfDirectory(at: bundle.thumbnailsPath, includingPropertiesForKeys: nil).first {
                thumbnailImage = NSImage(contentsOf: firstThumbnail)
            }

            // Set current project
            currentProject = OpenedProject(
                id: bundle.projectId,
                name: bundle.name,
                sport: bundle.sport,
                season: bundle.season,
                thumbnail: thumbnailImage
            )

            // Navigate to MaxView
            Task { @MainActor in
                await navigate(to: .maxView)
            }

        case .failure(let error):
            print("❌ Failed to open project: \(error.localizedDescription)")
        }
    }
}

struct OpenedProject {
    let id: String
    let name: String
    let sport: String
    let season: String?
    let thumbnail: NSImage?

    var displayTitle: String {
        if let season = season {
            return "\(name) - \(season)"
        }
        return name
    }
}
