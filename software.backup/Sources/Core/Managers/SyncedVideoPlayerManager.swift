//
//  SyncedVideoPlayerManager.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import Foundation
import AVFoundation
import Combine
import AppKit

// MARK: - Array Extension for Safe Subscripting
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

/// Manages synchronized playback across multiple video players
@MainActor
class SyncedVideoPlayerManager: ObservableObject {
    // MARK: - Singleton
    static let shared = SyncedVideoPlayerManager()

    // MARK: - Published Properties
    @Published var isPlaying: Bool = false
    @Published var currentTime: CMTime = .zero
    @Published var duration: CMTime = .zero
    @Published var playbackRate: Float = 1.0
    @Published var activePlayerIndex: Int = 0 // Currently active player (for single-angle playback mode)

    // MARK: - Private Properties
    private var players: [AVPlayer] = []
    private var timeObservers: [Int: Any] = [:] // Map player index to its time observer
    private var cancellables = Set<AnyCancellable>()
    private var singleAngleMode: Bool = false // Start in multi-angle mode by default
    private var loadedVideoURLs: [URL] = [] // Track currently loaded videos to avoid reloading
    private var freezeTimer: Timer? // Timer for freeze duration
    private var isFrozen: Bool = false // Track if video is currently frozen

    // MARK: - Initialization
    // Private initializer for singleton
    private init() {
        setupNotificationObservers()
    }

