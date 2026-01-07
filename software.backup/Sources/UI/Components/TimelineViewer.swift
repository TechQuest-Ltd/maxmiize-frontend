//
//  TimelineViewer.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import SwiftUI
import AVFoundation

struct TimelineSegment: Identifiable {
    let id = UUID()
    let startTime: Double // in seconds
    let endTime: Double
    let color: Color
    let momentId: String? // Link to tag for selection
    let momentName: String? // Name of the moment for tooltip
    var lane: Int = 0 // Vertical lane for overlapping segments
}

struct TimelineMarker: Identifiable {
    let id = UUID()
    let time: Double // in seconds
    let color: Color
    let momentId: String? // Link to tag for jumping
    let eventType: String? // For tooltip/debugging
}

struct TimelineTrack {
    let name: String
    let segments: [TimelineSegment]
    let markers: [TimelineMarker]
}

struct TimelineViewer: View {
    @EnvironmentObject var navigationState: NavigationState
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var timelineState = TimelineStateManager.shared
    @ObservedObject private var playerManager = SyncedVideoPlayerManager.shared
    @State private var tracks: [TimelineTrack] = []
    @State private var clips: [Clip] = []
    @State private var currentClipIndex: Int = 0
    @State private var totalDuration: Double = 2700 // Duration in seconds, updated from video length

    // Hover tooltip state
    @State private var hoveredSegment: TimelineSegment? = nil
    @State private var tooltipPosition: CGPoint = .zero
    @State private var showTooltip: Bool = false

    // Synchronized scrolling state
    @State private var scrollOffset: CGFloat = 0

    // Row selection for filtered clip navigation
    @State private var selectedTrackName: String? = nil

    let startTime: String = "00:00:00:00"

