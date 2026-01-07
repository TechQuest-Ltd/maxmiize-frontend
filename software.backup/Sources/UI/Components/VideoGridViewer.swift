//
//  VideoGridViewer.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import SwiftUI
import AVFoundation
import AppKit

enum GridLayout: Int, CaseIterable {
    case single = 1
    case dual = 2
    case quad = 4
}

struct VideoAngle: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let timecode: String
    let additionalInfo: String
    let imageName: String?
    let isActive: Bool
    let videoURL: URL?
}

struct VideoGridViewer: View {
    @EnvironmentObject var navigationState: NavigationState
    @State private var selectedLayout: GridLayout = .quad
    @State private var annotationsVisible: Bool = true
    @State private var videoAngles: [VideoAngle] = []
    @ObservedObject private var playerManager = SyncedVideoPlayerManager.shared
    @ObservedObject private var focusManager = VideoPlayerFocusManager.shared
    @ObservedObject private var annotationManager = AnnotationManager.shared
    @State private var selectedVideoIndex: Int? = nil
    @State private var focusedAngleIndex: Int = 0 // Track which angle is focused in grid
    @State private var clipMarker = ClipMarker()
    @State private var showingClipModal = false
    @State private var clipTitle: String = ""
    @State private var clipNotes: String = ""
    @State private var isAnnotationMode: Bool = false // Track annotation mode
    @State private var isFullscreenMode: Bool = false // Track manual fullscreen
    @State private var fullscreenVideoIndex: Int = 0 // Which video to show fullscreen
    @ObservedObject private var shortcutsManager = KeyboardShortcutsManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @FocusState private var isFocused: Bool

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                viewerHeader
                    .padding(.horizontal, 11)
                    .padding(.top, 13)
                    .padding(.bottom, 8)

                // Video Grid
                videoGrid
                    .padding(.horizontal, 11)
                    .padding(.bottom, 8)

