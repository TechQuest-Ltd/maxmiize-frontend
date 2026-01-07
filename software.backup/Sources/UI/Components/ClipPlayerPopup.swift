//
//  ClipPlayerPopup.swift
//  maxmiize-v1
//
//  Reusable clip player popup component
//

import SwiftUI
import AVFoundation

struct ClipPlayerPopup: View {
    @EnvironmentObject var themeManager: ThemeManager
    let clip: Clip
    let onClose: () -> Void
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var toastManager = ToastManager()
    @ObservedObject private var focusManager = VideoPlayerFocusManager.shared
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: CMTime = .zero
    @State private var duration: CMTime = .zero
    @State private var timeObserver: Any?
    @State private var currentClip: Clip  // Track modified clip
    @State private var keyboardMonitor: Any?  // Store keyboard event monitor to remove it later

    init(clip: Clip, onClose: @escaping () -> Void) {
        self.clip = clip
        self.onClose = onClose
        _currentClip = State(initialValue: clip)
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(clip.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()
            }
            .padding(16)
            .background(theme.surfaceBackground)

            Divider().background(theme.primaryBorder)

            // Video Player
            ZStack {
                if let player = player {
                    VideoPlayerView(player: player, videoGravity: .resizeAspect)
                } else {
                    Color.black
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Loading clip...")
                            .font(.system(size: 14))
                            .foregroundColor(theme.primaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                // Set keyboard focus to this popup
                focusManager.setFocus(.clipPopup)

                // Pause background video player
                SyncedVideoPlayerManager.shared.pause()
                loadClipVideo()
                setupKeyboardHandling()
                // Auto-play the clip after a short delay to ensure video is loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    player?.play()
                    isPlaying = true
                }
            }
            .onDisappear {
                // Return keyboard focus to main player
                focusManager.setFocus(.mainPlayer)

                // Clean up time observer
                if let observer = timeObserver {
                    player?.removeTimeObserver(observer)
                }
                player?.pause()

                // Remove keyboard event monitor
                if let monitor = keyboardMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyboardMonitor = nil
                    print("🔌 Removed ClipPlayerPopup keyboard monitor")
                }
            }

            Divider().background(theme.primaryBorder)

            // Playback Controls
            VStack(spacing: 8) {
                // Timeline scrubber
                HStack(spacing: 12) {
                    Text(formatTime(currentTime))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()
                        .frame(width: 80, alignment: .trailing)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            Rectangle()
                                .fill(theme.primaryBorder)
                                .frame(height: 4)
                                .cornerRadius(2)

                            // Progress track
                            let progress = CMTimeGetSeconds(currentTime) / max(CMTimeGetSeconds(duration), 1.0)
                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 4)
                                .cornerRadius(2)

                            // Scrubber thumb
                            Circle()
                                .fill(theme.primaryText)
                                .frame(width: 12, height: 12)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .offset(x: geometry.size.width * CGFloat(progress) - 6)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let progress = max(0, min(1, value.location.x / geometry.size.width))
                                    let clipDurationSeconds = Double(currentClip.endTimeMs - currentClip.startTimeMs) / 1000.0
                                    let targetTime = clipDurationSeconds * progress
                                    let absoluteTime = CMTime(seconds: Double(currentClip.startTimeMs) / 1000.0 + targetTime, preferredTimescale: 600)
                                    player?.seek(to: absoluteTime)
                                }
                        )
                    }
                    .frame(height: 20)

                    Text(formatTime(duration))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()
                        .frame(width: 80, alignment: .leading)
                }

                // Control buttons
                HStack(spacing: 16) {
                    // Play/Pause button
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.white)
                            .frame(width: 32, height: 32)
                            .background(theme.accent)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Skip backward
                    Button(action: {
                        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 2, preferredTimescale: 600))
                        let clipStart = CMTime(seconds: Double(clip.startTimeMs) / 1000.0, preferredTimescale: 600)
                        player?.seek(to: max(newTime, clipStart))
                    }) {
                        Image(systemName: "gobackward.5")
                            .font(.system(size: 14))
                            .foregroundColor(theme.primaryText)
                            .frame(width: 32, height: 32)
                            .background(theme.primaryBorder)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Skip forward
                    Button(action: {
                        let newTime = CMTimeAdd(currentTime, CMTime(seconds: 2, preferredTimescale: 600))
                        player?.seek(to: newTime)
                    }) {
                        Image(systemName: "goforward.5")
                            .font(.system(size: 14))
                            .foregroundColor(theme.primaryText)
                            .frame(width: 32, height: 32)
                            .background(theme.primaryBorder)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider()
                        .frame(width: 1, height: 24)
                        .background(Color(hex: "333333"))

                    // Start time adjustment
                    VStack(spacing: 2) {
                        Text("Start")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(hex: "666666"))

                        HStack(spacing: 4) {
                            // Extend start left (-5s on start time)
                            Button(action: {
                                adjustClipStart(by: -5)
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 10))
                                    Text("5s")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color(hex: "28c840"))
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Reduce start right (+5s on start time)
                            Button(action: {
                                adjustClipStart(by: 5)
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text("5s")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color(hex: "ff5252"))
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // End time adjustment
                    VStack(spacing: 2) {
                        Text("End")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Color(hex: "666666"))

                        HStack(spacing: 4) {
                            // Reduce end left (-5s on end time)
                            Button(action: {
                                adjustClipEnd(by: -5)
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 10))
                                    Text("5s")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color(hex: "ff5252"))
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Extend end right (+5s on end time)
                            Button(action: {
                                adjustClipEnd(by: 5)
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text("5s")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color(hex: "28c840"))
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    Spacer()

                    Text(formatClipDuration(currentClip))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.surfaceBackground)

            Divider().background(theme.primaryBorder)

            // Actions
            HStack(spacing: 12) {
                Button(action: exportClip) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Export")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: addToPlaylist) {
                    HStack {
                        Image(systemName: "plus.rectangle.on.folder")
                        Text("Add to Playlist")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
            .padding(16)
            .background(theme.surfaceBackground)
        }
        .frame(minWidth: 600, minHeight: 450)
        .background(theme.primaryBackground)
        .toast(manager: toastManager)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            // Pause video when window loses focus
            player?.pause()
            isPlaying = false
            print("⏸ Clip player paused - window lost focus")
        }
    }

    // MARK: - Helper Functions

    private func loadClipVideo() {
        guard let project = navigationState.currentProject,
              let bundle = ProjectManager.shared.currentProject else {
            print("❌ No project open")
            return
        }

        // Get the video file for this clip
        let videos = DatabaseManager.shared.getVideos(projectId: project.id)
        guard let video = videos.first else {
            print("❌ No videos found in project")
            return
        }

        // Create full video URL from bundle path
        let fileName = video.filePath.replacingOccurrences(of: "videos/", with: "")
        let videoURL = bundle.videosPath.appendingPathComponent(fileName)

        print("📹 Loading clip video from: \(videoURL.path)")
        print("   File exists: \(FileManager.default.fileExists(atPath: videoURL.path))")

        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)

        // Use currentClip (updated clip) instead of original clip
        // Seek to the clip's start time
        let startTime = CMTime(seconds: Double(currentClip.startTimeMs) / 1000.0, preferredTimescale: 600)
        let endTime = CMTime(seconds: Double(currentClip.endTimeMs) / 1000.0, preferredTimescale: 600)

        player = AVPlayer(playerItem: playerItem)
        player?.seek(to: startTime)

        // Set clip duration (not full video duration) - use currentClip!
        let clipDurationSeconds = Double(currentClip.endTimeMs - currentClip.startTimeMs) / 1000.0
        duration = CMTime(seconds: clipDurationSeconds, preferredTimescale: 600)
        currentTime = .zero

        // Add periodic time observer to update scrubber
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            // Convert absolute time to clip-relative time
            let relativeTime = CMTimeSubtract(time, startTime)
            self.currentTime = max(.zero, relativeTime)
        }

        // Add boundary observer to loop the clip
        let timeRange = [NSValue(time: endTime)]
        let capturedPlayer = player
        player?.addBoundaryTimeObserver(forTimes: timeRange, queue: .main) {
            Task { @MainActor in
                capturedPlayer?.seek(to: startTime)
                if self.isPlaying {
                    capturedPlayer?.play()
                }
            }
        }

        print("✅ Loaded clip video: \(videoURL.lastPathComponent)")
        print("   Clip range: \(currentClip.formattedStartTime) - \(Double(currentClip.endTimeMs) / 1000.0)s")
        print("   Clip duration: \(clipDurationSeconds)s")
    }

    private func togglePlayPause() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            print("⏸ Paused clip")
        } else {
            player.play()
            isPlaying = true
            print("▶️ Playing clip")
        }
    }

    private func adjustClipStart(by seconds: Int) {
        // Stop playback first to avoid issues
        player?.pause()
        isPlaying = false

        let newStartTimeMs = currentClip.startTimeMs + Int64(seconds * 1000)

        // Ensure start doesn't go below 0 and maintains minimum duration
        let finalStartTimeMs = max(0, min(newStartTimeMs, currentClip.endTimeMs - 1000))

        // Update the current clip
        currentClip = Clip(
            id: currentClip.id,
            gameId: currentClip.gameId,
            startTimeMs: finalStartTimeMs,
            endTimeMs: currentClip.endTimeMs,
            title: currentClip.title,
            notes: currentClip.notes,
            tags: currentClip.tags,
            createdAt: currentClip.createdAt
        )

        // Update in database
        let result = DatabaseManager.shared.updateClipTimes(clipId: currentClip.id, startTimeMs: finalStartTimeMs, endTimeMs: currentClip.endTimeMs)

        switch result {
        case .success:
            let action = seconds < 0 ? "Extended start" : "Reduced start"
            print("✅ \(action) by \(abs(seconds))s - new duration: \(formatClipDuration(currentClip))")
            toastManager.show(
                message: "\(action) by \(abs(seconds))s",
                icon: "checkmark.circle.fill",
                backgroundColor: "2979ff"
            )

            // Also update the corresponding moment's times
            updateMomentForClip(clipStartMs: finalStartTimeMs, clipEndMs: currentClip.endTimeMs)

            // Notify timeline to refresh
            NotificationCenter.default.post(name: NSNotification.Name("ClipUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("TagCreated"), object: nil)

            // Clean up old player
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
                timeObserver = nil
            }
            player = nil

            // Reload video with new start time
            loadClipVideo()

        case .failure(let error):
            print("❌ Failed to adjust clip start: \(error)")
            toastManager.show(message: "Failed to adjust clip start", icon: "exclamationmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func adjustClipEnd(by seconds: Int) {
        // Stop playback first to avoid issues
        player?.pause()
        isPlaying = false

        let newEndTimeMs = currentClip.endTimeMs + Int64(seconds * 1000)

        // Ensure clip doesn't go below minimum duration (1 second)
        let minEndTime = currentClip.startTimeMs + 1000
        let finalEndTimeMs = max(newEndTimeMs, minEndTime)

        // Update the current clip
        currentClip = Clip(
            id: currentClip.id,
            gameId: currentClip.gameId,
            startTimeMs: currentClip.startTimeMs,
            endTimeMs: finalEndTimeMs,
            title: currentClip.title,
            notes: currentClip.notes,
            tags: currentClip.tags,
            createdAt: currentClip.createdAt
        )

        // Update in database
        let result = DatabaseManager.shared.updateClipTimes(clipId: currentClip.id, startTimeMs: currentClip.startTimeMs, endTimeMs: finalEndTimeMs)

        switch result {
        case .success:
            let action = seconds > 0 ? "Extended end" : "Reduced end"
            print("✅ \(action) by \(abs(seconds))s - new duration: \(formatClipDuration(currentClip))")
            toastManager.show(
                message: "\(action) by \(abs(seconds))s",
                icon: "checkmark.circle.fill",
                backgroundColor: "2979ff"
            )

            // Also update the corresponding moment's times
            updateMomentForClip(clipStartMs: currentClip.startTimeMs, clipEndMs: finalEndTimeMs)

            // Notify timeline to refresh
            NotificationCenter.default.post(name: NSNotification.Name("ClipUpdated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("TagCreated"), object: nil)

            // Clean up old player
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
                timeObserver = nil
            }
            player = nil

            // Reload video with new end time
            loadClipVideo()

        case .failure(let error):
            print("❌ Failed to adjust clip end: \(error)")
            toastManager.show(message: "Failed to adjust clip end", icon: "exclamationmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func updateMomentForClip(clipStartMs: Int64, clipEndMs: Int64) {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("⚠️ No project/game available to update moment")
            return
        }

        // Find the moment that corresponds to this clip
        // We match by finding a moment whose original time range overlaps with the clip
        let moments = DatabaseManager.shared.getMoments(gameId: gameId)

        // Find moment that this clip was created from (the original clip times match the moment times)
        if let moment = moments.first(where: { moment in
            // Check if this moment overlaps with the original clip times
            let originalStart = clip.startTimeMs
            let originalEnd = clip.endTimeMs
            let momentStart = moment.startTimestampMs
            let momentEnd = moment.endTimestampMs ?? momentStart

            // Moments match if they overlap with the original clip
            return (originalStart >= momentStart - 10000 && originalStart <= momentEnd + 10000) ||
                   (originalEnd >= momentStart - 10000 && originalEnd <= momentEnd + 10000)
        }) {
            // Update the moment's times to match the adjusted clip
            let result = DatabaseManager.shared.updateMomentTimes(
                momentId: moment.id,
                startTimeMs: clipStartMs,
                endTimeMs: clipEndMs
            )

            switch result {
            case .success:
                print("✅ Updated moment '\(moment.momentCategory)' times to match clip")
            case .failure(let error):
                print("⚠️ Failed to update moment times: \(error)")
            }
        } else {
            print("⚠️ Could not find moment for this clip")
        }
    }

    private func formatClipDuration(_ clip: Clip) -> String {
        let durationSeconds = Double(clip.endTimeMs - clip.startTimeMs) / 1000.0
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTime(_ time: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(time)
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        let seconds = Int(totalSeconds) % 60
        let centiseconds = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 100)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, centiseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
        }
    }

    private func exportClip() {
        toastManager.show(
            message: "Export functionality coming soon",
            icon: "square.and.arrow.down",
            backgroundColor: "5adc8c"
        )
        print("📤 Export clip: \(clip.title)")
    }

    private func addToPlaylist() {
        toastManager.show(
            message: "Playlist functionality coming soon",
            icon: "plus.rectangle.on.folder",
            backgroundColor: "2979ff"
        )
        print("➕ Add to playlist: \(clip.title)")
    }

    // MARK: - Keyboard & Focus Handling

    private func setupKeyboardHandling() {
        // Store the monitor so we can remove it later
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Spacebar (keyCode 49)
            if event.keyCode == 49 && !event.modifierFlags.contains(.command) {
                // Check if we're in a text field
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder {
                    if firstResponder is NSTextView ||
                       firstResponder is NSTextField ||
                       String(describing: type(of: firstResponder)).contains("TextField") {
                        print("⚠️ [ClipPlayer] Text field focused - ignoring spacebar")
                        return event // Let spacebar work in text fields
                    }
                }

                // Check if this popup has keyboard focus
                if self.focusManager.shouldHandle(.clipPopup) {
                    print("✅ [ClipPlayer] Handling spacebar - toggling clip playback")
                    self.togglePlayPause()
                    return nil // Consume the event
                } else {
                    print("⚠️ [ClipPlayer] Not focused - passing spacebar through")
                    return event
                }
            }

            return event
        }

        print("🎹 ClipPlayerPopup keyboard monitor setup")
    }
}
