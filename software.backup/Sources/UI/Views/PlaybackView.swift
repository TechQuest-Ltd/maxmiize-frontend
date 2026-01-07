//
//  PlaybackView.swift
//  maxmiize-v1
//
//  Playback Review - Multi-angle clip analysis with Figma-matched design
//

import SwiftUI
import AVFoundation

struct PlaybackView: View {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var playerManager = SyncedVideoPlayerManager.shared
    @ObservedObject private var focusManager = VideoPlayerFocusManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @StateObject private var toastManager = ToastManager()

    var theme: ThemeColors {
        themeManager.colors
    }

    // Data state
    @State private var allMoments: [Moment] = []
    @State private var selectedMoment: Moment?
    @State private var selectedClip: Clip?
    @State private var allPlayers: [PlayerInfo] = []
    @State private var allTeams: [Team] = []
    @State private var currentMomentNotes: [Note] = []

    // Filter state
    @State private var filterCategory: String = "All"
    @State private var selectedPlayerForNote: String? = nil
    @State private var selectedTeamForNote: String = "Home"
    @State private var selectedTagLabels: Set<String> = []
    @State private var selectedFilterPlayer: String = "Any player"
    @State private var selectedFilterTags: Set<String> = ["Offense"]
    @State private var searchText: String = ""

    // Note attachments state
    @State private var attachNoteToMoment: Bool = true  // Always attach to moment by default
    @State private var selectedLayerAttachments: Set<String> = []  // Layer IDs to attach note to

    // UI state
    @State private var selectedMainNav: MainNavItem = .playback
    @State private var showSettings: Bool = false
    @State private var editingNotes: String = ""
    @State private var selectedRightTab: RightPanelTab = .notes
    @State private var playbackSpeed: Double = 1.0
    @State private var currentLayout: PlaybackLayout = .default

    // Table sorting state
    @State private var sortColumn: PlaybackTableColumn = .startTime
    @State private var sortAscending: Bool = true
    @State private var notesSortMode: NotesSortMode = .alphabetical

    enum NotesSortMode {
        case alphabetical
        case frequency
    }

    enum PlaybackLayout {
        case `default`  // 3-panel layout
        case table      // Video on top, table below
    }

    enum RightPanelTab: String, CaseIterable {
        case notes = "Notes"
        case labels = "Labels"
        case filters = "Filters"
    }

    // Video player state
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: CMTime = .zero
    @State private var duration: CMTime = .zero
    @State private var keyboardMonitor: Any?  // Store keyboard event monitor to remove it later
    @State private var timeObserver: Any? = nil  // Store observer for cleanup
    @State private var observerPlayer: AVPlayer? = nil  // Track which player has the observer

    // Multi-angle support
    @State private var availableAngles: [String] = []  // All available camera angles
    @State private var selectedAngles: Set<String> = []  // Currently visible angles (can't be empty)
    @State private var anglePlayers: [String: AVPlayer] = [:]  // Player for each angle

    // Notes cache for table view
    @State private var momentNotesCache: [String: [Note]] = [:]  // [momentId: notes]

