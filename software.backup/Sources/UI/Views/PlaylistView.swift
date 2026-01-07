//
//  PlaylistView.swift
//  maxmiize-v1
//
//  Playlist builder for assembling possession-based clips with coaching purpose
//

import SwiftUI
import AVFoundation

struct PlaylistView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var playlistManager = PlaylistManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var playerManager = SyncedVideoPlayerManager.shared

    @State private var selectedMainNav: MainNavItem = .playlist
    @State private var showSettings = false
    @State private var showFilterSheet = false
    @State private var showCreatePlaylistSheet = false
    @State private var selectedClipIndex: Int? = nil
    @State private var seekDebounceTask: Task<Void, Never>?
    @State private var clipEndObserver: Any?
    @State private var timeObserver: Any?

    // Filter state
    @State private var activeFilters = PlaylistFilters()
    @State private var generatedClips: [PlaylistClipWithMetadata] = []

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Main Navigation Bar
                MainNavigationBar(selectedItem: $selectedMainNav)
                    .onChange(of: selectedMainNav) { newValue in
                        handleNavigationChange(newValue)
                    }

                if playlistManager.presentationMode.isEnabled {
                    // Presentation Mode View
                    presentationModeView
                } else {
                    // Normal Playlist Builder View
                    GeometryReader { geometry in
                        HStack(spacing: 6) {
                            // Left Panel - Playlist Library & Filters
                            playlistLibrarySection
                                .frame(width: min(max(geometry.size.width * 0.20, 260), 320))

                            // Center Panel - Current Playlist (video + controls only)
                            currentPlaylistSection
                                .frame(maxWidth: .infinity)

                            // Right Panel - Clips List + Metadata (only when clips exist)
                            if !playlistManager.enrichedClips.isEmpty {
                                let currentIndex = selectedClipIndex ?? 0
                                if currentIndex < playlistManager.enrichedClips.count {
                                    rightSidebarPanel(currentClip: playlistManager.enrichedClips[currentIndex])
                                        .frame(width: min(max(geometry.size.width * 0.25, 300), 380))
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showFilterSheet) {
            filterSheetView
        }
        .sheet(isPresented: $showCreatePlaylistSheet) {
            createPlaylistSheetView
        }
        .onAppear {
            loadPlaylists()
        }
        .globalKeyboardShortcuts {
            // ESC handler (no action needed for playlist view)
        }
        .onDisappear {
            // Clean up observers when leaving the view
            if let observer = clipEndObserver, let player = playerManager.getPlayer(at: playerManager.activePlayerIndex) {
                player.removeTimeObserver(observer)
                clipEndObserver = nil
            }
            if let observer = timeObserver, let player = playerManager.getPlayer(at: playerManager.activePlayerIndex) {
                player.removeTimeObserver(observer)
                timeObserver = nil
            }
        }
    }

    // MARK: - Playlist Library Section

    private var playlistLibrarySection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PLAYLISTS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                Button(action: { showCreatePlaylistSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11))
                        Text("New")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Text("Purpose-driven clip collections")
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            Divider()
                .background(theme.secondaryBorder)

            // Playlists list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(playlistManager.playlists) { playlist in
                        PlaylistRow(
                            playlist: playlist,
                            isSelected: playlistManager.currentPlaylist?.id == playlist.id,
                            onTap: { loadPlaylist(playlist) }
                        )
                    }

                    if playlistManager.playlists.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "list.clipboard")
                                .font(.system(size: 32))
                                .foregroundColor(theme.primaryBorder)

                            Text("No playlists yet")
                                .font(.system(size: 13))
                                .foregroundColor(theme.tertiaryText)

                            Text("Create a playlist to get started")
                                .font(.system(size: 11))
                                .foregroundColor(theme.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }

            Spacer()

            // Filter button (only enabled when a playlist is selected)
            Button(action: { showFilterSheet = true }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 14))
                    Text("Generate from Filters")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(playlistManager.currentPlaylist != nil ? Color.white : theme.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(playlistManager.currentPlaylist != nil ? theme.accent.opacity(0.9) : theme.secondaryBorder)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(playlistManager.currentPlaylist == nil)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Current Playlist Section

    private var currentPlaylistSection: some View {
        VStack(spacing: 0) {
            if playlistManager.currentPlaylist != nil {
                if !playlistManager.enrichedClips.isEmpty {
                    let currentIndex = selectedClipIndex ?? 0
                    if currentIndex < playlistManager.enrichedClips.count {
                        let currentClip = playlistManager.enrichedClips[currentIndex]

                        VStack(spacing: 0) {
                            // Unified header with playlist info and stats
                            VStack(spacing: 8) {
                                HStack {
                                    if let playlist = playlistManager.currentPlaylist {
                                        HStack(spacing: 8) {
                                            Image(systemName: playlist.purpose.icon)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: playlist.purpose.color))

                                            Text(playlist.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(theme.primaryText)

                                            if let description = playlist.description {
                                                Text("·")
                                                    .foregroundColor(theme.tertiaryText)
                                                Text(description)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(theme.tertiaryText)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }

                                    Spacer()

                                    // Stats inline
                                    HStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "film")
                                                .font(.system(size: 10))
                                            Text("\(playlistManager.enrichedClips.count)")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(theme.tertiaryText)

                                        HStack(spacing: 4) {
                                            Image(systemName: "clock")
                                                .font(.system(size: 10))
                                            Text(totalDuration)
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(theme.tertiaryText)

                                        Button(action: { playlistManager.enterPresentationMode() }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "play.rectangle.fill")
                                                    .font(.system(size: 11))
                                                Text("Present")
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                            .foregroundColor(Color.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(theme.accent)
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            // Video player
                            ZStack {
                                if let player = playerManager.getPlayer(at: playerManager.activePlayerIndex) {
                                    VideoPlayerView(
                                        player: player,
                                        videoGravity: .resizeAspect
                                    )
                                    .background(theme.surfaceBackground)
                                } else {
                                    Rectangle()
                                        .fill(theme.surfaceBackground)
                                }
                            }

                            // Playback controls
                            clipPlaybackControls(clip: currentClip)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }
                } else {
                    // Empty state - no clips
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            if let playlist = playlistManager.currentPlaylist {
                                HStack(spacing: 8) {
                                    Image(systemName: playlist.purpose.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: playlist.purpose.color))

                                    Text(playlist.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(theme.primaryText)

                                    if let description = playlist.description {
                                        Text("·")
                                            .foregroundColor(theme.tertiaryText)
                                        Text(description)
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.tertiaryText)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Spacer()

                        VStack(spacing: 12) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 48))
                                .foregroundColor(theme.primaryBorder)

                            Text("No clips in playlist")
                                .font(.system(size: 13))
                                .foregroundColor(theme.tertiaryText)

                            Text("Use filters to generate clips")
                                .font(.system(size: 11))
                                .foregroundColor(theme.tertiaryText)
                        }

                        Spacer()
                    }
                }
            } else {
                // No playlist selected
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(theme.primaryBorder)

                    Text("Create or select a playlist")
                        .font(.system(size: 14))
                        .foregroundColor(theme.tertiaryText)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    private func clipPlaybackControls(clip: PlaylistClipWithMetadata) -> some View {
        VStack(spacing: 10) {
            // Timeline with time labels
            VStack(spacing: 4) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(theme.secondaryBorder)
                            .frame(height: 6)
                            .cornerRadius(3)

                        // Calculate progress relative to clip duration
                        let currentSeconds = CMTimeGetSeconds(playerManager.currentTime)
                        let clipStartSeconds = Double(clip.clip.startTimeMs) / 1000.0
                        let clipEndSeconds = Double(clip.clip.endTimeMs) / 1000.0
                        let relativePosition = currentSeconds - clipStartSeconds

                        // If we're at or past the end, show 100%
                        let progress: Double = {
                            guard clip.clip.duration > 0 else { return 0 }
                            if currentSeconds >= clipEndSeconds - 0.1 {
                                return 1.0
                            } else {
                                return min(max(relativePosition / clip.clip.duration, 0), 1)
                            }
                        }()

                        // Progress indicator
                        Rectangle()
                            .fill(theme.accent)
                            .frame(width: max(geo.size.width * CGFloat(progress), 0), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)

                // Time labels
                HStack {
                    let currentSeconds = CMTimeGetSeconds(playerManager.currentTime)
                    let clipStartSeconds = Double(clip.clip.startTimeMs) / 1000.0
                    let relativePosition = max(currentSeconds - clipStartSeconds, 0)

                    Text(formatTime(relativePosition))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()

                    Spacer()

                    Text(clip.clip.formattedDuration)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()
                }
            }

            // Playback controls - rounded card with centered content
            HStack(spacing: 12) {
                // Previous clip
                Button(action: playPreviousClip) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled((selectedClipIndex ?? 0) == 0)

                // Play/Pause
                Button(action: { playerManager.togglePlayPause() }) {
                    Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(PlainButtonStyle())

                // Next clip
                Button(action: playNextClip) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 15))
                        .foregroundColor(theme.primaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled((selectedClipIndex ?? 0) >= playlistManager.enrichedClips.count - 1)

                Spacer()

                // Clip counter
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Clip \((selectedClipIndex ?? 0) + 1) of \(playlistManager.enrichedClips.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(theme.surfaceBackground)
            .cornerRadius(12)

            // Compact inline clip details section - rounded card
            VStack(alignment: .leading, spacing: 8) {
                // Title and metadata in one compact row
                VStack(alignment: .leading, spacing: 6) {
                    Text(clip.clip.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)

                    // Metadata badges - compact horizontal layout
                    HStack(spacing: 6) {
                        // Quarter
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(clip.formattedQuarter)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.secondaryBorder)
                        .cornerRadius(4)

                        // Outcome
                        if let outcome = clip.outcome {
                            HStack(spacing: 3) {
                                Image(systemName: outcome == "Made" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 8))
                                Text(outcome)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(outcome == "Made" ? Color(hex: "5adc8c") : Color(hex: "ff5252"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(theme.secondaryBorder)
                            .cornerRadius(4)
                        }

                        // Duration
                        HStack(spacing: 3) {
                            Image(systemName: "timer")
                                .font(.system(size: 8))
                            Text(clip.clip.formattedDuration)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.secondaryBorder)
                        .cornerRadius(4)

                        // Events inline
                        if !clip.layers.isEmpty {
                            Text(clip.layers.map { $0.layerType }.joined(separator: ", "))
                                .font(.system(size: 9))
                                .foregroundColor(theme.tertiaryText)
                                .lineLimit(1)
                        }
                    }

                    // Players and notes in compact single line if present
                    if !clip.playerNames.isEmpty && clip.playerNames != "—" {
                        HStack(spacing: 4) {
                            Text("Players:")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)
                            Text(clip.playerNames)
                                .font(.system(size: 9))
                                .foregroundColor(theme.primaryText)
                                .lineLimit(1)
                        }
                    }

                    // Notes - compact single line
                    if !clip.clip.notes.isEmpty {
                        HStack(spacing: 4) {
                            Text("Notes:")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)
                            Text(clip.clip.notes)
                                .font(.system(size: 9))
                                .foregroundColor(theme.primaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(theme.surfaceBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - Right Sidebar Panel (Unified Clips List with Details)

    private func rightSidebarPanel(currentClip: PlaylistClipWithMetadata) -> some View {
        VStack(spacing: 0) {
            // Header with clips count
            HStack {
                Text("PLAYLIST CLIPS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                Text("\(playlistManager.enrichedClips.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.tertiaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.secondaryBorder)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(theme.secondaryBorder)

            // Unified clips list with integrated details
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(playlistManager.enrichedClips.enumerated()), id: \.element.id) { index, clip in
                        PlaylistClipRowWithDetails(
                            clip: clip,
                            index: index + 1,
                            isSelected: (selectedClipIndex ?? 0) == index,
                            onSelect: {
                                selectedClipIndex = index
                                playClip(at: index)
                            },
                            onDelete: {
                                playlistManager.removeClips(at: IndexSet(integer: index))
                                if selectedClipIndex == index {
                                    selectedClipIndex = max(0, index - 1)
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Compact Clip Metadata Details

    private func clipMetadataDetailsCompact(clip: PlaylistClipWithMetadata) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("DETAILS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Metadata badges
                    HStack(spacing: 6) {
                        // Quarter badge
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))
                            Text(clip.formattedQuarter)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.secondaryBorder)
                        .cornerRadius(3)

                        // Outcome badge
                        if let outcome = clip.outcome {
                            HStack(spacing: 3) {
                                Image(systemName: outcome == "Made" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 8))
                                Text(outcome)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(outcome == "Made" ? Color(hex: "5adc8c") : Color(hex: "ff5252"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(theme.secondaryBorder)
                            .cornerRadius(3)
                        }

                        // Duration
                        HStack(spacing: 3) {
                            Image(systemName: "timer")
                                .font(.system(size: 8))
                            Text(clip.clip.formattedDuration)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.secondaryBorder)
                        .cornerRadius(3)
                    }

                    // Moment category
                    if let moment = clip.moment {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Type")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            Text(moment.momentCategory)
                                .font(.system(size: 11))
                                .foregroundColor(theme.primaryText)
                        }
                    }

                    // Events (layers)
                    if !clip.layers.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Events")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            ForEach(clip.layers.prefix(3)) { layer in
                                Text("• \(layer.layerType)")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.primaryText)
                            }
                        }
                    }

                    // Players
                    if !clip.playerNames.isEmpty && clip.playerNames != "—" {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Players")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            Text(clip.playerNames)
                                .font(.system(size: 10))
                                .foregroundColor(theme.primaryText)
                        }
                    }

                    // Notes
                    if !clip.clip.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notes")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            Text(clip.clip.notes)
                                .font(.system(size: 10))
                                .foregroundColor(theme.primaryText)
                                .lineLimit(3)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Clip Metadata Section (Unused)

    private func clipMetadataSection(clip: PlaylistClipWithMetadata) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("CLIP DETAILS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .background(theme.secondaryBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        Text(clip.clip.title)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText)
                    }

                    // Metadata badges
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Metadata")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        HStack(spacing: 8) {
                            // Quarter badge
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(clip.formattedQuarter)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.secondaryBorder)
                            .cornerRadius(4)

                            // Outcome badge
                            if let outcome = clip.outcome {
                                HStack(spacing: 4) {
                                    Image(systemName: outcome == "Made" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.system(size: 9))
                                    Text(outcome)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundColor(outcome == "Made" ? Color(hex: "5adc8c") : Color(hex: "ff5252"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.secondaryBorder)
                                .cornerRadius(4)
                            }

                            // Duration
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.system(size: 9))
                                Text(clip.clip.formattedDuration)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(theme.secondaryBorder)
                            .cornerRadius(4)
                        }
                    }

                    // Moment category
                    if let moment = clip.moment {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Moment Type")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            Text(moment.momentCategory)
                                .font(.system(size: 12))
                                .foregroundColor(theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(theme.secondaryBorder)
                                .cornerRadius(6)
                        }
                    }

                    // Events (layers)
                    if !clip.layers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Events")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            ForEach(clip.layers) { layer in
                                Text("• \(layer.layerType)")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.primaryText)
                            }
                        }
                    }

                    // Players
                    if !clip.playerNames.isEmpty && clip.playerNames != "—" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Players")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            Text(clip.playerNames)
                                .font(.system(size: 11))
                                .foregroundColor(theme.primaryText)
                        }
                    }

                    // Notes
                    if !clip.clip.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            Text(clip.clip.notes)
                                .font(.system(size: 11))
                                .foregroundColor(theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(theme.secondaryBorder)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Presentation Mode View

    private var presentationModeView: some View {
        VStack(spacing: 0) {
            // Presentation header - compact
            HStack {
                if let playlist = playlistManager.currentPlaylist {
                    HStack(spacing: 6) {
                        Image(systemName: playlist.purpose.icon)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: playlist.purpose.color))

                        Text(playlist.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                    }
                }

                Spacer()

                // Clip counter
                if playlistManager.presentationMode.currentClipIndex < playlistManager.enrichedClips.count {
                    Text("\(playlistManager.presentationMode.currentClipIndex + 1) / \(playlistManager.enrichedClips.count)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.secondaryBorder)
                        .cornerRadius(5)
                }

                // Exit presentation mode
                Button(action: { playlistManager.exitPresentationMode() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                        Text("Exit")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.secondaryBorder)
                    .cornerRadius(5)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(theme.secondaryBackground)

            // Main content area with proper margins
            if playlistManager.presentationMode.currentClipIndex < playlistManager.enrichedClips.count {
                let currentClip = playlistManager.enrichedClips[playlistManager.presentationMode.currentClipIndex]

                VStack(spacing: 12) {
                    // Video player with margins
                    ZStack {
                        if let player = playerManager.getPlayer(at: playerManager.activePlayerIndex) {
                            VideoPlayerView(
                                player: player,
                                videoGravity: .resizeAspect
                            )
                            .background(Color.black)
                            .cornerRadius(8)
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // Clip details centered under video - more compact
                    presentationClipDetails(clip: currentClip)
                        .padding(.horizontal, 24)
                }
            }

            Spacer()

            // Simple playback controls - compact
            presentationControls
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .background(theme.secondaryBackground)
        }
        .padding(12)
        .onAppear {
            setupPresentationModeObservers()
        }
    }

    private func presentationClipDetails(clip: PlaylistClipWithMetadata) -> some View {
        VStack(spacing: 10) {
            // Clip title - more compact
            Text(clip.clip.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Compact inline metadata
            HStack(spacing: 8) {
                // Quarter
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(clip.formattedQuarter)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.secondaryBorder)
                .cornerRadius(4)

                // Outcome
                if let outcome = clip.outcome {
                    HStack(spacing: 3) {
                        Image(systemName: outcome == "Made" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 8))
                        Text(outcome)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(outcome == "Made" ? Color(hex: "5adc8c") : Color(hex: "ff5252"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.secondaryBorder)
                    .cornerRadius(4)
                }

                // Duration
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 8))
                    Text(clip.clip.formattedDuration)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.secondaryBorder)
                .cornerRadius(4)

                // Events inline
                if !clip.layers.isEmpty {
                    Text(clip.layers.map { $0.layerType }.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                        .lineLimit(1)
                }
            }

            // Players and notes in compact horizontal layout
            HStack(spacing: 16) {
                if !clip.playerNames.isEmpty && clip.playerNames != "—" {
                    HStack(spacing: 4) {
                        Text("Players:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)
                        Text(clip.playerNames)
                            .font(.system(size: 10))
                            .foregroundColor(theme.primaryText)
                            .lineLimit(1)
                    }
                }

                if !clip.clip.notes.isEmpty {
                    HStack(spacing: 4) {
                        Text("Notes:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)
                        Text(clip.clip.notes)
                            .font(.system(size: 10))
                            .foregroundColor(theme.primaryText)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: 900)
    }

    private var presentationControls: some View {
        HStack(spacing: 20) {
            // Previous
            Button(action: {
                playlistManager.playPreviousClip()
                if playlistManager.presentationMode.currentClipIndex < playlistManager.enrichedClips.count {
                    playClip(at: playlistManager.presentationMode.currentClipIndex)
                }
            }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.primaryText)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(playlistManager.presentationMode.currentClipIndex == 0)

            Spacer()

            // Play/Pause
            Button(action: {
                playerManager.togglePlayPause()
                playlistManager.presentationMode.isPlaying = playerManager.isPlaying
            }) {
                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Next
            Button(action: {
                playlistManager.playNextClip()
                if playlistManager.presentationMode.currentClipIndex < playlistManager.enrichedClips.count {
                    playClip(at: playlistManager.presentationMode.currentClipIndex)
                }
            }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.primaryText)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(playlistManager.presentationMode.currentClipIndex >= playlistManager.enrichedClips.count - 1)
        }
    }

    // MARK: - Filter Sheet

    private var filterSheetView: some View {
        FilterSheetView(
            filters: $activeFilters,
            projectId: navigationState.currentProject?.id,
            onGenerate: { filters in
                generateClipsFromFilters(filters)
                showFilterSheet = false
            },
            onCancel: {
                showFilterSheet = false
            }
        )
    }

    // MARK: - Create Playlist Sheet

    private var createPlaylistSheetView: some View {
        CreatePlaylistSheet(
            onSave: { name, purpose, description in
                createNewPlaylist(name: name, purpose: purpose, description: description)
                showCreatePlaylistSheet = false
            },
            onCancel: {
                showCreatePlaylistSheet = false
            }
        )
    }

    // MARK: - Helper Properties

    private var totalDuration: String {
        guard let playlist = playlistManager.currentPlaylist else { return "0:00" }
        return playlist.formattedDuration(clips: playlistManager.enrichedClips)
    }

    // MARK: - Action Handlers

    private func loadPlaylists() {
        guard let projectId = navigationState.currentProject?.id else { return }
        playlistManager.loadPlaylists(projectId: projectId)
    }

    private func loadPlaylist(_ playlist: Playlist) {
        playlistManager.loadEnrichedClips(for: playlist)
        // Auto-select first clip
        if !playlistManager.enrichedClips.isEmpty {
            selectedClipIndex = 0
            playClip(at: 0)
        }
    }

    private func playClip(at index: Int) {
        guard index < playlistManager.enrichedClips.count else { return }

        // Cancel any pending seek
        seekDebounceTask?.cancel()

        // Remove existing observers
        if let observer = clipEndObserver, let player = playerManager.getPlayer(at: playerManager.activePlayerIndex) {
            player.removeTimeObserver(observer)
            clipEndObserver = nil
        }
        if let observer = timeObserver, let player = playerManager.getPlayer(at: playerManager.activePlayerIndex) {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        let clip = playlistManager.enrichedClips[index]

        // Debounce seeks to prevent performance issues
        seekDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            guard !Task.isCancelled else { return }

            // Get the player and preserve volume
            if let player = playerManager.getPlayer(at: playerManager.activePlayerIndex) {
                let currentVolume = player.volume

                // Seek to clip start time
                let startTime = CMTime(value: clip.clip.startTimeMs, timescale: 1000)
                let endTime = CMTime(value: clip.clip.endTimeMs, timescale: 1000)

                playerManager.seek(to: startTime)

                // Restore volume after seek
                player.volume = currentVolume

                // Auto-play the clip
                playerManager.play()

                // Add boundary observer to stop playback at clip end
                clipEndObserver = player.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main) {
                    // Pause playback when clip ends
                    Task { @MainActor in
                        self.playerManager.pause()

                        // If in presentation mode and auto-advance is enabled, go to next clip
                        if self.playlistManager.presentationMode.isEnabled {
                            // Wait a moment before auto-advancing
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            if self.playlistManager.presentationMode.currentClipIndex < self.playlistManager.enrichedClips.count - 1 {
                                self.playlistManager.playNextClip()
                                self.playClip(at: self.playlistManager.presentationMode.currentClipIndex)
                            }
                        }
                    }
                }

                // Add periodic observer to ensure playback doesn't go past clip end
                let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                    // If we've gone past the clip end, pause and seek back
                    if time >= endTime {
                        Task { @MainActor in
                            self.playerManager.pause()
                            player.seek(to: endTime)
                        }
                    }
                }
            }
        }
    }

    private func setupPresentationModeObservers() {
        // Start playing the first clip when entering presentation mode
        if playlistManager.presentationMode.currentClipIndex < playlistManager.enrichedClips.count {
            playClip(at: playlistManager.presentationMode.currentClipIndex)
        }
    }

    private func playNextClip() {
        let currentIndex = selectedClipIndex ?? 0
        let nextIndex = currentIndex + 1
        if nextIndex < playlistManager.enrichedClips.count {
            selectedClipIndex = nextIndex
            playClip(at: nextIndex)
        }
    }

    private func playPreviousClip() {
        let currentIndex = selectedClipIndex ?? 0
        let prevIndex = currentIndex - 1
        if prevIndex >= 0 {
            selectedClipIndex = prevIndex
            playClip(at: prevIndex)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func createNewPlaylist(name: String, purpose: PlaylistPurpose, description: String?) {
        guard let projectId = navigationState.currentProject?.id else { return }
        _ = playlistManager.createPlaylist(
            projectId: projectId,
            name: name,
            purpose: purpose,
            description: description
        )
    }

    private func generateClipsFromFilters(_ filters: PlaylistFilters) {
        guard let projectId = navigationState.currentProject?.id else { return }
        generatedClips = playlistManager.generateClipsFromFilters(
            projectId: projectId,
            filters: filters
        )

        // Apply generated clips to current playlist
        if playlistManager.currentPlaylist != nil {
            playlistManager.setPlaylistClips(generatedClips)
        }
    }

    private func handleNavigationChange(_ item: MainNavItem) {
        Task { @MainActor in
            switch item {
            case .maxView:
                await navigationState.navigate(to: .maxView)
            case .tagging:
                await navigationState.navigate(to: .moments)
            case .playback:
                await navigationState.navigate(to: .playback)
            case .notes:
                await navigationState.navigate(to: .notes)
            case .playlist:
                break
            case .annotation:
                await navigationState.navigate(to: .annotation)
            case .sorter:
                await navigationState.navigate(to: .sorter)
            case .codeWindow:
                await navigationState.navigate(to: .codeWindow)
            case .templates:
                await navigationState.navigate(to: .blueprints)
            case .roster:
                await navigationState.navigate(to: .rosterManagement)
            case .liveCapture:
                await navigationState.navigate(to: .liveCapture)
            }
        }
    }
}

// MARK: - Supporting Views

struct PlaylistRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let playlist: Playlist
    let isSelected: Bool
    let onTap: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: playlist.purpose.icon)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: playlist.purpose.color))

                Text(playlist.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.primaryText)

                Spacer()
            }

            HStack(spacing: 4) {
                Text(playlist.purpose.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)

                Text("·")
                    .foregroundColor(theme.tertiaryText)

                Text("\(playlist.clipIds.count) clips")
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? theme.accent.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct PlaylistClipDetailRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let clip: PlaylistClipWithMetadata
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 12) {
            // Index
            Text("\(index)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? theme.accent : theme.tertiaryText)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.clip.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.primaryText)

                HStack(spacing: 6) {
                    Text(clip.formattedQuarter)
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)

                    Text("·")
                        .foregroundColor(theme.tertiaryText)

                    Text(clip.actionLabel)
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)

                    Text("·")
                        .foregroundColor(theme.tertiaryText)

                    Text(clip.clip.formattedDuration)
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                }
            }

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(theme.error)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? theme.accent.opacity(0.15) : theme.secondaryBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Simple Clip Row (No Expanding Details)

struct PlaylistClipRowWithDetails: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let clip: PlaylistClipWithMetadata
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 12) {
            // Index badge
            Text("\(index)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? Color.white : theme.tertiaryText)
                .frame(width: 28, height: 28)
                .background(isSelected ? theme.accent : theme.secondaryBorder)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(clip.clip.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)

                // Metadata badges row
                HStack(spacing: 6) {
                    // Quarter
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                        Text(clip.formattedQuarter)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(theme.primaryBorder)
                    .cornerRadius(4)

                    // Outcome
                    if let outcome = clip.outcome {
                        HStack(spacing: 3) {
                            Image(systemName: outcome == "Made" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 8))
                            Text(outcome)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(outcome == "Made" ? Color(hex: "5adc8c") : Color(hex: "ff5252"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.primaryBorder)
                        .cornerRadius(4)
                    }

                    // Duration
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 8))
                        Text(clip.clip.formattedDuration)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(theme.primaryBorder)
                    .cornerRadius(4)
                }
            }

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
                    .frame(width: 28, height: 28)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(isSelected ? theme.accent.opacity(0.08) : theme.primaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? theme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Filter Sheet View

struct FilterSheetView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var filters: PlaylistFilters

    let projectId: String?
    let onGenerate: (PlaylistFilters) -> Void
    let onCancel: () -> Void

    @State private var selectedCategories: Set<String> = []
    @State private var selectedLayers: Set<String> = []
    @State private var selectedQuarters: Set<Int> = []
    @State private var selectedOutcomes: Set<String> = []
    @State private var selectedPlayerIds: Set<String> = []
    @State private var availablePlayers: [Player] = []

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Filter Playlist Clips")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(theme.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Players Section
                    if !availablePlayers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Players")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            FlowLayout(spacing: 8) {
                                ForEach(availablePlayers, id: \.id) { player in
                                    Toggle("#\(player.number) \(player.name)", isOn: Binding(
                                        get: { selectedPlayerIds.contains(player.id.uuidString) },
                                        set: { isOn in
                                            if isOn {
                                                selectedPlayerIds.insert(player.id.uuidString)
                                            } else {
                                                selectedPlayerIds.remove(player.id.uuidString)
                                            }
                                        }
                                    ))
                                    .toggleStyle(.button)
                                    .font(.system(size: 11, weight: .medium))
                                }
                            }
                        }
                    }

                    // Moment Categories
                    filterSection(
                        title: "Moment Type",
                        options: ["Offense", "Defense"],
                        selection: $selectedCategories
                    )

                    // Events/Layers
                    filterSection(
                        title: "Event Type",
                        options: ["Shot", "1-Point", "2-Point", "3-Point", "Transition", "Assist"],
                        selection: $selectedLayers
                    )

                    // Outcomes
                    filterSection(
                        title: "Outcome",
                        options: ["Made", "Missed", "Turnover"],
                        selection: $selectedOutcomes
                    )

                    // Quarters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quarter")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        HStack(spacing: 8) {
                            ForEach(1...4, id: \.self) { quarter in
                                Toggle("Q\(quarter)", isOn: Binding(
                                    get: { selectedQuarters.contains(quarter) },
                                    set: { isOn in
                                        if isOn {
                                            selectedQuarters.insert(quarter)
                                        } else {
                                            selectedQuarters.remove(quarter)
                                        }
                                    }
                                ))
                                .toggleStyle(.button)
                                .font(.system(size: 11, weight: .medium))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onAppear {
                loadPlayers()
            }

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: clearFilters) {
                    Text("Clear All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.secondaryBorder)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: applyFilters) {
                    Text("Generate Clips")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 500, height: 600)
        .background(theme.secondaryBackground)
    }

    private func filterSection(title: String, options: [String], selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.primaryText)

            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Toggle(option, isOn: Binding(
                        get: { selection.wrappedValue.contains(option) },
                        set: { isOn in
                            if isOn {
                                selection.wrappedValue.insert(option)
                            } else {
                                selection.wrappedValue.remove(option)
                            }
                        }
                    ))
                    .toggleStyle(.button)
                    .font(.system(size: 11, weight: .medium))
                }
            }
        }
    }

    private func loadPlayers() {
        guard let projectId = projectId else { return }
        availablePlayers = DatabaseManager.shared.getPlayersForProject(projectId: projectId)
    }

    private func clearFilters() {
        selectedCategories.removeAll()
        selectedLayers.removeAll()
        selectedQuarters.removeAll()
        selectedOutcomes.removeAll()
        selectedPlayerIds.removeAll()
    }

    private func applyFilters() {
        var newFilters = PlaylistFilters()
        newFilters.playerIds = selectedPlayerIds.isEmpty ? nil : Array(selectedPlayerIds)
        newFilters.momentCategories = selectedCategories.isEmpty ? nil : Array(selectedCategories)
        newFilters.layerTypes = selectedLayers.isEmpty ? nil : Array(selectedLayers)
        newFilters.quarters = selectedQuarters.isEmpty ? nil : Array(selectedQuarters)
        newFilters.outcomes = selectedOutcomes.isEmpty ? nil : Array(selectedOutcomes)

        onGenerate(newFilters)
    }
}

// MARK: - Create Playlist Sheet

struct CreatePlaylistSheet: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    let onSave: (String, PlaylistPurpose, String?) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var purpose: PlaylistPurpose = .teaching
    @State private var description: String = ""

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Playlist")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(theme.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playlist Name")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    TextField("Enter playlist name", text: $name)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.primaryBackground)
                        .cornerRadius(6)
                }

                // Purpose
                VStack(alignment: .leading, spacing: 8) {
                    Text("Purpose")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    HStack(spacing: 8) {
                        ForEach(PlaylistPurpose.allCases, id: \.self) { p in
                            Button(action: { purpose = p }) {
                                VStack(spacing: 4) {
                                    Image(systemName: p.icon)
                                        .font(.system(size: 14))
                                    Text(p.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(purpose == p ? Color.white : theme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(purpose == p ? theme.accent : theme.secondaryBorder)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (Optional)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    TextEditor(text: $description)
                        .font(.system(size: 13))
                        .frame(height: 80)
                        .padding(8)
                        .background(theme.primaryBackground)
                        .cornerRadius(6)
                }
            }
            .padding(20)

            Spacer()

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.secondaryBorder)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    onSave(name, purpose, description.isEmpty ? nil : description)
                }) {
                    Text("Create")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(name.isEmpty ? theme.tertiaryText : theme.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(name.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 500, height: 500)
        .background(theme.secondaryBackground)
    }
}

#Preview {
    PlaylistView()
        .environmentObject(NavigationState())
        .frame(width: 1440, height: 1062)
}
