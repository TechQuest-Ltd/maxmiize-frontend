//
//  MultiAngleViewerGrid.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI
import AVFoundation

struct MultiAngleViewerGrid: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject var playerManager: SyncedVideoPlayerManager
    @ObservedObject var annotationManager = AnnotationManager.shared
    @State private var videos: [DatabaseManager.VideoInfo] = []

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        GeometryReader { geometry in
            if videos.isEmpty {
                // No videos loaded
                emptyStateView
            } else {
                // Single angle view with angle selector
                singleAngleWithSelectorLayout(geometry: geometry)
            }
        }
        .background(theme.primaryBackground)
        .onAppear {
            loadVideos()
            startTimeTracking()
        }
    }

    // MARK: - Time Tracking

    private func startTimeTracking() {
        // Track previous annotation count for freeze detection
        var previousVisibleCount = 0

        // Update annotation manager's current time every 100ms
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let currentSeconds = playerManager.currentTime.seconds
            let currentTimeMs = Int64(currentSeconds * 1000)
            annotationManager.currentTimeMs = currentTimeMs

            // Check for new annotations appearing (for freeze duration)
            if annotationManager.freezeDuration > 0 {
                // Count currently visible annotations across all angles
                let nowVisibleCount = annotationManager.annotations.filter { annotation in
                    annotation.isVisible(at: currentTimeMs)
                }.count

                // If new annotations just appeared, freeze playback
                if nowVisibleCount > previousVisibleCount && playerManager.isPlaying {
                    print("❄️ New annotation appeared! Freezing for \(annotationManager.freezeDuration)s")
                    playerManager.freezeFor(duration: annotationManager.freezeDuration)
                }

                previousVisibleCount = nowVisibleCount
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(theme.quaternaryText)

            Text("No videos imported")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.tertiaryText)

            Text("Import videos from the top menu")
                .font(.system(size: 13))
                .foregroundColor(theme.quaternaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Layout Functions

    private func singleAngleWithSelectorLayout(geometry: GeometryProxy) -> some View {
        // Video player with annotations (angle selector moved to header)
        let currentIndex = min(playerManager.activePlayerIndex, videos.count - 1)
        return AngleCell(
            video: videos[currentIndex],
            player: playerManager.getPlayer(at: currentIndex) ?? AVPlayer(),
            angleId: "angle_\(currentIndex)",
            width: geometry.size.width,
            height: geometry.size.height
        )
    }

    // MARK: - Load Videos

    private func loadVideos() {
        guard let project = navigationState.currentProject,
              let bundle = ProjectManager.shared.currentProject else {
            return
        }

        let loadedVideos = DatabaseManager.shared.getVideos(projectId: project.id)

        // Load all available videos (no limit for single-angle view)
        videos = loadedVideos

        // Construct video URLs
        let videoURLs = videos.map { videoInfo -> URL in
            bundle.bundlePath.appendingPathComponent(videoInfo.filePath)
        }

        // Setup synchronized players
        if !videoURLs.isEmpty {
            Task { @MainActor in
                await playerManager.setupPlayers(videoURLs: videoURLs)
                // Enable single-angle mode for annotation view (only one video plays at a time)
                playerManager.setSingleAngleMode(true)
                print("🎬 MultiAngleViewerGrid: Enabled single-angle mode for annotations")
            }
        }
    }
}

// MARK: - Angle Cell

struct AngleCell: View {
    @EnvironmentObject var themeManager: ThemeManager
    let video: DatabaseManager.VideoInfo
    let player: AVPlayer
    let angleId: String
    let width: CGFloat
    let height: CGFloat
    @ObservedObject var annotationManager = AnnotationManager.shared

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Video player
            VideoPlayerView(player: player, videoGravity: .resizeAspect)
                .frame(width: width, height: height)

            // Annotation canvas overlay (per-angle annotations!)
            AnnotationCanvas(annotationManager: annotationManager, angleId: angleId)
                .frame(width: width, height: height)

            // Angle label (top-left)
            Text(video.cameraAngle.capitalized)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.overlayDark)
                .cornerRadius(6)
                .padding(12)

            // Video info overlay (bottom-right)
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(video.width))x\(Int(video.height))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.tertiaryText)

                        Text("\(String(format: "%.1f", video.frameRate)) fps")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(theme.overlayDark)
                    .cornerRadius(4)
                    .padding(10)
                }
            }
        }
    }
}

// MARK: - Preview

struct MultiAngleViewerGrid_Previews: PreviewProvider {
    static var previews: some View {
        MultiAngleViewerGrid(playerManager: SyncedVideoPlayerManager.shared)
            .environmentObject(NavigationState())
            .frame(height: 600)
    }
}