    // Calculate visible duration based on zoom level
    // zoomLevel 0 = show full duration, zoomLevel 1 = show 2% of duration (50x zoom)
    private var visibleDuration: Double {
        let minVisibleRatio = 0.02 // At max zoom, show 2% of timeline (50x magnification)
        let maxVisibleRatio = 1.0   // At min zoom, show 100% of timeline
        let ratio = maxVisibleRatio - (timelineState.zoomLevel * (maxVisibleRatio - minVisibleRatio))
        return totalDuration * ratio
    }
    var endTime: String {
        formatTimeMs(Int64(totalDuration * 1000))
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            timelineHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // Timeline area with time markers and playhead overlay
            GeometryReader { timelineGeometry in
                ZStack(alignment: .topLeading) {
                    // Single ScrollView for both time markers and tracks to sync horizontal scrolling
                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            // Background for deselection - tap anywhere on empty space
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedTrackName != nil {
                                        selectedTrackName = nil
                                        print("🎯 Deselected track - clicked on empty space")
                                    }
                                }

                            VStack(alignment: .leading, spacing: 0) {
                                // Time markers - scrolls horizontally with tracks
                                timeMarkers(geometry: timelineGeometry)
                                    .padding(.horizontal, 16)

                                // Tracks
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                                        timelineTrack(track: track, geometry: timelineGeometry)
                                            .padding(.horizontal, 16)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .safeAreaPadding(.top, 0)
                    .safeAreaPadding(.bottom, 0)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Calculate time based on click position
                                // Account for label space (92px = 80px label + 12px spacing) and padding (16px)
                                let labelSpace: CGFloat = 92
                                let startX: CGFloat = 16 + labelSpace
                                let endX = timelineGeometry.size.width - 16
                                let relativeX = max(startX, min(value.location.x, endX))
                                let progress = (relativeX - startX) / (endX - startX)
                                let targetTime = totalDuration * progress
                                let newTime = CMTime(seconds: targetTime, preferredTimescale: 600)
                                playerManager.seek(to: newTime)
                            }
                    )

                // Playhead indicator - tall vertical line overlaying everything (interactive)
                GeometryReader { geometry in
                    let currentSeconds = CMTimeGetSeconds(playerManager.currentTime)
                    let labelSpace: CGFloat = 92
                    let contentWidth = geometry.size.width - labelSpace - 32 // Account for label and padding
                    let playheadPosition = (currentSeconds / totalDuration) * contentWidth + 16 + labelSpace

                    ZStack(alignment: .topLeading) {
                        // Combined playhead: triangle + line as one unit
                        VStack(spacing: 0) {
                            // Inverted triangle handle at top (interactive)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 12))     // Bottom left
                                path.addLine(to: CGPoint(x: 10, y: 12))  // Bottom right
                                path.addLine(to: CGPoint(x: 5, y: 0))    // Top center (point)
                                path.closeSubpath()
                            }
                            .fill(theme.error)
                            .frame(width: 10, height: 12)
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Calculate new time based on drag position
                                        let startX: CGFloat = 16 + labelSpace
                                        let endX = geometry.size.width - 16
                                        let relativeX = max(startX, min(value.location.x + playheadPosition - 5, endX))
                                        let progress = (relativeX - startX) / (endX - startX)
                                        let targetTime = totalDuration * progress
                                        let newTime = CMTime(seconds: targetTime, preferredTimescale: 600)
                                        playerManager.seek(to: newTime)
                                    }
                            )

                            // Tall vertical line connected to triangle (non-interactive)
                            Rectangle()
                                .fill(theme.error)
                                .frame(width: 2, height: geometry.size.height - 12)
                                .allowsHitTesting(false) // Allow clicks to pass through to tracks
                        }
                        .offset(x: playheadPosition - 5, y: 0)
                    }
                }
                }
            }

            // Footer
            timelineFooter
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .background(theme.surfaceBackground)
        .cornerRadius(12)
        .overlay(
            // Custom tooltip overlay
            Group {
                if showTooltip, let segment = hoveredSegment {
                    GeometryReader { geometry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(segment.momentName ?? "Moment")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            Text("\(formatTime(seconds: Int(segment.startTime))) - \(formatTime(seconds: Int(segment.endTime)))")
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondaryText)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(theme.secondaryBorder)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .position(x: geometry.size.width / 2, y: 30)
                    }
                }
            }
        )
        .onAppear {
            loadTags()
            loadClips()
            // Sync duration from player manager if available
            let duration = CMTimeGetSeconds(playerManager.duration)
            if duration > 0 {
                totalDuration = duration
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TagCreated"))) { _ in
            loadTags()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClipCreated"))) { _ in
            loadClips()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClipUpdated"))) { _ in
            loadClips()
            loadTags() // Also reload tags/moments since clip edits update moments
            // Clear hover state to show updated times on next hover
            hoveredSegment = nil
            showTooltip = false
            print("🔄 Timeline: Reloaded clips and tags after clip update")
        }
        .onChange(of: playerManager.duration) { newDuration in
            // Update total duration when player manager duration changes
            let duration = CMTimeGetSeconds(newDuration)
            if duration > 0 {
                totalDuration = duration
            }
        }
    }

    // MARK: - Header
    private var timelineHeader: some View {
        HStack {
            // Timeline label and timecode
            HStack(spacing: 16) {
                Text("Timeline")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.secondaryText)

                Text("\(startTime) – \(endTime)")
                    .font(.system(size: 13))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            // Zoom control
            HStack(spacing: 12) {
                Text("Zoom")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)

                Slider(value: $timelineState.zoomLevel, in: 0...1)
                    .frame(width: 180)
                    .accentColor(theme.accent)
                    .onChange(of: timelineState.zoomLevel) { newValue in
                        print("🔍 Zoom level changed: \(newValue)")
                        print("   Visible duration: \(visibleDuration)s / Total: \(totalDuration)s")
                    }
            }
        }
    }

    // MARK: - Time Markers
    private func timeMarkers(geometry: GeometryProxy) -> some View {
        // Account for label space (80px label + 12px spacing = 92px)
        let labelSpace: CGFloat = 92
        let viewportWidth = geometry.size.width - labelSpace

        // Scale contentWidth based on zoom: when zoomed in, content is wider than viewport
        let zoomRatio = totalDuration / visibleDuration
        let contentWidth = viewportWidth * zoomRatio

        // Calculate time intervals dynamically based on visible duration and zoom
        let intervals = calculateTimeIntervals()

        return ZStack(alignment: .topLeading) {
            // Draw tick marks and labels - aligned with track content area
            ForEach(intervals, id: \.self) { seconds in
                let position = labelSpace + (Double(seconds) / totalDuration) * contentWidth

                VStack(spacing: 2) {
                    // Tick mark
                    Rectangle()
                        .fill(theme.tertiaryText)
                        .frame(width: 1, height: 6)

                    // Time label
                    Text(formatTime(seconds: Int(seconds)))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()
                }
                .position(x: position, y: 10)
            }
        }
        .frame(height: 24)
    }

    // Calculate appropriate time intervals based on total duration and zoom level
    private func calculateTimeIntervals() -> [Double] {
        var intervals: [Double] = []

        // Determine interval spacing based on visible duration
        let intervalSeconds: Double
        if visibleDuration <= 60 {
            intervalSeconds = 5  // Every 5 seconds
        } else if visibleDuration <= 300 {
            intervalSeconds = 30  // Every 30 seconds
        } else if visibleDuration <= 600 {
            intervalSeconds = 60  // Every 1 minute
        } else if visibleDuration <= 1800 {
            intervalSeconds = 300  // Every 5 minutes
        } else {
            intervalSeconds = 600  // Every 10 minutes
        }

        // Generate intervals from 0 to total duration
        var currentTime: Double = 0
        while currentTime <= totalDuration {
            intervals.append(currentTime)
            currentTime += intervalSeconds
        }

        // Always include the end time
        if intervals.last != totalDuration {
            intervals.append(totalDuration)
        }

        return intervals
    }

    // MARK: - Timeline Track
    private func timelineTrack(track: TimelineTrack, geometry: GeometryProxy) -> some View {
        let maxLane = track.segments.map { $0.lane }.max() ?? 0
        let laneHeight: CGFloat = 10
        let laneSpacing: CGFloat = 2
        let topPadding: CGFloat = 4  // Minimal padding for corner radius
        let bottomPadding: CGFloat = 4
        // Calculate height to fit all lanes plus padding
        // Each lane needs (laneHeight + laneSpacing), but last lane doesn't need spacing after it
        let trackHeight = topPadding + CGFloat(maxLane + 1) * laneHeight + CGFloat(maxLane) * laneSpacing + bottomPadding

        // Debug: Check if any segments would overflow
        for segment in track.segments {
            let yOffset = topPadding + CGFloat(segment.lane) * (laneHeight + laneSpacing)
            let segmentBottom = yOffset + laneHeight
            if segmentBottom > trackHeight {
                print("⚠️ OVERFLOW: Track '\(track.name)' segment in lane \(segment.lane) extends beyond track height!")
                print("   yOffset=\(yOffset) segmentBottom=\(segmentBottom) trackHeight=\(trackHeight) maxLane=\(maxLane)")
            }
        }

        print("📊 Track '\(track.name)': maxLane=\(maxLane) segments=\(track.segments.count) trackHeight=\(trackHeight)")

        // Time markers use same calculation - must match exactly
        let labelSpace: CGFloat = 92
        let viewportWidth = geometry.size.width - labelSpace

        // Scale contentWidth based on zoom: when zoomed in, content is wider than viewport
        let zoomRatio = totalDuration / visibleDuration
        let contentWidth = viewportWidth * zoomRatio

        // Track selection state for filtering clip navigation
        let isSelected = selectedTrackName == track.name

        return HStack(spacing: 12) {
            // Track label with segment count
            Text("\(track.name) (\(track.segments.count))")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? theme.accent : theme.tertiaryText)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(width: 80, alignment: .leading)

            // Track timeline - this ZStack should fill remaining width after label
            ZStack(alignment: .topLeading) {
                // Background track - must match contentWidth (no hit testing, just visual)
                Rectangle()
                    .fill(theme.secondaryBorder)
                    .frame(width: contentWidth, height: trackHeight)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color(hex: "2979ff") : Color.clear, lineWidth: 2)
                    )
                    .allowsHitTesting(false)  // Don't block segment interactions

                // Segments and markers - use contentWidth for positioning
                ZStack(alignment: .topLeading) {
                    // Segments
                    ForEach(track.segments, id: \.id) { (segment: TimelineSegment) in
                        // Position using contentWidth
                        let startPosition = (segment.startTime / totalDuration) * contentWidth
                        let endPosition = (segment.endTime / totalDuration) * contentWidth
                        let calculatedWidth = endPosition - startPosition
                        let width = max(calculatedWidth, 8) // Minimum width of 8 pixels
                        let yOffset = topPadding + CGFloat(segment.lane) * (laneHeight + laneSpacing)

                        Button(action: {
                            jumpToTime(segment.startTime)
                            if let momentId = segment.momentId {
                                selectMoment(momentId)
                            }
                        }) {
                            Rectangle()
                                .fill(segment.color)
                                .frame(width: width, height: laneHeight)
                                .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(x: startPosition, y: yOffset)
                        .onHover { isHovering in
                            if isHovering {
                                hoveredSegment = segment
                                showTooltip = true
                            } else {
                                showTooltip = false
                            }
                        }
                    }

                    // Markers (layers) - rendered alongside segments
                    ForEach(track.markers) { marker in
                        let markerPosition = (marker.time / totalDuration) * contentWidth

                        Button(action: {
                            jumpToTag(marker)
                        }) {
                            Circle()
                                .fill(marker.color)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(theme.primaryBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(x: markerPosition - 5, y: trackHeight / 2 - 5) // Center vertically on track
                        .help(marker.eventType ?? "Layer")
                    }
                }
                .frame(height: trackHeight)
                .onAppear {
                    print("📐 Timeline track '\(track.name)' rendered with \(track.segments.count) segments")
                    print("   contentWidth=\(contentWidth)px geometry.size.width=\(geometry.size.width)px")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: trackHeight)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Toggle selection
            if selectedTrackName == track.name {
                selectedTrackName = nil
                print("🎯 Deselected track: \(track.name)")
            } else {
                selectedTrackName = track.name
                print("🎯 Selected track: \(track.name) - filtering clip navigation")
            }
        }
    }

    // MARK: - Footer
    private var timelineFooter: some View {
        HStack {
            // Navigation buttons
            HStack(spacing: 16) {
                Button(action: { goToPreviousClip() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11))
                        Text("Previous Clip")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(currentClipIndex > 0 ? theme.secondaryText : theme.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(currentClipIndex <= 0)

                Button(action: { goToNextClip() }) {
                    HStack(spacing: 6) {
                        Text("Next Clip")
                            .font(.system(size: 12))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(currentClipIndex < clips.count - 1 ? theme.secondaryText : theme.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(currentClipIndex >= clips.count - 1)
            }

            Spacer()

            // Info text with clip count
            if clips.isEmpty {
                Text("Timeline is non-destructive · In/Out only affect exports")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            } else {
                Text("Clip \(currentClipIndex + 1) of \(clips.count) · Timeline is non-destructive")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            }
        }
    }

    // MARK: - Load Tags
    private func loadTags() {
        guard let project = navigationState.currentProject else {
            print("⚠️ TimelineViewer: No project available")
            tracks = createEmptyTracks()
            return
        }

        print("🔍 TimelineViewer: Looking for game in project \(project.id)")

        guard let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("⚠️ TimelineViewer: No game found for project \(project.id)")
            tracks = createEmptyTracks()
            return
        }

        print("🔍 TimelineViewer: Found gameId: \(gameId)")

        // Get longest video duration to set timeline length
        let videos = DatabaseManager.shared.getVideos(projectId: project.id)
        if !videos.isEmpty {
            let maxDurationMs = videos.map { $0.durationMs }.max() ?? 2700000
            totalDuration = Double(maxDurationMs) / 1000.0
            print("📊 TimelineViewer: Timeline duration set to \(totalDuration)s (longest video)")
        }

        // Get all tags for this game
        let tags = DatabaseManager.shared.getMoments(gameId: gameId)
        print("📊 TimelineViewer: Loading \(tags.count) tags for game \(gameId)")

        // Get blueprint to access moment colors
        // Try MomentBehaviorEngine first, fallback to loading from database
        var blueprint = MomentBehaviorEngine.shared.currentBlueprint
        if blueprint == nil {
            // Load blueprint from database (use first available)
            let blueprints = DatabaseManager.shared.getBlueprints()
            blueprint = blueprints.first
            if let bp = blueprint {
                print("📋 TimelineViewer: Loaded blueprint '\(bp.name)' from database for colors")
            } else {
                print("⚠️ TimelineViewer: No blueprint found in database, using default gray color")
            }
        }

        // Group tags by category dynamically
        let categorizedTags = Dictionary(grouping: tags, by: { $0.momentCategory })

        print("   - Found \(categorizedTags.count) unique moment categories:")
        for (category, categoryTags) in categorizedTags {
            print("     • \(category): \(categoryTags.count) moments")
        }

        // Debug: Print first few tags
        for (index, tag) in tags.prefix(3).enumerated() {
            let timeInSeconds = Double(tag.startTimestampMs) / 1000.0
            print("   Tag \(index + 1): \(tag.momentCategory) at \(timeInSeconds)s")
        }

        // Create tracks dynamically for each category
        var newTracks: [TimelineTrack] = []

        for (category, categoryTags) in categorizedTags.sorted(by: { $0.key < $1.key }) {
            // Get color for this category from blueprint (or use default)
            let color = blueprint?.moments.first(where: { $0.category == category })?.color ?? "666666"

            // Create segments for this category (only for completed tags with end times)
            let segments = categoryTags.compactMap { tag -> TimelineSegment? in
                guard let endMs = tag.endTimestampMs else {
                    print("   ⚠️ Skipping active \(category) tag at \(Double(tag.startTimestampMs) / 1000.0)s (no end time)")
                    return nil
                }
                let startTime = Double(tag.startTimestampMs) / 1000.0
                let endTime = Double(endMs) / 1000.0
                print("   📍 Creating segment for \(category): startMs=\(tag.startTimestampMs) endMs=\(endMs) -> startTime=\(startTime)s endTime=\(endTime)s")
                return TimelineSegment(
                    startTime: startTime,
                    endTime: endTime,
                    color: Color(hex: color),
                    momentId: tag.id,
                    momentName: tag.momentCategory
                )
            }

            // Assign lanes to prevent overlapping segments
            let segmentsWithLanes = assignLanes(to: segments)

            // Only add track if it has segments
            if !segmentsWithLanes.isEmpty {
                print("   ✅ Created track '\(category)' with \(segmentsWithLanes.count) segments (color: #\(color))")
                newTracks.append(TimelineTrack(name: category, segments: segmentsWithLanes, markers: []))
            }
        }

        // NOTE: Layer markers are not displayed on timeline (only shown in playback page)
        print("📍 TimelineViewer: Layers hidden from timeline (shown on playback page)")
        print("   📊 Total tracks created: \(newTracks.count)")

        tracks = newTracks
    }

    // Assign vertical lanes to overlapping segments so they don't stack on top of each other
    private func assignLanes(to segments: [TimelineSegment]) -> [TimelineSegment] {
        guard !segments.isEmpty else { return [] }

        // Sort segments by start time
        let sorted = segments.sorted { $0.startTime < $1.startTime }
        var result: [TimelineSegment] = []
        var lanes: [[TimelineSegment]] = [] // Array of lanes, each lane holds non-overlapping segments

        for segment in sorted {
            // Find first lane where segment doesn't overlap with the last segment in that lane
            var assignedLane = -1
            for (laneIndex, lane) in lanes.enumerated() {
                if let lastInLane = lane.last, lastInLane.endTime <= segment.startTime {
                    // No overlap, can use this lane
                    assignedLane = laneIndex
                    break
                }
            }

            // If no suitable lane found, create a new lane
            if assignedLane == -1 {
                assignedLane = lanes.count
                lanes.append([])
            }

            // Assign segment to lane
            var segmentWithLane = segment
            segmentWithLane.lane = assignedLane
            result.append(segmentWithLane)
            lanes[assignedLane].append(segmentWithLane)
        }

        print("   📍 Assigned \(result.count) segments to \(lanes.count) lanes")
        return result
    }

    private func createEmptyTracks() -> [TimelineTrack] {
        return [
            TimelineTrack(name: "Offense", segments: [], markers: []),
            TimelineTrack(name: "Defence", segments: [], markers: []),
            TimelineTrack(name: "Transition", segments: [], markers: []),
            TimelineTrack(name: "Outcomes", segments: [], markers: [])
        ]
    }

    private func getColorForEventType(_ eventType: String) -> Color {
        // Shot events - green for makes, red for misses
        if eventType.contains("Shot") || eventType.contains("Free Throw") {
            return theme.success // Green for shots
        }
        // Positive offensive events
        else if eventType.contains("Assist") || eventType.contains("Offensive Rebound") {
            return theme.accent // Light blue
        }
        // Negative offensive events
        else if eventType.contains("Turnover") {
            return theme.error // Red
        }
        // Defensive events
        else if eventType.contains("Defensive Rebound") || eventType.contains("Steal") {
            return theme.success // Green
        }
        else if eventType.contains("Block") || eventType.contains("Deflection") {
            return theme.accentLight // Cyan
        }
        else if eventType.contains("Foul") {
            return theme.error.opacity(0.6) // Light red
        }
        // Transition events
        else if eventType.contains("Fast Break") {
            return theme.error // Red
        }
        // Default
        else {
            return theme.warning // Yellow/Gold
        }
    }

    // MARK: - Jump to Tag/Time
    private func jumpToTime(_ timeInSeconds: Double) {
        let timestampMs = Int64(timeInSeconds * 1000)

        print("🎯 TimelineViewer: Jumping to \(formatTimeMs(timestampMs))")

        // Post notification for video player to seek to this timestamp
        NotificationCenter.default.post(
            name: NSNotification.Name("JumpToTag"),
            object: nil,
            userInfo: ["timestampMs": timestampMs]
        )
    }

    private func selectMoment(_ momentId: String) {
        print("📌 TimelineViewer: Selecting tag \(momentId)")

        // Post notification to select tag in right panel
        NotificationCenter.default.post(
            name: NSNotification.Name("SelectTag"),
            object: nil,
            userInfo: ["tagId": momentId]
        )
    }

    private func jumpToTag(_ marker: TimelineMarker) {
        guard let momentId = marker.momentId else {
            print("⚠️ TimelineViewer: Marker has no tag ID")
            return
        }

        // Convert marker time to milliseconds
        let markerTimestampMs = Int64(marker.time * 1000)

        print("🎯 Jumping to tag #\(momentId): \(marker.eventType ?? "Unknown") at \(formatTimeMs(markerTimestampMs))")

        // Find the moment to get its start timestamp
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("❌ No project/game available")
            return
        }

        let moments = DatabaseManager.shared.getMoments(gameId: gameId)
        guard let moment = moments.first(where: { $0.id == momentId }) else {
            print("⚠️ Could not find moment with ID \(momentId)")
            return
        }

        // Use the moment's start timestamp to find the clip
        let momentStartMs = moment.startTimestampMs
        let momentEndMs = moment.endTimestampMs ?? momentStartMs
        print("📌 Moment: \(formatTimeMs(momentStartMs)) - \(formatTimeMs(momentEndMs))")

        // Find the clip that was created from this moment
        // Note: Clips may have lead/lag time offsets, so we look for clips that overlap with the moment
        print("🔍 Looking for clip matching moment: \(formatTimeMs(momentStartMs)) - \(formatTimeMs(momentEndMs))")
        print("   Available clips: \(clips.count)")
        for (idx, clip) in clips.enumerated() {
            print("   Clip \(idx): \(clip.title) (\(formatTimeMs(clip.startTimeMs)) - \(formatTimeMs(clip.endTimeMs)))")
        }

        if let clipIndex = clips.firstIndex(where: { clip in
            // Check if clip overlaps with moment time range
            // Clip overlaps if: clip.startTimeMs <= momentEndMs AND clip.endTimeMs >= momentStartMs
            let overlaps = clip.startTimeMs <= momentEndMs && clip.endTimeMs >= momentStartMs

            // Also check if clip contains the moment's start time (more precise match)
            let containsStart = clip.startTimeMs <= momentStartMs && clip.endTimeMs >= momentStartMs

            let matches = overlaps && containsStart
            if matches {
                print("   ✅ Found match: \(clip.title) (\(formatTimeMs(clip.startTimeMs)) - \(formatTimeMs(clip.endTimeMs)))")
            }
            return matches
        }) {
            let clip = clips[clipIndex]
            print("📍 Found matching clip: \(clip.title) at index \(clipIndex)")

            // Update shared state to select this clip
            timelineState.selectClip(clipId: clip.id)

            // Also update local clip index for Previous/Next navigation
            currentClipIndex = clipIndex
        } else {
            print("⚠️ No clip found for moment at \(formatTimeMs(momentStartMs))")
        }

        // Post notification for video player to seek to the moment's start time
        NotificationCenter.default.post(
            name: NSNotification.Name("JumpToTag"),
            object: nil,
            userInfo: ["timestampMs": momentStartMs, "tagId": momentId]
        )
    }

    private func formatTimeMs(_ timestampMs: Int64) -> String {
        let totalSeconds = Int(timestampMs / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Load Clips
    private func loadClips() {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            clips = []
            return
        }

        clips = DatabaseManager.shared.getClips(gameId: gameId)
        print("🎬 TimelineViewer: Loaded \(clips.count) clips")

        // Reset clip index if it's out of bounds
        if currentClipIndex >= clips.count {
            currentClipIndex = max(0, clips.count - 1)
        }
    }

    // MARK: - Clip Navigation
    private func goToPreviousClip() {
        let filteredClips = getFilteredClips()
        guard !filteredClips.isEmpty else {
            print("⚠️ No clips available")
            return
        }

        let currentClip = clips[currentClipIndex]

        // Find current clip in filtered list
        if let currentFilteredIndex = filteredClips.firstIndex(where: { $0.id == currentClip.id }) {
            // Current clip is in filtered list - go to previous
            if currentFilteredIndex > 0 {
                let previousClip = filteredClips[currentFilteredIndex - 1]
                if let globalIndex = clips.firstIndex(where: { $0.id == previousClip.id }) {
                    currentClipIndex = globalIndex
                    jumpToClipStart(previousClip)
                }
            } else {
                print("⚠️ Already at first clip in filtered list")
            }
        } else {
            // Current clip not in filtered list - find the last clip before current time
            let currentTime = currentClip.startTimeMs
            let clipsBeforeCurrent = filteredClips.filter { $0.startTimeMs < currentTime }

            if let lastClip = clipsBeforeCurrent.last,
               let globalIndex = clips.firstIndex(where: { $0.id == lastClip.id }) {
                currentClipIndex = globalIndex
                jumpToClipStart(lastClip)
            } else if let firstClip = filteredClips.first,
                      let globalIndex = clips.firstIndex(where: { $0.id == firstClip.id }) {
                // No clips before, go to first in filtered list
                currentClipIndex = globalIndex
                jumpToClipStart(firstClip)
            }
        }
    }

    private func goToNextClip() {
        let filteredClips = getFilteredClips()
        guard !filteredClips.isEmpty else {
            print("⚠️ No clips available")
            return
        }

        let currentClip = clips[currentClipIndex]

        // Find current clip in filtered list
        if let currentFilteredIndex = filteredClips.firstIndex(where: { $0.id == currentClip.id }) {
            // Current clip is in filtered list - go to next
            if currentFilteredIndex < filteredClips.count - 1 {
                let nextClip = filteredClips[currentFilteredIndex + 1]
                if let globalIndex = clips.firstIndex(where: { $0.id == nextClip.id }) {
                    currentClipIndex = globalIndex
                    jumpToClipStart(nextClip)
                }
            } else {
                print("⚠️ Already at last clip in filtered list")
            }
        } else {
            // Current clip not in filtered list - find the first clip after current time
            let currentTime = currentClip.startTimeMs
            let clipsAfterCurrent = filteredClips.filter { $0.startTimeMs > currentTime }

            if let nextClip = clipsAfterCurrent.first,
               let globalIndex = clips.firstIndex(where: { $0.id == nextClip.id }) {
                currentClipIndex = globalIndex
                jumpToClipStart(nextClip)
            } else if let firstClip = filteredClips.first,
                      let globalIndex = clips.firstIndex(where: { $0.id == firstClip.id }) {
                // No clips after, go to first in filtered list
                currentClipIndex = globalIndex
                jumpToClipStart(firstClip)
            }
        }
    }

    private func getFilteredClips() -> [Clip] {
        guard let selectedTrack = selectedTrackName else {
            // No track selected, return all clips
            return clips
        }

        // Get moments for the current game
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            return clips
        }

        let moments = DatabaseManager.shared.getMoments(gameId: gameId)

        // Filter clips by matching them to moments of the selected category
        return clips.filter { clip in
            // Find the moment that matches this clip's time range
            let matchingMoment = moments.first { moment in
                moment.startTimestampMs == clip.startTimeMs &&
                moment.endTimestampMs == clip.endTimeMs
            }

            // Check if the moment's category matches the selected track
            return matchingMoment?.momentCategory == selectedTrack
        }
    }

    private func jumpToClipStart(_ clip: Clip) {
        print("🎬 Jumping to clip \(currentClipIndex + 1): \(clip.title) at \(formatTimeMs(clip.startTimeMs))")

        // Post notification for video player to seek to clip start
        NotificationCenter.default.post(
            name: NSNotification.Name("JumpToClip"),
            object: nil,
            userInfo: ["startTimeMs": clip.startTimeMs, "clipId": clip.id]
        )
    }

    // MARK: - Helper
    private func formatTime(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    TimelineViewer()
        .frame(width: 1200, height: 240)
        .background(Color.black)
        .environmentObject(NavigationState())
        .environmentObject(ThemeManager.shared)
}