                // Playback Controls
                PlaybackControls(
                    playerManager: playerManager,
                    showTimeline: true,
                    inPoint: clipMarker.inPoint,
                    outPoint: clipMarker.outPoint
                )
                .padding(.horizontal, 11)
                .padding(.bottom, 13)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.primaryBorder.opacity(0.3), lineWidth: 0.5)
            )
            .onAppear {
                loadVideos()
                // Switch to multi-angle mode for MaxView (all videos play)
                playerManager.setSingleAngleMode(false)
                print("🎬 VideoGridViewer: Switched to multi-angle mode")

                // Setup keyboard handling for spacebar
                setupKeyboardHandling()
                // Request focus so keyboard events work immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }

                // Load annotations for current project
                if let project = navigationState.currentProject {
                    annotationManager.setCurrentProject(project.id)
                    annotationManager.loadAnnotations(projectId: project.id)
                    print("🎨 VideoGridViewer: Loaded annotations for project: \(project.name)")
                }

                // Start continuous time tracking for annotation visibility
                startContinuousTimeTracking()
            }
            .focusable()
            .focused($isFocused)
            .onKeyPress { keyPress in
                return handleKeyPress(keyPress)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JumpToClip"))) { notification in
                if let userInfo = notification.userInfo,
                   let startTimeMs = userInfo["startTimeMs"] as? Int64 {
                    let time = CMTime(value: startTimeMs, timescale: 1000)
                    playerManager.seek(to: time)
                    print("🎬 Jumped to clip at \(formatTime(time))")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JumpToTag"))) { notification in
                if let timestampMs = notification.userInfo?["timestampMs"] as? Int64 {
                    let seconds = Double(timestampMs) / 1000.0
                    let time = CMTime(seconds: seconds, preferredTimescale: 600)
                    playerManager.seek(to: time)
                    print("🎬 VideoGridViewer: Jumped to tag at \(seconds)s")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EnterAnnotationMode"))) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAnnotationMode = true

                    // Set project ID and load annotations for annotation manager
                    if let project = navigationState.currentProject {
                        annotationManager.setCurrentProject(project.id)
                        annotationManager.loadAnnotations(projectId: project.id)
                        print("🎨 VideoGridViewer: Entered annotation mode for project: \(project.name)")

                        // Start time tracking for freeze mechanism
                        startAnnotationTimeTracking()
                    } else {
                        print("⚠️ VideoGridViewer: No project found when entering annotation mode")
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExitAnnotationMode"))) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAnnotationMode = false
                    print("🎨 VideoGridViewer: Exited annotation mode")
                }
            }

            // Video Modal Overlay
            if let selectedIndex = selectedVideoIndex {
                videoModal(for: selectedIndex)
            }

            // Clip Creation Modal
            if showingClipModal {
                clipCreationModal
            }
        }
    }

    // MARK: - Load Videos
    private func loadVideos() {
        guard let project = navigationState.currentProject,
              let bundle = ProjectManager.shared.currentProject else {
            print("⚠️ VideoGridViewer: No project open - showing empty grid")
            videoAngles = []
            return
        }

        print("📹 VideoGridViewer: Loading videos for project: \(project.name) (ID: \(project.id))")

        // Get videos from database
        let videos = DatabaseManager.shared.getVideos(projectId: project.id)

        print("📹 VideoGridViewer: Database returned \(videos.count) videos")
        for (index, video) in videos.enumerated() {
            print("   Video \(index + 1): \(video.filePath) - \(video.cameraAngle)")
        }

        // Convert to VideoAngle objects with full video URLs
        videoAngles = videos.enumerated().map { index, video in
            // Construct full URL from bundle path + relative file path
            let videoURL = bundle.bundlePath.appendingPathComponent(video.filePath)

            print("   Video URL: \(videoURL.path)")

            return VideoAngle(
                name: "Video \(index + 1)",
                description: video.cameraAngle,
                timecode: formatDuration(video.durationMs),
                additionalInfo: index == 0 ? "Linked · 1.00x" : "",
                imageName: nil,
                isActive: index == 0,
                videoURL: videoURL
            )
        }

        // Setup synchronized players with video URLs
        let videoURLs = videoAngles.compactMap { $0.videoURL }
        if !videoURLs.isEmpty {
            Task { @MainActor in
                await playerManager.setupPlayers(videoURLs: videoURLs)
            }
        }

        print("✅ VideoGridViewer: Loaded \(videoAngles.count) videos successfully")
    }

    // MARK: - Annotation Time Tracking

    /// Continuous time tracking - updates annotation manager's current time for annotation visibility
    private func startContinuousTimeTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let currentSeconds = playerManager.currentTime.seconds
            let currentTimeMs = Int64(currentSeconds * 1000)
            annotationManager.currentTimeMs = currentTimeMs
        }
    }

    /// Freeze detection - only runs in annotation mode
    private func startAnnotationTimeTracking() {
        // Track previous annotation count for freeze detection
        var previousVisibleCount = 0

        // Update annotation manager's current time every 100ms
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            // Stop timer when exiting annotation mode
            guard isAnnotationMode else {
                timer.invalidate()
                return
            }

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

    private func formatDuration(_ durationMs: Int64) -> String {
        let totalSeconds = Int(durationMs / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let frames = Int((durationMs % 1000) * 30 / 1000) // Assuming 30fps

        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    // MARK: - Header
    private var viewerHeader: some View {
        HStack {
            // Left: Mode indicator
            HStack(spacing: 8) {
                Text("Viewer • Quad Grid")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Text("Active: Tactical High Angle")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accent)
            }

            Spacer()

            // Right: Controls
            HStack(spacing: 6) {
                // Fullscreen button
                Button(action: { print("Fullscreen") }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12))
                            .foregroundColor(theme.secondaryText)

                        Text("Fullscreen")
                            .font(.system(size: 11))
                            .foregroundColor(theme.secondaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.cardBackground)
                    .cornerRadius(999)
                }
                .buttonStyle(PlainButtonStyle())

                // Grid layout selector
                HStack(spacing: 4) {
                    ForEach([GridLayout.single, .dual, .quad], id: \.self) { layout in
                        Button(action: {
                            selectedLayout = layout
                        }) {
                            Text("\(layout.rawValue)")
                                .font(.system(size: 11))
                                .foregroundColor(selectedLayout == layout ? Color.white : theme.tertiaryText)
                                .frame(width: 24, height: 20)
                                .background(selectedLayout == layout ? theme.accent : Color.clear)
                                .cornerRadius(999)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(3)
                .background(theme.cardBackground)
                .cornerRadius(999)

                // Annotations toggle
                Button(action: {
                    annotationsVisible.toggle()
                }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(annotationsVisible ? theme.accent : theme.tertiaryText)
                            .frame(width: 6, height: 6)

                        Text("Annotations Visible")
                            .font(.system(size: 11))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.cardBackground)
                    .cornerRadius(999)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    // MARK: - Video Grid
    private var videoGrid: some View {
        GeometryReader { geometry in
            ZStack {
                theme.primaryBackground
                    .cornerRadius(12)

                if isAnnotationMode {
                    // Single fullscreen video for annotation
                    singleVideoWithAnnotation(geometry: geometry)
                } else if isFullscreenMode {
                    // Single fullscreen video (manual)
                    singleVideoFullscreen(geometry: geometry, videoIndex: fullscreenVideoIndex)
                } else {
                    // 2x2 Grid (optimized spacing)
                    quadVideoGrid(geometry: geometry)
                }
            }
        }
    }

    // MARK: - Single Video with Annotation Overlay
    private func singleVideoWithAnnotation(geometry: GeometryProxy) -> some View {
        ZStack {
            // Fullscreen video
            VideoPanel(
                angle: safeVideoAngle(at: playerManager.activePlayerIndex),
                isActive: true,
                player: playerManager.getPlayer(at: playerManager.activePlayerIndex),
                onClick: {}
            )
            .frame(width: geometry.size.width, height: geometry.size.height)

            // Annotation canvas overlay (directly on the video) - always visible and interactive in annotation mode
            AnnotationCanvas(
                annotationManager: annotationManager,
                angleId: "angle_\(playerManager.activePlayerIndex)"
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
            .allowsHitTesting(annotationManager.currentTool != .select) // Allow drawing when tool is selected

            // Exit button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        // Exit annotation mode
                        annotationManager.currentTool = .select
                        NotificationCenter.default.post(name: NSNotification.Name("ExitAnnotationMode"), object: nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 32, height: 32))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(16)
                }
                Spacer()
            }
        }
    }

    // MARK: - Single Video Fullscreen (Manual)
    private func singleVideoFullscreen(geometry: GeometryProxy, videoIndex: Int) -> some View {
        ZStack {
            // Fullscreen video
            VideoPanel(
                angle: safeVideoAngle(at: videoIndex),
                isActive: true,
                player: playerManager.getPlayer(at: videoIndex),
                onClick: {}
            )
            .frame(width: geometry.size.width, height: geometry.size.height)

            // Annotation canvas overlay (view-only in fullscreen mode)
            if annotationsVisible {
                AnnotationCanvas(
                    annotationManager: annotationManager,
                    angleId: "angle_\(videoIndex)"
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .allowsHitTesting(false) // View-only, no interaction in fullscreen mode
            }

            // Exit button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isFullscreenMode = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                            .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 32, height: 32))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(16)
                }
                Spacer()
            }
        }
    }

    // MARK: - Quad Grid (Optimized)
    private func quadVideoGrid(geometry: GeometryProxy) -> some View {
        let spacing: CGFloat = 4 // Reduced spacing
        let totalWidth = geometry.size.width - (spacing * 3)
        let totalHeight = geometry.size.height - (spacing * 3)
        let cellWidth = totalWidth / 2
        let cellHeight = totalHeight / 2

        return VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                // Top-left
                quadVideoCell(index: 0, width: cellWidth, height: cellHeight)

                // Top-right
                quadVideoCell(index: 1, width: cellWidth, height: cellHeight)
            }

            HStack(spacing: spacing) {
                // Bottom-left
                quadVideoCell(index: 2, width: cellWidth, height: cellHeight)

                // Bottom-right
                quadVideoCell(index: 3, width: cellWidth, height: cellHeight)
            }
        }
        .padding(spacing)
    }

    // MARK: - Quad Video Cell with Annotation Overlay
    private func quadVideoCell(index: Int, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            VideoPanel(
                angle: safeVideoAngle(at: index),
                isActive: focusedAngleIndex == index,
                player: playerManager.getPlayer(at: index),
                onClick: {
                    focusedAngleIndex = index
                    navigationState.selectedAngleIndex = index
                    playerManager.switchToAngle(index)
                    // Enable fullscreen
                    withAnimation(.easeInOut(duration: 0.3)) {
                        fullscreenVideoIndex = index
                        isFullscreenMode = true
                    }
                }
            )
            .frame(width: width, height: height)

            // Annotation overlay (view-only in quad grid)
            if annotationsVisible {
                AnnotationCanvas(
                    annotationManager: annotationManager,
                    angleId: "angle_\(index)"
                )
                .frame(width: width, height: height)
                .allowsHitTesting(false) // View-only, no interaction in quad grid
            }
        }
    }


    // MARK: - Helper Functions

    private func formatTime(_ time: CMTime) -> String {
        let totalSeconds = Int(time.seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Video Modal
    @ViewBuilder
    private func videoModal(for index: Int) -> some View {
        ZStack {
            // Backdrop - click to close
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    selectedVideoIndex = nil
                }

            // Modal container
            VStack(spacing: 0) {
                // Modal Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(safeVideoAngle(at: index).name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Text(safeVideoAngle(at: index).description)
                            .font(.system(size: 13))
                            .foregroundColor(theme.tertiaryText)
                    }

                    Spacer()

                    // Close button
                    Button(action: {
                        selectedVideoIndex = nil
                    }) {
                        ZStack {
                            Circle()
                                .fill(theme.cardBackground)
                                .frame(width: 32, height: 32)

                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(20)
                .background(theme.secondaryBackground)

                // Video player
                if let player = playerManager.getPlayer(at: index) {
                    VideoPlayerView(player: player, videoGravity: .resizeAspect)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.primaryBackground)
                } else {
                    theme.surfaceBackground
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Playback controls
                PlaybackControls(playerManager: playerManager, showTimeline: true)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(theme.secondaryBackground)
            }
            .frame(maxWidth: 1200, maxHeight: 700)
            .background(theme.secondaryBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.primaryBorder, lineWidth: 1)
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedVideoIndex)
    }

    // MARK: - Helper Methods

    /// Safely gets a video angle at the specified index, or returns a placeholder if not available
    private func safeVideoAngle(at index: Int) -> VideoAngle {
        guard index < videoAngles.count else {
            return VideoAngle(
                name: "Empty Slot",
                description: "No video",
                timecode: "00:00:00:00",
                additionalInfo: "",
                imageName: nil,
                isActive: false,
                videoURL: nil
            )
        }
        return videoAngles[index]
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardHandling() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Spacebar is keyCode 49
            if event.keyCode == 49 && !event.modifierFlags.contains(.command) {
                // Check if we're in a text field
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder {
                    if firstResponder is NSTextView ||
                       firstResponder is NSTextField ||
                       String(describing: type(of: firstResponder)).contains("TextField") {
                        return event
                    }
                }

                // IMPORTANT: Only handle spacebar if we're on MaxView screen AND have main player focus
                guard self.navigationState.currentScreen == .maxView else {
                    print("⚠️ [VideoGridViewer] Not on MaxView screen - passing spacebar through")
                    return event
                }

                guard self.focusManager.shouldHandle(.mainPlayer) else {
                    print("⚠️ [VideoGridViewer] Another player has focus - passing spacebar through")
                    return event
                }

                // Toggle play/pause
                self.playerManager.togglePlayPause()
                print("⏯️ [VideoGridViewer] Handled spacebar - toggling playback")
                return nil
            }
            return event
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        let key = keyPress.characters.uppercased()
        let modifiers = getModifiers(from: keyPress)

        // Handle spacebar for play/pause
        if keyPress.key == .space && modifiers.isEmpty {
            playerManager.togglePlayPause()
            print("⏯️ Spacebar: Toggled play/pause")
            return .handled
        }

        // Check against configured shortcuts
        for (action, shortcut) in shortcutsManager.shortcuts {
            if shortcut.key == key && shortcut.modifiers == modifiers {
                handleShortcutAction(action)
                return .handled
            }
        }

        return .ignored
    }

    private func getModifiers(from keyPress: KeyPress) -> Set<ShortcutModifier> {
        var modifiers: Set<ShortcutModifier> = []
        if keyPress.modifiers.contains(.command) { modifiers.insert(.command) }
        if keyPress.modifiers.contains(.shift) { modifiers.insert(.shift) }
        if keyPress.modifiers.contains(.option) { modifiers.insert(.option) }
        if keyPress.modifiers.contains(.control) { modifiers.insert(.control) }
        return modifiers
    }

    private func handleShortcutAction(_ action: ShortcutAction) {
        print("🎯 Shortcut triggered: \(action.rawValue)")

        switch action {
        // Playback
        case .playPause:
            playerManager.togglePlayPause()

        case .skipForward:
            let currentTime = playerManager.currentTime
            let newTime = CMTimeAdd(currentTime, CMTime(seconds: 5, preferredTimescale: 600))
            playerManager.seek(to: newTime)

        case .skipBackward:
            let currentTime = playerManager.currentTime
            let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 5, preferredTimescale: 600))
            playerManager.seek(to: max(newTime, .zero))

        case .speedUp:
            let newRate = min(playerManager.playbackRate + 0.25, 2.0)
            playerManager.setRate(newRate)

        case .speedDown:
            let newRate = max(playerManager.playbackRate - 0.25, 0.25)
            playerManager.setRate(newRate)

        // Clip Marking
        case .markIn:
            clipMarker.inPoint = playerManager.currentTime
            print("📍 Marked IN point: \(formatTime(playerManager.currentTime))")

        case .markOut:
            clipMarker.outPoint = playerManager.currentTime
            print("📍 Marked OUT point: \(formatTime(playerManager.currentTime))")

        case .createClip:
            if clipMarker.hasBothPoints {
                showingClipModal = true
            } else {
                print("⚠️ Need both In and Out points to create a clip")
            }

        case .clearMarks:
            clipMarker.clear()
            print("🗑️ Cleared In/Out markers")

        default:
            print("⚠️ Action not yet implemented: \(action.rawValue)")
        }
    }

    // MARK: - Clip Creation Modal

    @ViewBuilder
    private var clipCreationModal: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    showingClipModal = false
                }

            // Modal
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Clip")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("Mark a moment from your game footage")
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)

                Divider()
                    .background(theme.primaryBorder)

                // Content
                VStack(spacing: 20) {
                    if let inPoint = clipMarker.inPoint, let outPoint = clipMarker.outPoint {
                        // Duration Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Duration")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(theme.tertiaryText)
                                    .textCase(.uppercase)

                                Text(formatDuration(from: inPoint, to: outPoint))
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(theme.primaryText)
                                    .monospacedDigit()
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(theme.cardBackground)
                        .cornerRadius(8)

                        // Time Range
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("IN POINT")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(theme.accent)
                                    .textCase(.uppercase)

                                Text(formatTime(inPoint))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.secondaryText)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(theme.cardBackground)
                            .cornerRadius(6)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 14))
                                .foregroundColor(theme.tertiaryText)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("OUT POINT")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(theme.error)
                                    .textCase(.uppercase)

                                Text(formatTime(outPoint))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(theme.secondaryText)
                                    .monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(theme.cardBackground)
                            .cornerRadius(6)
                        }

                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.tertiaryText)
                                .textCase(.uppercase)

                            TextField("", text: $clipTitle, prompt: Text("Enter clip title (e.g., Pick and Roll Defense)")
                                .foregroundColor(theme.tertiaryText))
                                .font(.system(size: 13))
                                .foregroundColor(theme.primaryText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(12)
                                .background(theme.cardBackground)
                                .cornerRadius(6)
                        }

                        // Notes Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes (Optional)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.tertiaryText)
                                .textCase(.uppercase)

                            ZStack(alignment: .topLeading) {
                                if clipNotes.isEmpty {
                                    Text("Add notes, observations, or coaching points...")
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.tertiaryText)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                }

                                TextEditor(text: $clipNotes)
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.primaryText)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .frame(height: 80)
                                    .padding(6)
                            }
                            .background(theme.cardBackground)
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(24)

                Divider()
                    .background(theme.primaryBorder)

                // Footer Actions
                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingClipModal = false
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.primaryBorder)
                    .foregroundColor(theme.secondaryText)
                    .cornerRadius(8)

                    Button("Create Clip") {
                        createClipFromMarkers()
                        showingClipModal = false
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.accent)
                    .foregroundColor(Color.white)
                    .cornerRadius(8)
                }
                .padding(24)
            }
            .background(theme.secondaryBackground)
            .cornerRadius(16)
            .frame(width: 560)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.primaryBorder, lineWidth: 1)
            )
        }
    }

    private func createClipFromMarkers() {
        guard let inPoint = clipMarker.inPoint,
              let outPoint = clipMarker.outPoint,
              let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("❌ Cannot create clip: missing data")
            return
        }

        let startMs = Int64(inPoint.seconds * 1000)
        let endMs = Int64(outPoint.seconds * 1000)

        // Use custom title if provided, otherwise generate one
        let finalTitle = clipTitle.isEmpty ? "Clip at \(formatTime(inPoint))" : clipTitle

        let result = DatabaseManager.shared.createClip(
            gameId: gameId,
            startTimeMs: startMs,
            endTimeMs: endMs,
            title: finalTitle,
            notes: clipNotes,
            tags: []
        )

        switch result {
        case .success(let clip):
            print("✅ Created clip: \(clip.title)")
            clipMarker.clear()
            // Clear input fields
            clipTitle = ""
            clipNotes = ""
            // Notify clips panel to refresh
            NotificationCenter.default.post(name: NSNotification.Name("ClipCreated"), object: nil)
        case .failure(let error):
            print("❌ Failed to create clip: \(error.localizedDescription)")
        }
    }

    private func formatDuration(from start: CMTime, to end: CMTime) -> String {
        let duration = CMTimeSubtract(end, start).seconds
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video Panel
struct VideoPanel: View {
    @EnvironmentObject var themeManager: ThemeManager

    let angle: VideoAngle
    let isActive: Bool
    let player: AVPlayer?
    let onClick: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            // Video player or placeholder
            if let player = player {
                VideoPlayerView(player: player, videoGravity: .resizeAspect)
            } else {
                theme.surfaceBackground
            }

            // Overlays
            VStack {
                HStack {
                    // Top-left: Angle name
                    Text("\(angle.name) · \(angle.description)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.secondaryText.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.primaryBackground.opacity(0.8))
                        .cornerRadius(999)
                        .padding(8)

                    Spacer()
                }

                Spacer()

                HStack {
                    Spacer()

                    // Bottom-right: Timecode
                    Text(angle.additionalInfo.isEmpty ? angle.timecode : "\(angle.timecode) · \(angle.additionalInfo)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.primaryBackground.opacity(0.82))
                        .cornerRadius(999)
                        .padding(8)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onClick()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? theme.accent : theme.surfaceBackground, lineWidth: 1)
        )
        .cornerRadius(10)
        .overlay(
            isActive ?
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.accent.opacity(0.55), lineWidth: 1)
                .padding(-1)
            : nil
        )
    }
}

#Preview {
    VideoGridViewer()
        .frame(width: 820, height: 393)
        .background(Color.black)
}
