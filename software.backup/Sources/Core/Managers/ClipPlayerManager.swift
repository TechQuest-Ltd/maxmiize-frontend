//
//  ClipPlayerManager.swift
//  maxmiize-v1
//
//  Centralized manager for opening and managing clip players
//

import Foundation
import SwiftUI
import AppKit

@MainActor
class ClipPlayerManager {
    static let shared = ClipPlayerManager()

    private init() {}

    /// Open a clip player window for a specific moment
    /// - Parameters:
    ///   - momentId: The ID of the moment to play
    ///   - navigationState: The navigation state environment object
    func openClipForMoment(_ momentId: String, navigationState: NavigationState) {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("❌ ClipPlayerManager: No project/game available")
            return
        }

        // Load the moment
        let moments = DatabaseManager.shared.getMoments(gameId: gameId)
        guard let moment = moments.first(where: { $0.id == momentId }) else {
            print("⚠️ ClipPlayerManager: Could not find moment with ID \(momentId)")
            return
        }

        // Find clip that matches this moment's time range
        // Note: Clips may have lead/lag time offsets, so we look for clips that overlap with and contain the moment
        let clips = DatabaseManager.shared.getClips(gameId: gameId)
        let momentStartMs = moment.startTimestampMs
        let momentEndMs = moment.endTimestampMs ?? momentStartMs

        guard let clip = clips.first(where: { clip in
            // Check if clip overlaps with moment time range AND contains the moment's start time
            let overlaps = clip.startTimeMs <= momentEndMs && clip.endTimeMs >= momentStartMs
            let containsStart = clip.startTimeMs <= momentStartMs && clip.endTimeMs >= momentStartMs
            return overlaps && containsStart
        }) else {
            print("⚠️ ClipPlayerManager: No clip found for moment: \(moment.momentCategory)")
            print("   Moment time: \(momentStartMs)ms - \(momentEndMs)ms")
            print("   Available clips: \(clips.count)")
            for clip in clips {
                print("   - \(clip.title): \(clip.startTimeMs)ms - \(clip.endTimeMs)ms")
            }
            return
        }

        // Open the clip player
        openClipPlayer(clip: clip, navigationState: navigationState)
    }

    /// Open a clip player window for a specific clip
    /// - Parameters:
    ///   - clip: The clip to play
    ///   - navigationState: The navigation state environment object
    func openClipPlayer(clip: Clip, navigationState: NavigationState) {
        let popupView = ClipPlayerPopup(clip: clip, onClose: {})
            .environmentObject(navigationState)
            .environmentObject(ThemeManager.shared)

        let hostingController = NSHostingController(rootView: popupView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Clip Player - \(clip.title)"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false

        print("▶️ ClipPlayerManager: Opened clip player for \(clip.title)")
    }
}