    // MARK: - Public Methods
    func setSingleAngleMode(_ enabled: Bool) {
        guard singleAngleMode != enabled else { return }

        let wasPlaying = isPlaying
        singleAngleMode = enabled
        print("🎬 SyncedVideoPlayerManager: Switched to \(enabled ? "single-angle" : "multi-angle") mode")

        if enabled {
            // Switching to single-angle mode - pause all except active
            for (index, player) in players.enumerated() {
                if index != activePlayerIndex {
                    player.pause()
                }
            }

            // Update duration to match active player only
            if let activePlayer = players[safe: activePlayerIndex],
               let item = activePlayer.currentItem,
               item.status == .readyToPlay {
                let activeDuration = item.duration
                if CMTIME_IS_VALID(activeDuration) {
                    duration = activeDuration
                    print("📏 Set duration to active angle \(activePlayerIndex): \(CMTimeGetSeconds(activeDuration))s")
                }
            }
        } else {
            // Switching to multi-angle mode - sync and resume all players
            let currentTime = self.currentTime
            for (index, player) in players.enumerated() {
                // Sync all players to current time
                player.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)

                // Fix audio: use ONLY isMuted, not volume
                player.isMuted = (index != activePlayerIndex)
            }

            // Update duration to longest video in multi-angle mode
            var longestDuration: CMTime = .zero
            for player in players {
                if let item = player.currentItem, item.status == .readyToPlay {
                    if CMTIME_IS_VALID(item.duration) && CMTimeCompare(item.duration, longestDuration) > 0 {
                        longestDuration = item.duration
                    }
                }
            }
            if CMTIME_IS_VALID(longestDuration) {
                duration = longestDuration
                print("📏 Set duration to longest video: \(CMTimeGetSeconds(longestDuration))s")
            }

            // Resume playback if we were playing
            if wasPlaying {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.play()
                }
            }
        }
    }

    deinit {
        // Cleanup must be done synchronously in deinit
        // Since we're already on MainActor (class is @MainActor), this is safe
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }

    // MARK: - Player Management
    func setupPlayers(videoURLs: [URL]) async {
        // Check if we already have these videos loaded
        if loadedVideoURLs == videoURLs && !players.isEmpty {
            print("✅ SyncedVideoPlayerManager: Videos already loaded, skipping setup")
            return
        }

        print("🎬 SyncedVideoPlayerManager: Setting up \(videoURLs.count) players")

        // Clean up existing players
        cleanup()

        // Pre-load durations from assets (can do this off main thread)
        let maxDuration = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var maxDur: CMTime = .zero
                for url in videoURLs {
                    let asset = AVAsset(url: url)
                    let assetDuration = asset.duration
                    if CMTIME_IS_VALID(assetDuration) && CMTimeCompare(assetDuration, maxDur) > 0 {
                        maxDur = assetDuration
                    }
                }
                continuation.resume(returning: maxDur)
            }
        }

        // Set duration immediately if we found a valid one
        if CMTIME_IS_VALID(maxDuration) && CMTimeCompare(maxDuration, .zero) > 0 {
            self.duration = maxDuration
            print("📏 Pre-set duration from assets: \(CMTimeGetSeconds(maxDuration))s")
        }

        // Create players on MAIN THREAD (required for AVPlayer on macOS)
        let newPlayers = videoURLs.enumerated().map { (index, url) in
            // Use cached asset loading for better performance
            let asset = AVURLAsset(url: url, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: false  // Faster loading
            ])
            asset.resourceLoader.preloadsEligibleContentKeys = true

            let playerItem = AVPlayerItem(asset: asset)

            // Reduce buffer size from 2.0s to 1.0s to prevent overload with multi-angle
            playerItem.preferredForwardBufferDuration = 1.0  // 1 second buffer (reduced from 2.0)

            // Prefer software decoding to avoid hardware decoder limits when playing 4 videos
            playerItem.videoComposition = nil  // Disable video composition for better compatibility
            playerItem.audioTimePitchAlgorithm = .varispeed  // Use varispeed for performance (macOS compatible)

            let player = AVPlayer(playerItem: playerItem)

            player.actionAtItemEnd = .none  // Don't auto-pause when video ends

            // Fix audio: use ONLY isMuted, NOT volume to avoid conflicts
            player.isMuted = (index != self.activePlayerIndex)

            // Check if video has audio (for logging only)
            let audioTracks = asset.tracks(withMediaType: .audio)
            if index == self.activePlayerIndex {
                print("🔊 Player \(index) audio ENABLED (audio tracks: \(audioTracks.count))")
            } else {
                print("🔇 Player \(index) audio MUTED")
            }

            // Optimize for smooth playback with multiple videos
            player.automaticallyWaitsToMinimizeStalling = true  // Prevent decoder overload
            player.preventsDisplaySleepDuringVideoPlayback = true

            return player
        }

        self.players = newPlayers
        self.loadedVideoURLs = videoURLs

        // Set up time observer on active player
        if let activePlayer = self.players[safe: self.activePlayerIndex] {
            self.setupTimeObserver(for: activePlayer, at: self.activePlayerIndex)
        }

        // Update duration - use longest video in multi-angle mode
        self.updateDurationFromAllPlayers()

        print("✅ SyncedVideoPlayerManager: Players setup complete (\(self.players.count) players, active angle: \(self.activePlayerIndex), single-angle mode: \(self.singleAngleMode))")
    }

    func getPlayer(at index: Int) -> AVPlayer? {
        guard index < players.count else { return nil }
        return players[index]
    }

    /// Switch to a different angle (for single-angle playback mode)
    func switchToAngle(_ angleIndex: Int) {
        guard angleIndex < players.count else {
            print("⚠️ Invalid angle index: \(angleIndex)")
            return
        }

        guard angleIndex != activePlayerIndex else {
            print("ℹ️ Already on angle \(angleIndex)")
            return
        }

        print("🎬 SyncedVideoPlayerManager: Switching from angle \(activePlayerIndex) to \(angleIndex)")

        let wasPlaying = isPlaying
        let currentTime = self.currentTime

        // Pause old active player
        if let oldPlayer = players[safe: activePlayerIndex] {
            oldPlayer.pause()
            print("⏸️ Paused angle \(activePlayerIndex)")
        }

        // Remove time observer from old player
        if let observer = timeObservers[activePlayerIndex], let oldPlayer = players[safe: activePlayerIndex] {
            oldPlayer.removeTimeObserver(observer)
            timeObservers.removeValue(forKey: activePlayerIndex)
            print("🗑️ Removed time observer from player \(activePlayerIndex)")
        }

        // Update active player index
        activePlayerIndex = angleIndex

        // Set up time observer on new active player
        if let newPlayer = players[safe: activePlayerIndex] {
            setupTimeObserver(for: newPlayer, at: activePlayerIndex)

            // Update duration to match the new active player in single-angle mode
            if singleAngleMode, let item = newPlayer.currentItem, item.status == .readyToPlay {
                let newDuration = item.duration
                if CMTIME_IS_VALID(newDuration) {
                    duration = newDuration
                    print("📏 Updated duration to active angle \(angleIndex): \(CMTimeGetSeconds(newDuration))s")
                }
            }
        }

        // Sync new player to current time
        if let newPlayer = players[safe: activePlayerIndex] {
            newPlayer.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                guard let self = self, finished else { return }

                // Switch audio to new player (use ONLY isMuted)
                for (index, player) in self.players.enumerated() {
                    player.isMuted = (index != angleIndex)
                }

                // Resume playback if was playing
                if wasPlaying {
                    Task { @MainActor in
                        self.play()
                    }
                }
            }
            print("✅ Synced angle \(angleIndex) to \(currentTime.seconds)s")
        }
    }

    /// Switch audio to a different player (angle) - legacy method
    func setAudioSource(playerIndex: Int) {
        // In single-angle mode, this switches the active angle
        if singleAngleMode {
            switchToAngle(playerIndex)
        } else {
            // Multi-angle mode: just switch audio
            guard playerIndex < players.count else {
                print("⚠️ Invalid player index: \(playerIndex)")
                return
            }

            print("🔊 SyncedVideoPlayerManager: Switching audio to player \(playerIndex)")

            for (index, player) in players.enumerated() {
                if index == playerIndex {
                    player.isMuted = false
                    print("🔊 Player \(index) audio ENABLED")
                } else {
                    player.isMuted = true
                    print("🔇 Player \(index) audio MUTED")
                }
            }
        }
    }

    // MARK: - Playback Controls
    func play() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Re-verify audio routing before playing (prevent audio loss)
            for (index, player) in self.players.enumerated() {
                player.isMuted = (index != self.activePlayerIndex)
            }

            if self.singleAngleMode {
                // Only play the active player for performance
                print("▶️ SyncedVideoPlayerManager: Playing angle \(self.activePlayerIndex)")
                if let activePlayer = self.players[safe: self.activePlayerIndex] {
                    if activePlayer.currentTime() < activePlayer.currentItem?.duration ?? .zero {
                        activePlayer.play()
                        activePlayer.rate = self.playbackRate
                    }
                }
            } else {
                // Play all players (multi-angle mode)
                print("▶️ SyncedVideoPlayerManager: Playing all angles")
                self.players.forEach { player in
                    if player.currentTime() < player.currentItem?.duration ?? .zero {
                        player.play()
                        player.rate = self.playbackRate
                    }
                }
            }
            self.isPlaying = true
        }
    }

    func pause() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            if self.singleAngleMode {
                print("⏸️ SyncedVideoPlayerManager: Pausing angle \(self.activePlayerIndex)")
                self.players[safe: self.activePlayerIndex]?.pause()
            } else {
                print("⏸️ SyncedVideoPlayerManager: Pausing all angles")
                self.players.forEach { $0.pause() }
            }
            self.isPlaying = false
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Freeze video playback for a specified duration (in seconds)
    func freezeFor(duration: Double) {
        guard duration > 0, !isFrozen else { return }

        // Cancel any existing freeze timer
        freezeTimer?.invalidate()
        freezeTimer = nil

        // Pause playback
        let wasPlaying = isPlaying
        if wasPlaying {
            pause()
        }

        isFrozen = true
        print("❄️ Freezing playback for \(duration)s")

        // Schedule resume after freeze duration
        freezeTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                self.isFrozen = false
                print("▶️ Resuming playback after freeze")

                // Resume playback if it was playing before freeze
                if wasPlaying {
                    self.play()
                }

                self.freezeTimer = nil
            }
        }
    }

    /// Cancel any active freeze
    func cancelFreeze() {
        freezeTimer?.invalidate()
        freezeTimer = nil
        isFrozen = false
    }

    func seek(to time: CMTime) {
        print("⏩ SyncedVideoPlayerManager: Seeking to \(time.seconds)s")

        // Pause during seek for smoother experience
        let wasPlaying = isPlaying
        pause()

        if singleAngleMode {
            // Only seek the active player
            if let activePlayer = players[safe: activePlayerIndex] {
                // Use larger tolerance for smoother seeking
                let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
                activePlayer.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] finished in
                    guard let self = self, finished else { return }

                    // Ensure audio is properly configured after seek
                    DispatchQueue.main.async {
                        // Re-verify audio routing after seek (use ONLY isMuted)
                        for (index, player) in self.players.enumerated() {
                            player.isMuted = (index != self.activePlayerIndex)
                        }

                        if wasPlaying {
                            self.play()
                        }
                    }
                }
            }
        } else {
            // Seek all players (multi-angle mode)
            Task { @MainActor in
                let group = DispatchGroup()

                for player in self.players {
                    group.enter()
                    let tolerance = CMTime(seconds: 0.01, preferredTimescale: 600)
                    player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance) { _ in
                        group.leave()
                    }
                }

                group.notify(queue: .main) { [weak self] in
                    guard let self = self else { return }
                    Task { @MainActor in
                        // Re-verify audio routing after seek (prevent audio loss, use ONLY isMuted)
                        for (index, player) in self.players.enumerated() {
                            player.isMuted = (index != self.activePlayerIndex)
                        }

                        if wasPlaying {
                            self.play()
                        }
                    }
                }
            }
        }
    }

    func setRate(_ rate: Float) {
        print("⏩ SyncedVideoPlayerManager: Setting playback rate to \(rate)x")
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.playbackRate = rate
            if self.isPlaying {
                self.players.forEach { $0.rate = rate }
            }
        }
    }

    // MARK: - Time Synchronization
    private func setupTimeObserver(for player: AVPlayer, at index: Int) {
        // Update every 30th of a second for smooth scrubbing
        let interval = CMTime(seconds: 1.0/30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            // Update current time on main thread
            Task { @MainActor in
                self.currentTime = time
            }

            // No need to sync other players in single-angle mode
            // Only the active player is playing
        }

        // Store the observer for this player
        timeObservers[index] = observer
        print("✅ Added time observer for player \(index)")
    }

    private func updateDurationFromAllPlayers() {
        // Find the longest duration among all players immediately
        var maxDuration: CMTime = .zero

        print("🔍 Checking durations for \(players.count) players...")
        for (index, player) in players.enumerated() {
            guard let currentItem = player.currentItem else {
                print("   Player \(index): No current item")
                continue
            }

            let itemDuration = currentItem.duration
            let itemStatus = currentItem.status
            print("   Player \(index): duration=\(CMTimeGetSeconds(itemDuration))s, status=\(itemStatus.rawValue)")

            // Check immediate duration if already ready
            if currentItem.status == .readyToPlay && CMTIME_IS_VALID(itemDuration) {
                if CMTimeCompare(itemDuration, maxDuration) > 0 {
                    maxDuration = itemDuration
                    print("   → New max duration: \(CMTimeGetSeconds(maxDuration))s")
                }
            }

            // Also observe duration changes and errors for each player
            currentItem.publisher(for: \.status)
                .sink { [weak self] status in
                    guard let self = self else { return }

                    if status == .readyToPlay {
                        // Find the maximum duration across all loaded players
                        var longestDuration: CMTime = .zero
                        for p in self.players {
                            if let item = p.currentItem, item.status == .readyToPlay, CMTIME_IS_VALID(item.duration) {
                                if CMTimeCompare(item.duration, longestDuration) > 0 {
                                    longestDuration = item.duration
                                }
                            }
                        }

                        // Update published duration if changed
                        if CMTIME_IS_VALID(longestDuration) && CMTimeCompare(longestDuration, self.duration) != 0 {
                            Task { @MainActor in
                                self.duration = longestDuration
                                print("📏 Updated duration to longest video: \(CMTimeGetSeconds(longestDuration))s")
                            }
                        }
                    } else if status == .failed {
                        if let error = currentItem.error {
                            print("❌ Player item failed with error: \(error.localizedDescription)")
                            if let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError {
                                print("   Underlying error: \(underlyingError.domain) code: \(underlyingError.code)")
                            }
                        }
                    }
                }
                .store(in: &cancellables)
        }

        // Set initial duration if any player is already ready
        if CMTIME_IS_VALID(maxDuration) && CMTimeCompare(maxDuration, .zero) > 0 {
            Task { @MainActor in
                duration = maxDuration
                print("📏 Initial duration set to longest video: \(CMTimeGetSeconds(maxDuration))s")
            }
        } else {
            print("⚠️ No valid duration found yet, will update when players are ready")
        }
    }

    /// Restore audio session (called when app becomes active)
    func restoreAudioSession() {
        // Re-verify audio routing to ensure proper audio playback
        for (index, player) in players.enumerated() {
            player.isMuted = (index != activePlayerIndex)
        }
        print("🔊 Audio session restored, active player: \(activePlayerIndex)")
    }

    // MARK: - Cleanup
    nonisolated private func setupNotificationObservers() {
        // Observe when videos finish playing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        // Observe when window loses focus
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )

        // Observe when screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSNotification.Name("ScreenDidChange"),
            object: nil
        )
    }

    @objc private func windowDidResignKey(notification: Notification) {
        Task { @MainActor in
            // Pause playback when main window loses focus
            if isPlaying {
                pause()
                print("⏸ Video paused - window lost focus")
            }
        }
    }

    @objc private func screenDidChange(notification: Notification) {
        Task { @MainActor in
            // Pause playback when navigating away from video screens
            if isPlaying {
                pause()
                print("⏸ Video paused - screen changed")
            }
        }
    }

    @objc private func playerDidFinishPlaying(notification: Notification) {
        print("⏹️ SyncedVideoPlayerManager: A video finished playback")

        // Check if ALL videos have finished (some might be different lengths)
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            let allFinished = self.players.allSatisfy { player in
                guard let item = player.currentItem else { return true }
                return player.currentTime() >= item.duration
            }

            if allFinished {
                print("⏹️ SyncedVideoPlayerManager: All videos finished")
                self.isPlaying = false
            } else {
                print("⏹️ SyncedVideoPlayerManager: Some videos still playing")
                // Keep playing other videos
            }
        }
    }

    private func cleanup() {
        // Remove all time observers
        for (index, observer) in timeObservers {
            if let player = players[safe: index] {
                player.removeTimeObserver(observer)
                print("🗑️ Removed time observer from player \(index) during cleanup")
            }
        }
        timeObservers.removeAll()

        // Pause and cleanup players
        players.forEach { player in
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        players.removeAll()
        loadedVideoURLs.removeAll()

        // Cancel freeze timer if active
        freezeTimer?.invalidate()
        freezeTimer = nil
        isFrozen = false

        cancellables.removeAll()

        print("✅ SyncedVideoPlayerManager cleanup complete")
    }
}