    private var filteredMoments: [Moment] {
        var filtered = allMoments

        // Filter by category
        if filterCategory != "All" {
            filtered = filtered.filter { $0.momentCategory == filterCategory }
        }

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { moment in
                moment.momentCategory.localizedCaseInsensitiveContains(searchText) ||
                (moment.notes?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                moment.layers.contains { $0.layerType.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return filtered
    }

    private var sessionInfoText: String {
        let isFiltered = filterCategory != "All" || !searchText.isEmpty
        if isFiltered && filteredMoments.count != allMoments.count {
            return "Playback Review • Showing \(filteredMoments.count) of \(allMoments.count) moments"
        } else {
            return "Playback Review • \(allMoments.count) moments"
        }
    }

    private var sortedTableMoments: [Moment] {
        var moments = filteredMoments

        // Apply sorting based on selected column
        moments.sort { moment1, moment2 in
            let ascending = sortAscending

            switch sortColumn {
            case .momentName:
                return ascending ? moment1.momentCategory < moment2.momentCategory : moment1.momentCategory > moment2.momentCategory
            case .startTime:
                return ascending ? moment1.startTimestampMs < moment2.startTimestampMs : moment1.startTimestampMs > moment2.startTimestampMs
            case .duration:
                let dur1 = moment1.duration ?? 0
                let dur2 = moment2.duration ?? 0
                return ascending ? dur1 < dur2 : dur1 > dur2
            case .layers:
                return ascending ? moment1.layers.count < moment2.layers.count : moment1.layers.count > moment2.layers.count
            case .notes:
                // Get note text from cache (Note objects) or fallback to moment.notes field
                let getNoteText = { (moment: Moment) -> String in
                    if let notes = momentNotesCache[moment.id], !notes.isEmpty {
                        return notes.first?.content ?? ""
                    }
                    return moment.notes ?? ""
                }

                if notesSortMode == .frequency {
                    // Sort by frequency of note text
                    let noteFrequencies = Dictionary(grouping: filteredMoments, by: { getNoteText($0) })
                        .mapValues { $0.count }
                    let notes1 = getNoteText(moment1)
                    let notes2 = getNoteText(moment2)
                    let freq1 = noteFrequencies[notes1] ?? 0
                    let freq2 = noteFrequencies[notes2] ?? 0
                    if freq1 != freq2 {
                        return ascending ? freq1 < freq2 : freq1 > freq2
                    }
                    // If same frequency, sort alphabetically
                    return notes1 < notes2
                } else {
                    // Alphabetical sorting
                    let notes1 = getNoteText(moment1)
                    let notes2 = getNoteText(moment2)
                    return ascending ? notes1 < notes2 : notes1 > notes2
                }
            }
        }

        return moments
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

                // Playback Header Controls
                playbackHeaderControls

                // Main content
                GeometryReader { geometry in
                    if currentLayout == .default {
                        // Default 3-panel layout
                        HStack(spacing: 12) {
                            // Left: Event Log
                            eventLogPanel
                                .frame(width: min(max(geometry.size.width * 0.20, 260), 300))

                            // Center: Video Player (two rows)
                            videoPlayerPanel(twoRows: true)
                                .frame(maxWidth: .infinity)

                            // Right: Details
                            detailsPanel
                                .frame(width: min(max(geometry.size.width * 0.25, 320), 380))
                        }
                        .padding(.all, 12)
                    } else {
                        // Table layout - Video on top, table below
                        VStack(spacing: 12) {
                            // Top: Video Player (one row)
                            videoPlayerPanel(twoRows: false)
                                .frame(height: geometry.size.height * 0.5)

                            // Bottom: Moments Table
                            momentsTableView
                        }
                        .padding(.all, 12)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            // Set keyboard focus to main player when this view appears
            focusManager.setFocus(.mainPlayer)

            loadData()
            setupKeyboardShortcuts()
        }
        .onDisappear {
            // Stop ALL players when leaving PlaybackView
            player?.pause()
            isPlaying = false
            for (_, anglePlayer) in anglePlayers {
                anglePlayer.pause()
            }
            print("⏸️ Stopped all players - left PlaybackView")

            // Remove keyboard event monitor
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
                print("🔌 Removed PlaybackView keyboard monitor")
            }

            // Clean up time observer to prevent memory leaks
            // Only remove from the player that the observer was added to
            if let observer = timeObserver, let observerPlayer = observerPlayer {
                observerPlayer.removeTimeObserver(observer)
                timeObserver = nil
                self.observerPlayer = nil
            }
        }
        .toast(manager: toastManager)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            // Pause local player when window loses focus
            player?.pause()
            isPlaying = false
            print("⏸ PlaybackView player paused - window lost focus")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScreenDidChange"))) { _ in
            // Pause local player when navigating away from playback screen
            player?.pause()
            isPlaying = false
            print("⏸ PlaybackView player paused - screen changed")
        }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        // Store the monitor so we can remove it later
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Spacebar - Play/Pause
            if event.keyCode == 49 && !event.modifierFlags.contains(.command) {
                if self.shouldHandleSpacebar() {
                    self.togglePlayPause()
                    print("⏯️ [PlaybackView] Handled spacebar - toggled play/pause")
                    return nil
                } else {
                    print("⚠️ [PlaybackView] Passing spacebar through (modal/popup open or text field focused)")
                }
            }
            return event
        }
        print("🎹 PlaybackView keyboard monitor setup")
    }

    private func shouldHandleSpacebar() -> Bool {
        guard let window = NSApp.keyWindow else {
            print("⚠️ [PlaybackView] No key window")
            return false
        }

        // Check if typing in text field
        if let firstResponder = window.firstResponder {
            if firstResponder is NSTextView ||
               firstResponder is NSTextField ||
               String(describing: type(of: firstResponder)).contains("TextField") ||
               String(describing: type(of: firstResponder)).contains("TextEditor") {
                print("⚠️ [PlaybackView] Text field focused")
                return false
            }
        }

        // Check if this player has keyboard focus (not a popup)
        if !focusManager.shouldHandle(.mainPlayer) {
            print("⚠️ [PlaybackView] Another player has focus (current: \(focusManager.focusedPlayer))")
            return false
        }

        print("✅ [PlaybackView] Has focus - handling spacebar")
        return true
    }

    // MARK: - Playback Header Controls

    private var playbackHeaderControls: some View {
        HStack {
            // Left: Session info
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionInfoText)
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            // Right: Action buttons
            HStack(spacing: 12) {
                // Layout toggle
                Button(action: { toggleLayout() }) {
                    HStack(spacing: 6) {
                        Image(systemName: currentLayout == .default ? "rectangle.split.3x1" : "rectangle.split.2x1")
                            .font(.system(size: 10))
                        Text(currentLayout == .default ? "3-Panel" : "Table")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Toggle Layout")

                // Settings
                Button(action: { showSettings = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gear")
                            .font(.system(size: 10))
                        Text("Settings")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.primaryBackground)
    }

    // MARK: - Event Log Panel

    private var eventLogPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("EVENT LOG")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)

                    TextField("Search moments...", text: $searchText)
                        .font(.system(size: 13))
                        .foregroundColor(theme.primaryText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.surfaceBackground)
                .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Divider()
                .background(theme.secondaryBorder)

            // Moments list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredMoments) { moment in
                        momentRow(moment: moment)
                    }

                    if filteredMoments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "film")
                                .font(.system(size: 40))
                                .foregroundColor(theme.primaryBorder)

                            Text("No moments found")
                                .font(.system(size: 13))
                                .foregroundColor(theme.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
            }
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    private func momentRow(moment: Moment) -> some View {
        Button(action: {
            selectMoment(moment)
        }) {
            HStack(spacing: 10) {
                // Category indicator
                Circle()
                    .fill(colorForCategory(moment.momentCategory))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 4) {
                    Text(moment.momentCategory)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    // Layers
                    if !moment.layers.isEmpty {
                        Text(moment.layers.map { $0.layerType }.joined(separator: " • "))
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "9a9a9a"))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Timestamp
                Text(formatTimestampMs(moment.startTimestampMs))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "666666"))
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(selectedMoment?.id == moment.id ? Color(hex: "2979ff").opacity(0.15) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(selectedMoment?.id == moment.id ? Color(hex: "2979ff") : Color.clear)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity),
                alignment: .leading
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Multi-Angle Video Grid

    private var multiAngleVideoGrid: some View {
        let sortedAngles = selectedAngles.sorted()
        let angleCount = sortedAngles.count

        return GeometryReader { geometry in
            Group {
                if angleCount == 1 {
                    // Single angle - full screen
                    if let angle = sortedAngles.first, let player = anglePlayers[angle] ?? player {
                        videoAngleView(player: player, angle: angle)
                    }
                } else if angleCount == 2 {
                    // Two angles - side by side
                    HStack(spacing: 2) {
                        ForEach(sortedAngles, id: \.self) { angle in
                            if let player = anglePlayers[angle] ?? player {
                                videoAngleView(player: player, angle: angle)
                            }
                        }
                    }
                } else if angleCount == 3 {
                    // Three angles - one on top, two on bottom
                    VStack(spacing: 2) {
                        if let firstAngle = sortedAngles.first,
                           let player = anglePlayers[firstAngle] ?? player {
                            videoAngleView(player: player, angle: firstAngle)
                        }
                        HStack(spacing: 2) {
                            ForEach(sortedAngles.dropFirst(), id: \.self) { angle in
                                if let player = anglePlayers[angle] ?? player {
                                    videoAngleView(player: player, angle: angle)
                                }
                            }
                        }
                    }
                } else {
                    // Four angles - 2x2 grid
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            ForEach(Array(sortedAngles.prefix(2)), id: \.self) { angle in
                                if let player = anglePlayers[angle] ?? player {
                                    videoAngleView(player: player, angle: angle)
                                }
                            }
                        }
                        HStack(spacing: 2) {
                            ForEach(Array(sortedAngles.dropFirst(2)), id: \.self) { angle in
                                if let player = anglePlayers[angle] ?? player {
                                    videoAngleView(player: player, angle: angle)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func videoAngleView(player: AVPlayer, angle: String) -> some View {
        ZStack(alignment: .topLeading) {
            VideoPlayerView(player: player, videoGravity: .resizeAspect)

            // Angle label
            Text(angle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .padding(8)
        }
    }

    // MARK: - Video Player Panel

    private func videoPlayerPanel(twoRows: Bool) -> some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                if let clip = selectedClip {
                    // Video player area - Multi-angle grid
                    ZStack(alignment: .topTrailing) {
                        if !selectedAngles.isEmpty {
                            multiAngleVideoGrid
                        } else {
                            Rectangle()
                                .fill(Color.black)
                        }

                        // Angle selector overlay (top-right corner)
                        if !availableAngles.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(Array(availableAngles.enumerated()), id: \.offset) { index, angle in
                                    Button(action: {
                                        toggleAngle(angle)
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedAngles.contains(angle) ? theme.accent : Color(hex: "333333"))
                                                .frame(width: 20, height: 20)

                                            Text("\(index + 1)")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(theme.primaryText)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(12)
                        }
                    }
                    .frame(maxHeight: .infinity)

                    // Video controls - Rounded container with shadow
                    Group {
                        if twoRows {
                            // Two-row layout for default view
                            VStack(spacing: 12) {
                                // First row: Playback controls + Speed + Timecode
                                HStack(spacing: 20) {
                                    // Left controls - Playback
                                    HStack(spacing: 8) {
                                        controlButton(icon: isPlaying ? "pause.fill" : "play.fill", selected: false) {
                                            togglePlayPause()
                                        }
                                        controlButton(icon: "backward.fill", selected: false) {
                                            seekBy(-0.033)
                                        }
                                        controlButton(icon: "gobackward.5", selected: false) {
                                            seekBy(-5)
                                        }
                                        controlButton(icon: "goforward.5", selected: false) {
                                            seekBy(5)
                                        }
                                        controlButton(icon: "forward.fill", selected: false) {
                                            seekBy(0.033)
                                        }
                                    }

                                    speedControlMenu

                                    Spacer()

                                    timecodeDisplay
                                }

                                // Second row: Moment navigation + Mark In/Out
                                HStack(spacing: 20) {
                                    momentNavigationButtons

                                    Spacer()

                                    markInOutButtons
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                            .background(controlsBackground)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        } else {
                            // Single-row layout for table view
                            HStack(spacing: 20) {
                                // Left controls - Playback
                                HStack(spacing: 8) {
                                    controlButton(icon: isPlaying ? "pause.fill" : "play.fill", selected: false) {
                                        togglePlayPause()
                                    }
                                    controlButton(icon: "backward.fill", selected: false) {
                                        seekBy(-0.033)
                                    }
                                    controlButton(icon: "gobackward.5", selected: false) {
                                        seekBy(-5)
                                    }
                                    controlButton(icon: "goforward.5", selected: false) {
                                        seekBy(5)
                                    }
                                    controlButton(icon: "forward.fill", selected: false) {
                                        seekBy(0.033)
                                    }
                                }

                                speedControlMenu

                                Spacer()

                                momentNavigationButtons

                                Spacer()

                                markInOutButtons

                                timecodeDisplay
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                            .background(controlsBackground)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }

                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "333333"))

                        Text("Select a moment to play")
                            .font(.system(size: 13))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    private func controlButton(icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 26)
                .background(selected ? Color(hex: "202127") : Color(hex: "18191c"))
                .cornerRadius(999)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Reusable Control Components

    private var speedControlMenu: some View {
        Menu {
            Button("0.25×") { playbackSpeed = 0.25 }
            Button("0.5×") { playbackSpeed = 0.5 }
            Button("0.75×") { playbackSpeed = 0.75 }
            Button("1.0×") { playbackSpeed = 1.0 }
            Button("1.5×") { playbackSpeed = 1.5 }
            Button("2.0×") { playbackSpeed = 2.0 }
        } label: {
            HStack(spacing: 6) {
                Text("Speed")
                    .font(.system(size: 12))
                Text("\(String(format: "%.1f", playbackSpeed))×")
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .foregroundColor(theme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(theme.surfaceBackground)
            .cornerRadius(999)
        }
        .buttonStyle(PlainButtonStyle())
        .fixedSize()
        .onChange(of: playbackSpeed) { speed in
            player?.rate = Float(speed)
        }
    }

    private var timecodeDisplay: some View {
        Text(formatTimecode(currentTime))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(theme.primaryText)
            .monospacedDigit()
            .fixedSize()
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(theme.surfaceBackground.opacity(0.6))
            .cornerRadius(999)
    }

    private var momentNavigationButtons: some View {
        HStack(spacing: 10) {
            // Prev Moment
            Button(action: { goToPreviousMoment() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10))
                    Text("Prev Moment")
                        .font(.system(size: 13))
                        .fixedSize()
                }
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(theme.surfaceBackground)
                .cornerRadius(999)
            }
            .buttonStyle(PlainButtonStyle())
            .fixedSize()

            // Next Moment
            Button(action: { goToNextMoment() }) {
                HStack(spacing: 6) {
                    Text("Next Moment")
                        .font(.system(size: 13))
                        .fixedSize()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                }
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(theme.surfaceBackground)
                .cornerRadius(999)
            }
            .buttonStyle(PlainButtonStyle())
            .fixedSize()
        }
    }

    private var markInOutButtons: some View {
        HStack(spacing: 10) {
            Button(action: {}) {
                Text("Mark In")
                    .font(.system(size: 13))
                    .fixedSize()
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(theme.surfaceBackground)
                    .cornerRadius(999)
            }
            .buttonStyle(PlainButtonStyle())
            .fixedSize()

            Button(action: {}) {
                Text("Mark Out")
                    .font(.system(size: 13))
                    .fixedSize()
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(theme.surfaceBackground)
                    .cornerRadius(999)
            }
            .buttonStyle(PlainButtonStyle())
            .fixedSize()
        }
    }

    private var controlsBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(theme.secondaryBorder.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.9), radius: 26, x: 0, y: 26)
    }

    // MARK: - Details Panel

    private var detailsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Tab selector with rounded pill design
            HStack(spacing: 0) {
                HStack(spacing: 3) {
                    ForEach(RightPanelTab.allCases, id: \.self) { tab in
                        Button(action: {
                            selectedRightTab = tab
                        }) {
                            Text(tab.rawValue)
                                .font(.system(size: 11))
                                .foregroundColor(selectedRightTab == tab ? .white : theme.secondaryText)
                                .padding(.horizontal, 0)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(selectedRightTab == tab ? theme.accent : Color.clear)
                                .cornerRadius(999)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(3)
                .background(theme.surfaceBackground)
                .cornerRadius(999)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)

            // Tab content
            ScrollView {
                if let moment = selectedMoment {
                    VStack(alignment: .leading, spacing: 8) {
                        // Tab content based on selection
                        Group {
                            switch selectedRightTab {
                            case .notes:
                                notesTabContent(moment: moment)
                            case .labels:
                                labelsTabContent(moment: moment)
                            case .filters:
                                filtersTabContent()
                            }
                        }
                    }
                    .padding(10)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 40))
                            .foregroundColor(theme.primaryBorder)

                        Text("No moment selected")
                            .font(.system(size: 13))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                }
            }
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Moments Table View

    private var momentsTableView: some View {
        VStack(spacing: 0) {
            // Table header with search
            HStack {
                Text("Moments")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)

                    TextField("Search moments...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                        .foregroundColor(theme.primaryText)
                        .frame(width: 200)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.surfaceBackground)
                .cornerRadius(6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(theme.secondaryBorder)

            // Table
            ScrollView {
                VStack(spacing: 0) {
                    // Table header
                    tableHeaderRow
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(theme.surfaceBackground)

                    // Table rows
                    ForEach(sortedTableMoments) { moment in
                        tableRow(moment: moment)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedMoment?.id == moment.id ? theme.accent.opacity(0.15) : Color.clear)
                            .onTapGesture {
                                selectMoment(moment)
                            }

                        Divider()
                            .background(theme.secondaryBorder)
                    }

                    if sortedTableMoments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "film")
                                .font(.system(size: 40))
                                .foregroundColor(theme.primaryBorder)

                            Text("No moments found")
                                .font(.system(size: 13))
                                .foregroundColor(theme.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
            }
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    private var tableHeaderRow: some View {
        HStack(spacing: 16) {
            // Moment column - width accounts for circle (8) + spacing (8) in rows
            HStack(spacing: 4) {
                sortableTableHeader(.momentName, title: "Moment", width: nil)
            }
            .frame(width: 150, alignment: .leading)

            sortableTableHeader(.startTime, title: "Start Time", width: 100)
            sortableTableHeader(.duration, title: "Duration", width: 80)
            sortableTableHeader(.layers, title: "Layers", width: 100)

            // Notes column with sort mode menu
            notesColumnHeader
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Actions")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "9a9a9a"))
                .frame(width: 60, alignment: .center)
        }
    }

    private var notesColumnHeader: some View {
        HStack(spacing: 4) {
            Button(action: {
                if sortColumn == .notes {
                    sortAscending.toggle()
                } else {
                    sortColumn = .notes
                    sortAscending = true
                }
            }) {
                HStack(spacing: 4) {
                    Text("Notes")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "9a9a9a"))

                    if sortColumn == .notes {
                        Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(Color(hex: "2979ff"))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Sort mode indicator/toggle
            Menu {
                Button(action: { notesSortMode = .alphabetical }) {
                    HStack {
                        Text("Alphabetical")
                        if notesSortMode == .alphabetical {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: { notesSortMode = .frequency }) {
                    HStack {
                        Text("Frequency")
                        if notesSortMode == .frequency {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text("(\(notesSortMode == .alphabetical ? "A-Z" : "Freq"))")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "666666"))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7))
                        .foregroundColor(Color(hex: "666666"))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func sortableTableHeader(_ column: PlaybackTableColumn, title: String, width: CGFloat?) -> some View {
        Button(action: {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = true
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "9a9a9a"))

                if sortColumn == column {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "2979ff"))
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func tableRow(moment: Moment) -> some View {
        HStack(spacing: 16) {
            // Moment name with color indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(colorForCategory(moment.momentCategory))
                    .frame(width: 8, height: 8)

                Text(moment.momentCategory)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .frame(width: 150, alignment: .leading)

            // Start time
            Text(formatTimestampMs(moment.startTimestampMs))
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "d0d0d3"))
                .monospacedDigit()
                .frame(width: 100, alignment: .leading)

            // Duration
            if let duration = moment.duration {
                Text(formatDurationSeconds(duration))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "d0d0d3"))
                    .monospacedDigit()
                    .frame(width: 80, alignment: .leading)
            } else {
                Text("Active")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "ffd24c"))
                    .frame(width: 80, alignment: .leading)
            }

            // Layers
            if moment.layers.isEmpty {
                Text("-")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "666666"))
                    .frame(width: 100, alignment: .leading)
            } else {
                Text(moment.layers.map { $0.layerType }.joined(separator: ", "))
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "9a9a9a"))
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
            }

            // Notes - show first note from notes array or moment.notes field
            Button(action: {
                selectMoment(moment)
            }) {
                HStack(spacing: 4) {
                    if let notes = momentNotesCache[moment.id], !notes.isEmpty {
                        // Show first note with count badge
                        Text(notes.first?.content ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "9a9a9a"))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        if notes.count > 1 {
                            Text("(\(notes.count))")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.accent)
                        }
                    } else if let noteText = moment.notes, !noteText.isEmpty {
                        // Fallback to moment.notes field
                        Text(noteText)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "9a9a9a"))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text("-")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "666666"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Click to view notes")

            // Actions
            Button(action: {
                selectMoment(moment)
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "2979ff"))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Play moment")
            .frame(width: 60, alignment: .center)
        }
    }

    private func formatDurationSeconds(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Tab Content Views

    private func notesTabContent(moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Info card with rounded corners and shadow
            VStack(alignment: .leading, spacing: 6) {
                // Current Selection header
                HStack {
                    Text("Current Selection")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "e4e4e6"))

                    Spacer()

                    Text("Linked to tag at \(formatTimestampMs(moment.startTimestampMs))")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))
                }

                // Player dropdown
                HStack {
                    Text("Player")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))

                    Spacer()

                    Text("Required")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))
                }
                .padding(.top, 2)

                // Player selection dropdown
                Menu {
                    ForEach(allPlayers, id: \.id) { player in
                        Button("\(player.firstName) \(player.lastName) · #\(player.jerseyNumber)") {
                            selectedPlayerForNote = player.id
                        }
                    }
                } label: {
                    HStack {
                        if let playerId = selectedPlayerForNote,
                           let player = allPlayers.first(where: { $0.id == playerId }) {
                            Text("\(player.firstName) \(player.lastName) · #\(player.jerseyNumber)")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "dadadd"))
                        } else {
                            Text("Select player")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "dadadd"))
                        }

                        Spacer()

                        Text("▾")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "dadadd"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: "18191d"))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)

                // Team label
                Text("Team")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "85868a"))

                // Team selection dropdown
                Menu {
                    ForEach(allTeams, id: \.id) { team in
                        Button(team.name) {
                            selectedTeamForNote = team.id
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedTeamForNote)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "dadadd"))

                        Spacer()

                        Text("▾")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "dadadd"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: "18191d"))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)

                // Tag Labels section
                HStack {
                    Text("Tag Labels")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))

                    Spacer()

                    Text("Multiple")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "9fa0a4"))
                }
                .padding(.top, 2)

                // Tag labels as pills
                let allTagOptions = ["Press Trigger", "Final Third", "Shot", "Transition"]
                FlowLayout(spacing: 6) {
                    ForEach(allTagOptions, id: \.self) { tag in
                        Button(action: {
                            if selectedTagLabels.contains(tag) {
                                selectedTagLabels.remove(tag)
                            } else {
                                selectedTagLabels.insert(tag)
                            }
                        }) {
                            Text(tag)
                                .font(.system(size: 11))
                                .foregroundColor(selectedTagLabels.contains(tag) ? Color(hex: "e4ecff") : Color(hex: "cbcbd0"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(selectedTagLabels.contains(tag) ? Color(hex: "2979ff").opacity(0.22) : Color(hex: "202127"))
                                .cornerRadius(999)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 2)

                // Notes section header
                HStack {
                    Text("Notes")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))

                    Spacer()

                    HStack(spacing: 2) {
                        Text("⌘Enter")
                            .font(.system(size: 11))
                        Text("·")
                            .font(.system(size: 11))
                        Text("Save")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color(hex: "85868a"))
                }
                .padding(.top, 4)

                // Checkboxes for note attachments
                VStack(alignment: .leading, spacing: 6) {
                    // Always show "Moment" checkbox (checked by default)
                    HStack(spacing: 6) {
                        Button(action: {
                            attachNoteToMoment.toggle()
                        }) {
                            ZStack {
                                Rectangle()
                                    .fill(attachNoteToMoment ? Color(hex: "2979ff") : Color(hex: "0f1316"))
                                    .frame(width: 14, height: 14)
                                    .cornerRadius(4)

                                if attachNoteToMoment {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        Text("Moment")
                            .font(.system(size: 12, weight: .thin))
                            .foregroundColor(Color(hex: "e3eef6"))
                    }

                    // Show layer checkboxes if moment has layers
                    if let moment = selectedMoment, !moment.layers.isEmpty {
                        ForEach(moment.layers) { layer in
                            HStack(spacing: 6) {
                                Button(action: {
                                    if selectedLayerAttachments.contains(layer.id) {
                                        selectedLayerAttachments.remove(layer.id)
                                    } else {
                                        selectedLayerAttachments.insert(layer.id)
                                    }
                                }) {
                                    ZStack {
                                        Rectangle()
                                            .fill(selectedLayerAttachments.contains(layer.id) ? Color(hex: "2979ff") : Color(hex: "0f1316"))
                                            .frame(width: 14, height: 14)
                                            .cornerRadius(4)

                                        if selectedLayerAttachments.contains(layer.id) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())

                                Text(layer.layerType)
                                    .font(.system(size: 12, weight: .thin))
                                    .foregroundColor(Color(hex: "e3eef6"))
                            }
                        }
                    }
                }

                // Notes text area
                TextEditor(text: $editingNotes)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "c5c6cc"))
                    .frame(height: 90)
                    .padding(8)
                    .background(Color(hex: "242632"))
                    .cornerRadius(10)
                    .overlay(
                        Group {
                            if editingNotes.isEmpty {
                                VStack(alignment: .leading) {
                                    Text("Quickly describe context, decision, and\noutcome for this moment…")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "c5c6cc").opacity(0.5))
                                        .padding(.horizontal, 12)
                                        .padding(.top, 14)
                                    Spacer()
                                }
                            }
                        }
                    )
                    .onAppear {
                        editingNotes = moment.notes ?? ""
                    }
                .padding(.top, 2)

                // Action buttons
                HStack(spacing: 6) {
                    // Save & Add to Playlist (bordered button)
                    Button(action: {
                        saveAndAddToPlaylist(moment: moment)
                    }) {
                        Text("Save & Add to Playlist")
                            .font(.system(size: 13, weight: .thin))
                            .foregroundColor(Color(hex: "2f7bff"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "2f7bff"), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Save Note (filled button)
                    Button(action: {
                        saveNote(moment: moment)
                    }) {
                        Text("Save")
                            .font(.system(size: 13, weight: .thin))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(hex: "2f7bff"))
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)

                // Notes list section
                if !currentMomentNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("SAVED NOTES (\(currentMomentNotes.count))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "85868a"))
                                .tracking(0.5)

                            Spacer()
                        }
                        .padding(.top, 12)

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(currentMomentNotes) { note in
                                    noteCard(note: note)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(8)
            .background(Color(hex: "1a1b1d"))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.7), radius: 8, x: 0, y: 8)

            // Footer with profile info
            HStack {
                Text("Profile: Playback Analyst")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "77787d"))

                Spacer()

                Text("⌥⌘N · New Note")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "77787d"))
            }
            .padding(.top, 2)
        }
    }

    private func labelsTabContent(moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Info card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Current Selection")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "e4e4e6"))

                    Spacer()

                    Text("Linked to tag at \(formatTimestampMs(moment.startTimestampMs))")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))
                }

                Text("LAYERS (\(moment.layers.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "85868a"))
                    .tracking(0.5)
                    .padding(.top, 8)

                if moment.layers.isEmpty {
                    Text("No layers attached")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "666666"))
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(moment.layers.enumerated()), id: \.element.id) { index, layer in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: "2979ff"))
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(layer.layerType)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)

                                    if let timestamp = layer.timestampMs {
                                        Text(formatTimestampMs(timestamp))
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: "666666"))
                                            .monospacedDigit()
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)

                            if index < moment.layers.count - 1 {
                                Divider()
                                    .background(Color(hex: "333333"))
                            }
                        }
                    }
                    .background(Color(hex: "18191d"))
                    .cornerRadius(8)
                }
            }
            .padding(8)
            .background(Color(hex: "1a1b1d"))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.7), radius: 8, x: 0, y: 8)
        }
    }

    private func filtersTabContent() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Filters card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Filters")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "e4e4e6"))

                    Spacer()

                    Text("Affect timeline + log")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))
                }

                // Player filter
                HStack {
                    Text("Player")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))

                    Spacer()

                    Text("All")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "9fa0a4"))
                }
                .padding(.top, 2)

                Menu {
                    Button("Any player") { selectedFilterPlayer = "Any player" }
                    ForEach(allPlayers, id: \.id) { player in
                        Button("\(player.firstName) \(player.lastName) · #\(player.jerseyNumber)") {
                            selectedFilterPlayer = "\(player.firstName) \(player.lastName)"
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedFilterPlayer)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "dadadd"))

                        Spacer()

                        Text("▾")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "dadadd"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(hex: "18191d"))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 2)

                // Tag Type filter
                HStack {
                    Text("Tag Type")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "85868a"))

                    Spacer()

                    Text("Multi-select")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "9fa0a4"))
                }
                .padding(.top, 2)

                // Tag type pills
                FlowLayout(spacing: 6) {
                    ForEach(["Offense", "Defense", "Transition", "Set Pieces"], id: \.self) { tagType in
                        Button(action: {
                            if selectedFilterTags.contains(tagType) {
                                selectedFilterTags.remove(tagType)
                            } else {
                                selectedFilterTags.insert(tagType)
                            }
                        }) {
                            Text(tagType)
                                .font(.system(size: 11))
                                .foregroundColor(selectedFilterTags.contains(tagType) ? Color(hex: "e4ecff") : Color(hex: "cbcbd0"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(selectedFilterTags.contains(tagType) ? Color(hex: "2979ff").opacity(0.22) : Color(hex: "202127"))
                                .cornerRadius(999)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 2)
            }
            .padding(8)
            .background(Color(hex: "1a1b1d"))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.7), radius: 8, x: 0, y: 8)

            // Footer
            HStack {
                Text("Profile: Playback Analyst")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "77787d"))

                Spacer()

                Text("⌥⌘N · New Note")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "77787d"))
            }
            .padding(.top, 2)

            Spacer()
        }
    }

    // MARK: - Helper Functions

    private func loadData() {
        guard let project = navigationState.currentProject else { return }

        // Load moments
        if let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) {
            allMoments = DatabaseManager.shared.getMoments(gameId: gameId)

            // Load notes for all moments to display in table
            loadNotesCache(gameId: gameId)

            // Auto-select first moment by default if none selected
            if selectedMoment == nil, let firstMoment = allMoments.first {
                selectMoment(firstMoment)
                print("📌 Auto-selected first moment: \(firstMoment.momentCategory)")
            }
        }

        // Load teams
        allTeams = GlobalTeamsManager.shared.getTeams()

        // Load players from teams
        for team in allTeams {
            let teamPlayers = GlobalTeamsManager.shared.getPlayers(teamId: team.id)
            allPlayers.append(contentsOf: teamPlayers)
        }

        // Set default tag labels
        selectedTagLabels = Set(["Press Trigger"])

        print("📊 Loaded \(allMoments.count) moments, \(allPlayers.count) players, \(allTeams.count) teams")
    }

    private func loadNotesCache(gameId: String) {
        // Clear existing cache
        momentNotesCache.removeAll()

        // Load notes for each moment
        for moment in allMoments {
            let notes = DatabaseManager.shared.getNotes(momentId: moment.id, gameId: gameId)
            if !notes.isEmpty {
                momentNotesCache[moment.id] = notes
            }
        }

        print("📝 Loaded notes for \(momentNotesCache.count) moments")
    }

    private func selectMoment(_ moment: Moment) {
        // Pause current playback before switching
        player?.pause()
        isPlaying = false

        selectedMoment = moment
        editingNotes = moment.notes ?? ""

        // Find or create clip for this moment
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id),
              let endMs = moment.endTimestampMs else {
            return
        }

        // Load notes for this moment
        currentMomentNotes = DatabaseManager.shared.getNotes(momentId: moment.id, gameId: gameId)

        // Try to find existing clip
        let clips = DatabaseManager.shared.getClips(gameId: gameId)
        if let clip = clips.first(where: { $0.startTimeMs == moment.startTimestampMs && $0.endTimeMs == endMs }) {
            selectedClip = clip
            loadClipVideo(clip)
        }
    }

    private func loadClipVideo(_ clip: Clip) {
        guard let project = navigationState.currentProject,
              let bundle = ProjectManager.shared.currentProject else {
            return
        }

        let videos = DatabaseManager.shared.getVideos(projectId: project.id)
        guard let video = videos.first else {
            return
        }

        let fileName = video.filePath.replacingOccurrences(of: "videos/", with: "")
        let videoURL = bundle.videosPath.appendingPathComponent(fileName)

        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)

        // Reuse existing player or create new one
        if player == nil {
            player = AVPlayer(playerItem: playerItem)

            // Enable audio for main player (will be the only one with audio in multi-angle view)
            player?.volume = 1

            // Add time observer only once when player is created
            let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
            timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                guard let clip = self.selectedClip else { return }
                let startTime = CMTime(seconds: Double(clip.startTimeMs) / 1000.0, preferredTimescale: 600)
                let relativeTime = CMTimeSubtract(time, startTime)
                self.currentTime = max(.zero, relativeTime)
            }
            // Store which player the observer was added to
            observerPlayer = player
        } else {
            // Pause before replacing to prevent background audio
            player?.pause()
            // Replace the player item in existing player
            player?.replaceCurrentItem(with: playerItem)
            // Ensure audio is enabled for main player
            player?.volume = 1
        }

        // Ensure playback is stopped when loading new clip
        isPlaying = false
        player?.pause()

        let startTime = CMTime(seconds: Double(clip.startTimeMs) / 1000.0, preferredTimescale: 600)
        player?.seek(to: startTime)

        duration = CMTime(seconds: Double(clip.endTimeMs - clip.startTimeMs) / 1000.0, preferredTimescale: 600)
        currentTime = .zero

        // Load available angles for multi-angle view
        loadAvailableAngles()
    }

    private func loadAvailableAngles() {
        guard let project = navigationState.currentProject else { return }

        let videos = DatabaseManager.shared.getVideos(projectId: project.id)
        availableAngles = videos.map { $0.cameraAngle }

        // Select first angle by default if none selected
        if selectedAngles.isEmpty, let firstAngle = availableAngles.first {
            selectedAngles.insert(firstAngle)
        }

        // Load videos for selected angles
        if let clip = selectedClip {
            loadMultiAngleVideos(clip)
        }
    }

    private func loadMultiAngleVideos(_ clip: Clip, syncToCurrentTime: Bool = false) {
        guard let project = navigationState.currentProject,
              let bundle = ProjectManager.shared.currentProject else {
            return
        }

        let videos = DatabaseManager.shared.getVideos(projectId: project.id)
        let sortedAngles = selectedAngles.sorted()
        let isMultiAngleView = selectedAngles.count > 1
        let clipStartTime = CMTime(seconds: Double(clip.startTimeMs) / 1000.0, preferredTimescale: 600)

        // Get current playback time from main player if syncing to current time
        let seekTime: CMTime
        if syncToCurrentTime, let mainPlayer = player {
            seekTime = mainPlayer.currentTime()
            print("🔄 Syncing new angles to current playback time: \(CMTimeGetSeconds(seekTime))s")
        } else {
            seekTime = clipStartTime
        }

        // Create player for EACH selected angle (including the first one)
        for (index, angle) in sortedAngles.enumerated() {
            // Check if player already exists for this angle
            if let existingPlayer = anglePlayers[angle] {
                // Player exists - only seek if not syncing to current time (already at correct position)
                if !syncToCurrentTime {
                    existingPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    print("🔄 Seeked existing angle '\(angle)' to \(clip.startTimeMs)ms")
                }

                // Update audio settings
                if isMultiAngleView && index > 0 {
                    existingPlayer.volume = 0
                } else {
                    existingPlayer.volume = 1
                }

                continue
            }

            // Player doesn't exist - create new one
            guard let video = videos.first(where: { $0.cameraAngle == angle }) else {
                continue
            }

            let fileName = video.filePath.replacingOccurrences(of: "videos/", with: "")
            let videoURL = bundle.videosPath.appendingPathComponent(fileName)

            let asset = AVAsset(url: videoURL)
            let playerItem = AVPlayerItem(asset: asset)
            let anglePlayer = AVPlayer(playerItem: playerItem)
            anglePlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)

            // IMPORTANT: Mute all players except the first one to avoid audio chaos
            if isMultiAngleView && index > 0 {
                anglePlayer.volume = 0
                print("🔇 Muted angle '\(angle)' (multi-angle view)")
            } else {
                anglePlayer.volume = 1
                print("🔊 Audio enabled for angle '\(angle)'")
            }

            // If syncing to current time and main player is playing, start this player too
            if syncToCurrentTime && isPlaying {
                anglePlayer.play()
                anglePlayer.rate = Float(playbackSpeed)
                print("▶️ Started playback for new angle '\(angle)'")
            }

            anglePlayers[angle] = anglePlayer

            print("✅ Loaded angle '\(angle)': \(videoURL.lastPathComponent)")
        }

        // Update main player reference to first angle
        if let firstAngle = sortedAngles.first {
            player = anglePlayers[firstAngle]
        }

        // Remove players for deselected angles
        let deselectedAngles = Set(anglePlayers.keys).subtracting(selectedAngles)
        for angle in deselectedAngles {
            anglePlayers[angle]?.pause()
            anglePlayers.removeValue(forKey: angle)
            print("🗑️ Removed player for angle '\(angle)'")
        }

        print("✅ Active angles: \(anglePlayers.count)")
    }

    private func togglePlayPause() {
        if isPlaying {
            // Pause all angle players
            player?.pause()
            for (_, anglePlayer) in anglePlayers {
                anglePlayer.pause()
            }
        } else {
            // Sync all players to main player's time before playing
            if let mainPlayer = player {
                let currentTime = mainPlayer.currentTime()
                for (_, anglePlayer) in anglePlayers {
                    // Only sync if player is not the main player
                    if anglePlayer !== mainPlayer {
                        anglePlayer.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                }
            }

            // Play all angle players
            player?.play()
            player?.rate = Float(playbackSpeed)
            for (_, anglePlayer) in anglePlayers {
                anglePlayer.play()
                anglePlayer.rate = Float(playbackSpeed)
            }
        }
        isPlaying.toggle()
    }

    private func seekBy(_ seconds: Double) {
        guard let player = player else { return }
        let targetTime = CMTimeAdd(player.currentTime(), CMTime(seconds: seconds, preferredTimescale: 600))
        player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)

        // Seek all angle players to the same precise time
        for (_, anglePlayer) in anglePlayers {
            anglePlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    private func goToPreviousMoment() {
        guard let current = selectedMoment,
              let index = allMoments.firstIndex(where: { $0.id == current.id }),
              index > 0 else { return }
        selectMoment(allMoments[index - 1])
    }

    private func goToNextMoment() {
        guard let current = selectedMoment,
              let index = allMoments.firstIndex(where: { $0.id == current.id }),
              index < allMoments.count - 1 else { return }
        selectMoment(allMoments[index + 1])
    }

    private func toggleAngle(_ angle: String) {
        if selectedAngles.contains(angle) {
            // Don't allow deselecting if it's the only one selected
            guard selectedAngles.count > 1 else {
                toastManager.show(message: "At least one angle must be selected", icon: "exclamationmark.triangle.fill", backgroundColor: "ff5252")
                return
            }
            selectedAngles.remove(angle)
            print("🎥 Deselected angle: \(angle). Active angles: \(selectedAngles.count)")
        } else {
            selectedAngles.insert(angle)
            print("🎥 Selected angle: \(angle). Active angles: \(selectedAngles.count)")
        }

        // Reload videos for selected angles, syncing to current playback position
        if let clip = selectedClip {
            loadMultiAngleVideos(clip, syncToCurrentTime: true)
        }
    }

    private func saveNote(moment: Moment) {
        // Build attachments array based on selections
        var attachments: [NoteAttachment] = []

        // Add moment attachment if selected
        if attachNoteToMoment {
            attachments.append(NoteAttachment(type: .moment, id: moment.id))
        }

        // Add layer attachments if selected
        for layerId in selectedLayerAttachments {
            attachments.append(NoteAttachment(type: .layer, id: layerId))
        }

        // Add player attachment if selected
        if let playerId = selectedPlayerForNote {
            attachments.append(NoteAttachment(type: .player, id: playerId))
        }

        // Must have either note text OR at least one attachment
        if editingNotes.isEmpty && attachments.isEmpty {
            toastManager.show(message: "Add note text or select an attachment", icon: "exclamationmark.circle.fill", backgroundColor: "ff5252")
            return
        }

        // Save note to database
        let result = DatabaseManager.shared.createNote(
            momentId: moment.id,
            gameId: moment.gameId,
            content: editingNotes,
            attachedTo: attachments,
            playerId: selectedPlayerForNote
        )

        switch result {
        case .success(let noteId):
            print("📝 Note saved with ID: \(noteId)")

            // IMPORTANT: Also update the moment's notes field so it shows in table
            let updateResult = DatabaseManager.shared.updateMomentNotes(momentId: moment.id, notes: editingNotes)
            switch updateResult {
            case .success:
                // Reload moments to reflect updated notes in table
                if let project = navigationState.currentProject,
                   let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) {
                    allMoments = DatabaseManager.shared.getMoments(gameId: gameId)
                    // Refresh notes cache
                    loadNotesCache(gameId: gameId)
                    // Update selectedMoment to point to refreshed data
                    if let updatedMoment = allMoments.first(where: { $0.id == moment.id }) {
                        selectedMoment = updatedMoment
                    }
                }
                print("📝 Updated moment notes field for table display")
            case .failure(let error):
                print("⚠️ Failed to update moment notes: \(error)")
            }

            toastManager.show(message: "Note saved", icon: "checkmark.circle.fill", backgroundColor: "2979ff")

            // Reload notes list
            currentMomentNotes = DatabaseManager.shared.getNotes(momentId: moment.id, gameId: moment.gameId)

            // Clear the form
            editingNotes = ""
            selectedLayerAttachments.removeAll()
            attachNoteToMoment = true
            selectedPlayerForNote = nil

        case .failure(let error):
            print("❌ Failed to save note: \(error)")
            toastManager.show(message: "Failed to save note", icon: "exclamationmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func saveAndAddToPlaylist(moment: Moment) {
        saveNote(moment: moment)
        toastManager.show(message: "Saved & added to playlist", icon: "checkmark.circle.fill", backgroundColor: "2979ff")
    }

    private func formatTimecode(_ time: CMTime) -> String {
        let totalSeconds = Int(time.seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let frames = Int((time.seconds - Double(totalSeconds)) * 30) // 30fps
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    private func formatTimestampMs(_ ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "offense": return Color(hex: "5adc8c")
        case "defense": return Color(hex: "ff5252")
        case "transition": return Color(hex: "ffd24c")
        default: return Color(hex: "2979ff")
        }
    }

    private func noteCard(note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Note header with timestamp and attachments
            HStack(spacing: 6) {
                // Timestamp
                Text(formatDate(note.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "85868a"))
                    .monospacedDigit()

                // Attachment badges
                ForEach(note.attachedTo, id: \.id) { attachment in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(attachmentColor(attachment.type))
                            .frame(width: 6, height: 6)

                        Text(attachmentLabel(attachment))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "85868a"))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "202127"))
                    .cornerRadius(8)
                }

                Spacer()

                // Delete button
                Button(action: {
                    deleteNote(note)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "ff5252").opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Note content
            Text(note.content)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "dadadd"))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color(hex: "18191d"))
        .cornerRadius(10)
    }

    private func attachmentColor(_ type: NoteAttachmentType) -> Color {
        switch type {
        case .moment: return Color(hex: "2979ff")
        case .layer: return Color(hex: "ffd24c")
        case .player: return Color(hex: "5adc8c")
        }
    }

    private func attachmentLabel(_ attachment: NoteAttachment) -> String {
        switch attachment.type {
        case .moment:
            return "Moment"
        case .layer:
            // Try to find the layer name
            if let moment = selectedMoment,
               let layer = moment.layers.first(where: { $0.id == attachment.id }) {
                return layer.layerType
            }
            return "Layer"
        case .player:
            // Try to find the player name
            if let player = allPlayers.first(where: { $0.id == attachment.id }) {
                return "#\(player.jerseyNumber)"
            }
            return "Player"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }

    private func deleteNote(_ note: Note) {
        let success = DatabaseManager.shared.deleteNote(noteId: note.id)
        if success {
            // Reload notes list
            if let moment = selectedMoment {
                currentMomentNotes = DatabaseManager.shared.getNotes(momentId: moment.id, gameId: moment.gameId)
            }
            toastManager.show(message: "Note deleted", icon: "trash.fill", backgroundColor: "ff5252")
        } else {
            toastManager.show(message: "Failed to delete note", icon: "exclamationmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func toggleLayout() {
        currentLayout = currentLayout == .default ? .table : .default
        print("🎛️ Layout toggled to: \(currentLayout == .default ? "Default" : "Table")")
    }

    private func handleNavigationChange(_ item: MainNavItem) {
        Task { @MainActor in
            switch item {
            case .maxView:
                await navigationState.navigate(to: .maxView)
            case .tagging:
                await navigationState.navigate(to: .moments)
            case .playback:
                break
            case .notes:
                await navigationState.navigate(to: .notes)
            case .playlist:
                await navigationState.navigate(to: .playlist)
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

// MARK: - Supporting Types

enum PlaybackTableColumn {
    case momentName
    case startTime
    case duration
    case layers
    case notes
}

#Preview {
    PlaybackView()
        .environmentObject(NavigationState())
}
