//
//  MomentsView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 14/12/2025.
//

import SwiftUI
import AVFoundation
import AppKit

struct MomentsView: View {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var playerManager = SyncedVideoPlayerManager.shared
    @ObservedObject private var focusManager = VideoPlayerFocusManager.shared
    @ObservedObject private var autoSaveManager = AutoSaveManager.shared
    @ObservedObject private var behaviorEngine = MomentBehaviorEngine.shared
    @ObservedObject private var timelineState = TimelineStateManager.shared
    @StateObject private var toastManager = ToastManager()

    // Tag/Label state management
    @State private var activeTag: Moment? = nil
    @State private var selectedTag: Moment? = nil  // For sidebar details
    @State private var selectedMomentNotes: String = ""  // Editable notes for selected moment
    @State private var tagButtons: [MomentButton] = DefaultMomentCategories.all
    @State private var labelButtons: [LayerButton] = DefaultLayerTypes.all
    @State private var allTags: [Moment] = []

    // UI state
    @State private var searchText: String = ""
    @State private var selectedAngle: String = "Angle A"
    @State private var selectedAngleIndex: Int = 0
    @State private var isHotkeysActive: Bool = true
    @State private var videoAngles: [VideoAngle] = []
    @State private var editingMoment: MomentButton?
    @State private var editingLayer: LayerButton?
    @State private var selectedMainNav: MainNavItem = .tagging
    @State private var showSettings: Bool = false
    @State private var availableBlueprints: [Blueprint] = []
    @State private var selectedBlueprintId: String?
    @State private var canvasZoom: CGFloat = 1  // Start zoomed out to fit sidebar
    @State private var isZoomToolActive: Bool = false
    @State private var zoomFocusPoint: CGPoint = CGPoint(x: 1000, y: 750)

    private var sessionInfo: String {
        let momentCount = allTags.count
        if momentCount == 0 {
            return "No moments created • Hotkeys active"
        } else if momentCount == 1 {
            return "Auto-save every 30 seconds • 1 moment"
        } else {
            return "Auto-save every 30 seconds • \(momentCount) moments"
        }
    }

    @ObservedObject private var themeManager = ThemeManager.shared
    
    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main Navigation Bar
            MainNavigationBar(selectedItem: $selectedMainNav)
                .onChange(of: selectedMainNav) { newValue in
                    handleNavigationChange(newValue)
                }

            GeometryReader { geometry in
                HStack(spacing: 12) {
                    // Left Sidebar - Tag Template (20% of width, min 260px, max 300px)
                    leftSidebar
                        .frame(width: min(max(geometry.size.width * 0.20, 260), 300))

                    // Center - Video Viewer (flexible, takes remaining space)
                    centerVideoArea(geometry: geometry)
                        .frame(maxWidth: .infinity)

                    // Right Sidebar - Tag Details (22% of width, min 280px, max 340px)
                    rightSidebar
                        .frame(width: min(max(geometry.size.width * 0.22, 280), 340))
                }
                .padding(.all, 12)
            }
        }
        .background(theme.primaryBackground)
        .onAppear {
            // Set keyboard focus to main player when this view appears
            focusManager.setFocus(.mainPlayer)

            loadVideos()
            loadTags()
            loadBlueprint()
        }
        .focusable()
        .onKeyPress { keyPress in
            return handleKeyPress(keyPress)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("JumpToTag"))) { notification in
            if let timestampMs = notification.userInfo?["timestampMs"] as? Int64 {
                // Seek video
                let seconds = Double(timestampMs) / 1000.0
                let time = CMTime(seconds: seconds, preferredTimescale: 600)
                playerManager.seek(to: time)
                print("🎬 Video jumped to \(seconds)s from timeline click")

                // Load tag if provided
                if let momentId = notification.userInfo?["tagId"] as? String {
                    loadTagDetails(momentId: momentId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTag"))) { notification in
            if let momentId = notification.userInfo?["tagId"] as? String {
                loadTagDetails(momentId: momentId)
            }
        }
        .onChange(of: timelineState.selectedClipId) { oldValue, newValue in
            // When a clip is selected from the timeline, open the clip player popup
            if let clipId = newValue {
                openClipPlayerForId(clipId)
            }
        }
        .toast(manager: toastManager)
        .globalKeyboardShortcuts(onEscape: {
            if activeTag != nil {
                endCurrentTag()
            }
        })
        .sheet(item: $editingMoment) { moment in
            MomentConfigModal(
                moment: moment,
                existingMoments: tagButtons,
                onSave: { newMoment in
                    tagButtons.append(newMoment)
                    print("✅ Created new moment: \(newMoment.category)")
                    editingMoment = nil
                },
                isNewMoment: moment.id == "new-moment-placeholder"
            )
        }
        .sheet(item: $editingLayer) { layer in
            LayerConfigModal(
                layer: layer,
                onSave: { newLayer in
                    labelButtons.append(newLayer)
                    editingLayer = nil
                    print("✅ Created new layer: \(newLayer.layerType)")
                }
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Load Videos
    private func loadVideos() {
        guard let project = navigationState.currentProject,
              let bundle = ProjectManager.shared.currentProject else {
            print("❌ TaggingView: No project bundle available")
            print("   - currentProject: \(navigationState.currentProject?.name ?? "nil")")
            print("   - bundle: \(ProjectManager.shared.currentProject?.name ?? "nil")")
            return
        }

        let videos = DatabaseManager.shared.getVideos(projectId: project.id)
        print("📹 TaggingView: Loading \(videos.count) videos")

        videoAngles = videos.enumerated().map { index, video in
            // Remove "videos/" prefix if it exists in the file path since bundle.videosPath already points to videos folder
            let fileName = video.filePath.replacingOccurrences(of: "videos/", with: "")
            let videoURL = bundle.videosPath.appendingPathComponent(fileName)
            print("   - Video \(index): \(video.filePath)")
            print("   - Cleaned filename: \(fileName)")
            print("   - Full path: \(videoURL.path)")
            print("   - Exists: \(FileManager.default.fileExists(atPath: videoURL.path))")

            return VideoAngle(
                name: "Angle \(String(UnicodeScalar(65 + index)!))",
                description: video.cameraAngle,
                timecode: formatDuration(TimeInterval(video.durationMs) / 1000.0),
                additionalInfo: "\(video.width)x\(video.height) · \(String(format: "%.2f", video.frameRate))fps",
                imageName: nil,
                isActive: index == 0,
                videoURL: videoURL
            )
        }

        // Load videos into player manager
        let videoURLs = videoAngles.compactMap { $0.videoURL }
        print("📹 TaggingView: Setting up \(videoURLs.count) video players")
        if !videoURLs.isEmpty {
            Task { @MainActor in
                await playerManager.setupPlayers(videoURLs: videoURLs)
                // Enable single-angle mode for better performance in tagging view
                playerManager.setSingleAngleMode(true)
            }

            // Switch to the angle selected in MaxView (or default to first angle)
            let targetAngleIndex = navigationState.selectedAngleIndex
            if targetAngleIndex < videoAngles.count {
                selectedAngleIndex = targetAngleIndex
                selectedAngle = videoAngles[targetAngleIndex].name
                print("📹 TaggingView: Switching to angle \(targetAngleIndex) from MaxView selection")
                playerManager.switchToAngle(targetAngleIndex)
            } else {
                // If invalid index, default to first angle
                selectedAngleIndex = 0
                selectedAngle = videoAngles.first?.name ?? "Angle A"
                print("📹 TaggingView: Invalid angle index \(targetAngleIndex), defaulting to angle 0")
            }

            // Give player a moment to initialize, then try to play
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let player = playerManager.getPlayer(at: self.selectedAngleIndex) {
                    print("✅ TaggingView: Player ready, status: \(player.status.rawValue)")
                    print("   - Current item: \(player.currentItem != nil ? "exists" : "nil")")
                    if let item = player.currentItem {
                        print("   - Item status: \(item.status.rawValue)")
                        print("   - Duration: \(item.duration)")
                    }
                }
            }
        } else {
            print("❌ TaggingView: No video URLs to load")
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    // MARK: - Blueprint Loading

    private func loadBlueprint() {
        // Load all available blueprints
        availableBlueprints = DatabaseManager.shared.getBlueprints()

        // If no blueprints exist, create a default one
        if availableBlueprints.isEmpty {
            let defaultBlueprint = Blueprint(
                id: UUID().uuidString,
                name: "Default Blueprint",
                moments: DefaultMomentCategories.all,
                layers: DefaultLayerTypes.all,
                createdAt: Date()
            )

            let result = DatabaseManager.shared.saveBlueprint(defaultBlueprint)
            switch result {
            case .success(let saved):
                availableBlueprints = [saved]
                print("✅ Created default blueprint")
            case .failure(let error):
                print("❌ Failed to create default blueprint: \(error)")
                availableBlueprints = [defaultBlueprint]
            }
        }

        // Select blueprint (use selected ID, or first available)
        let blueprintToLoad: Blueprint
        if let selectedId = selectedBlueprintId,
           let selected = availableBlueprints.first(where: { $0.id == selectedId }) {
            blueprintToLoad = selected
        } else {
            blueprintToLoad = availableBlueprints.first!
            selectedBlueprintId = blueprintToLoad.id
        }

        // Apply the selected blueprint
        behaviorEngine.setBlueprint(blueprintToLoad)
        tagButtons = blueprintToLoad.moments
        labelButtons = blueprintToLoad.layers
        print("✅ Loaded blueprint: '\(blueprintToLoad.name)' with \(blueprintToLoad.moments.count) moments")
    }

    private func switchBlueprint(to blueprintId: String) {
        selectedBlueprintId = blueprintId
        loadBlueprint()
        print("🔄 Switched to blueprint: \(blueprintId)")
    }

    // MARK: - Tag/Label Management

    private func endCurrentTag() {
        guard let active = activeTag,
              let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            return
        }

        let currentTimestamp = getCurrentVideoTimestamp()

        // Validate end timestamp is not before start timestamp
        let endTimestamp: Int64
        if currentTimestamp < active.startTimestampMs {
            print("⚠️ End time (\(formatTimestampMs(currentTimestamp))) is before start time (\(formatTimestampMs(active.startTimestampMs)))")
            print("   Using start time as end time instead")
            endTimestamp = active.startTimestampMs
            toastManager.show(
                message: "Video seeked backward - moment ended at start time",
                icon: "exclamationmark.triangle.fill",
                backgroundColor: "ffa500",
                duration: 3.0
            )
        } else {
            endTimestamp = currentTimestamp
        }

        let result = DatabaseManager.shared.endMoment(momentId: active.id, endTimestampMs: endTimestamp)

        switch result {
        case .success(let endedTag):
            print("✅ Ended tag '\(endedTag.momentCategory)' via ESC - duration: \(endedTag.durationMs ?? 0)ms")

            // Automatically create a clip from this tag
            if let endMs = endedTag.endTimestampMs {
                let clipTitle = "\(endedTag.momentCategory) - \(formatTimestampMs(endedTag.startTimestampMs))"
                let layerTypes = endedTag.layers.map { $0.layerType }

                // Apply lead/lag time offsets with bounds checking
                let adjustedTimes = applyLeadLagOffsets(
                    category: endedTag.momentCategory,
                    startTimeMs: endedTag.startTimestampMs,
                    endTimeMs: endMs
                )

                let clipResult = DatabaseManager.shared.createClip(
                    gameId: gameId,
                    startTimeMs: adjustedTimes.startTimeMs,
                    endTimeMs: adjustedTimes.endTimeMs,
                    title: clipTitle,
                    notes: "",
                    tags: layerTypes
                )

                switch clipResult {
                case .success(let clip):
                    print("✅ Auto-created clip: '\(clip.title)' (\(clip.duration)s)")
                    NotificationCenter.default.post(name: NSNotification.Name("ClipCreated"), object: nil)
                case .failure(let error):
                    print("⚠️ Failed to auto-create clip: \(error)")
                }
            }

            // Notify timeline that tag ended
            NotificationCenter.default.post(name: NSNotification.Name("TagCreated"), object: nil)

            activeTag = nil
            toastManager.show(message: "\(endedTag.momentCategory) stopped", icon: "stop.circle.fill", backgroundColor: "666666")
            loadTags()

        case .failure(let error):
            print("❌ Failed to end tag via ESC: \(error)")
            toastManager.show(message: "Failed to stop moment", icon: "xmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func loadTags() {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("❌ TaggingView.loadTags: No project or game")
            return
        }

        allTags = DatabaseManager.shared.getMoments(gameId: gameId)
        print("📊 TaggingView: Loaded \(allTags.count) tags")

        // Check if there's an active tag
        activeTag = DatabaseManager.shared.getActiveMoment(gameId: gameId)
        if let active = activeTag {
            print("✅ TaggingView: Found active tag '\(active.momentCategory)'")
        }
    }

    private func toggleTag(category: String) {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            toastManager.show(message: "No game loaded", icon: "xmark.circle.fill", backgroundColor: "ff5252")
            return
        }

        let currentTimestamp = getCurrentVideoTimestamp()

        // If clicking same category, just deactivate (don't start new tag)
        if activeTag?.momentCategory == category {
            deactivateMoment(category: category, gameId: gameId, timestamp: currentTimestamp)
            return
        }

        // If there's a different active tag, end it first
        if let active = activeTag {
            deactivateMoment(category: active.momentCategory, gameId: gameId, timestamp: currentTimestamp)
        }

        // Activate the new moment (with behavior engine handling)
        activateMoment(category: category, gameId: gameId, timestamp: currentTimestamp)
    }

    /// Activate a moment with full behavior engine integration
    private func activateMoment(category: String, gameId: String, timestamp: Int64) {
        // Call behavior engine BEFORE activating to handle pre-activation behaviors
        behaviorEngine.handleMomentActivation(
            momentCategory: category,
            currentActiveCategory: activeTag?.momentCategory,
            gameId: gameId,
            timestamp: timestamp,
            onDeactivate: { categoryToDeactivate in
                self.deactivateMoment(category: categoryToDeactivate, gameId: gameId, timestamp: timestamp)
            },
            onActivate: { categoryToActivate in
                self.activateMoment(category: categoryToActivate, gameId: gameId, timestamp: timestamp)
            }
        )

        // Start the moment in database
        let result = DatabaseManager.shared.startMoment(
            gameId: gameId,
            category: category,
            timestampMs: timestamp
        )

        switch result {
        case .success(let tag):
            activeTag = tag
            toastManager.show(message: "\(category) started", icon: "record.circle.fill", backgroundColor: "5adc8c")
            print("✅ Started moment '\(category)' at \(timestamp)ms")
            NotificationCenter.default.post(name: NSNotification.Name("TagCreated"), object: nil)
            loadTags()

        case .failure(let error):
            toastManager.show(message: "Failed to start moment", icon: "xmark.circle.fill", backgroundColor: "ff5252")
            print("❌ Failed to start moment: \(error)")
        }
    }

    /// Deactivate a moment with full behavior engine integration
    private func deactivateMoment(category: String, gameId: String, timestamp: Int64) {
        // Find the active moment for this category
        guard let momentToEnd = allTags.first(where: { $0.momentCategory == category && $0.endTimestampMs == nil }) else {
            print("⚠️ No active moment found for '\(category)'")
            return
        }

        // Validate end timestamp is not before start timestamp
        let endTimestamp: Int64
        if timestamp < momentToEnd.startTimestampMs {
            print("⚠️ End time (\(formatTimestampMs(timestamp))) is before start time (\(formatTimestampMs(momentToEnd.startTimestampMs)))")
            print("   Using start time as end time instead")
            endTimestamp = momentToEnd.startTimestampMs
            toastManager.show(
                message: "Video seeked backward - moment ended at start time",
                icon: "exclamationmark.triangle.fill",
                backgroundColor: "ffa500",
                duration: 3.0
            )
        } else {
            endTimestamp = timestamp
        }

        // End the moment in database
        let result = DatabaseManager.shared.endMoment(momentId: momentToEnd.id, endTimestampMs: endTimestamp)

        switch result {
        case .success(let endedTag):
            print("✅ Ended moment '\(endedTag.momentCategory)' - duration: \(endedTag.durationMs ?? 0)ms")

            // Automatically create a clip from this tag
            if let endMs = endedTag.endTimestampMs {
                let clipTitle = "\(endedTag.momentCategory) - \(formatTimestampMs(endedTag.startTimestampMs))"
                let layerTypes = endedTag.layers.map { $0.layerType }

                // Apply lead/lag time offsets with bounds checking
                let adjustedTimes = applyLeadLagOffsets(
                    category: endedTag.momentCategory,
                    startTimeMs: endedTag.startTimestampMs,
                    endTimeMs: endMs
                )

                let clipResult = DatabaseManager.shared.createClip(
                    gameId: gameId,
                    startTimeMs: adjustedTimes.startTimeMs,
                    endTimeMs: adjustedTimes.endTimeMs,
                    title: clipTitle,
                    notes: "",
                    tags: layerTypes
                )

                switch clipResult {
                case .success(let clip):
                    print("✅ Auto-created clip: '\(clip.title)' (\(clip.duration)s)")
                    NotificationCenter.default.post(name: NSNotification.Name("ClipCreated"), object: nil)
                case .failure(let error):
                    print("⚠️ Failed to auto-create clip: \(error)")
                }
            }

            // Call behavior engine AFTER deactivating to handle post-deactivation behaviors
            behaviorEngine.handleMomentDeactivation(
                momentCategory: category,
                gameId: gameId,
                timestamp: timestamp,
                onActivate: { categoryToActivate in
                    self.activateMoment(category: categoryToActivate, gameId: gameId, timestamp: timestamp)
                },
                onDeactivate: { categoryToDeactivate in
                    self.deactivateMoment(category: categoryToDeactivate, gameId: gameId, timestamp: timestamp)
                }
            )

            // Update UI
            if activeTag?.id == endedTag.id {
                activeTag = nil
            }
            toastManager.show(message: "\(category) stopped", icon: "stop.circle.fill", backgroundColor: "666666")
            NotificationCenter.default.post(name: NSNotification.Name("TagCreated"), object: nil)
            loadTags()

        case .failure(let error):
            print("❌ Failed to end moment: \(error)")
        }
    }

    private func addLabelToActiveTag(layerType: String) {
        guard let active = activeTag else {
            toastManager.show(message: "No active tag", icon: "exclamationmark.circle", backgroundColor: "ffa500")
            return
        }

        let result = DatabaseManager.shared.addLayer(momentId: active.id, layerType: layerType)

        switch result {
        case .success:
            toastManager.show(message: layerType, icon: "checkmark.circle.fill", backgroundColor: "5adc8c", duration: 1.0)
            print("✅ Added label '\(layerType)' to active tag")
        case .failure(let error):
            toastManager.show(message: "Failed to add label", icon: "xmark.circle.fill", backgroundColor: "ff5252")
            print("❌ Failed to add label: \(error)")
        }
    }

    private func getCurrentVideoTimestamp() -> Int64 {
        // Use the playerManager's currentTime which is always updated from the active player
        let seconds = CMTimeGetSeconds(playerManager.currentTime)
        let timestampMs = Int64(seconds * 1000.0)  // Convert to milliseconds
        return timestampMs
    }

    private func applyLeadLagOffsets(category: String, startTimeMs: Int64, endTimeMs: Int64) -> (startTimeMs: Int64, endTimeMs: Int64) {
        // Find the moment button configuration for this category
        guard let momentButton = tagButtons.first(where: { $0.category == category }) else {
            print("⚠️ No moment button found for category '\(category)', using original times")
            return (startTimeMs, endTimeMs)
        }

        let leadTimeMs = Int64((momentButton.leadTimeSeconds ?? 0) * 1000)
        let lagTimeMs = Int64((momentButton.lagTimeSeconds ?? 0) * 1000)

        // Apply offsets
        var adjustedStart = startTimeMs - leadTimeMs
        var adjustedEnd = endTimeMs + lagTimeMs

        // Get video duration for bounds checking
        var maxDurationMs: Int64 = Int64.max
        if let player = playerManager.getPlayer(at: selectedAngleIndex),
           let item = player.currentItem {
            let durationSeconds = CMTimeGetSeconds(item.duration)
            if durationSeconds.isFinite && durationSeconds > 0 {
                maxDurationMs = Int64(durationSeconds * 1000.0)
            }
        }

        // Apply bounds checking
        adjustedStart = max(0, adjustedStart)
        adjustedEnd = min(maxDurationMs, adjustedEnd)

        // Ensure start < end
        if adjustedStart >= adjustedEnd {
            print("⚠️ Lead/lag offsets caused invalid clip bounds, using original times")
            return (startTimeMs, endTimeMs)
        }

        if leadTimeMs > 0 || lagTimeMs > 0 {
            print("✅ Applied lead/lag offsets: lead=\(leadTimeMs)ms, lag=\(lagTimeMs)ms")
            print("   Original: \(startTimeMs)ms - \(endTimeMs)ms")
            print("   Adjusted: \(adjustedStart)ms - \(adjustedEnd)ms")
        }

        return (adjustedStart, adjustedEnd)
    }

    // MARK: - Left Sidebar (Tag Template)
    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("MOMENTS TEMPLATE")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
                    .tracking(0.5)

                // Blueprint Selector
                Menu {
                    ForEach(availableBlueprints, id: \.id) { blueprint in
                        Button(action: {
                            switchBlueprint(to: blueprint.id)
                        }) {
                            HStack {
                                Text(blueprint.name)
                                Spacer()
                                if blueprint.id == selectedBlueprintId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button(action: {
                        Task { @MainActor in
                            await navigationState.navigate(to: .blueprints)
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create New Blueprint")
                        }
                    }
                } label: {
                    HStack {
                        if let selectedBlueprint = availableBlueprints.first(where: { $0.id == selectedBlueprintId }) {
                            Text(selectedBlueprint.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                        } else {
                            Text("Select Blueprint")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                        }

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(theme.tertiaryText)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                HStack(spacing: 8) {
                    Button(action: {}) {
                        Text("Import")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(theme.primaryBorder)
                            .cornerRadius(999)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {}) {
                        Text("Export")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(theme.primaryBorder)
                            .cornerRadius(999)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Temporary: Clear all tags button
                    Button(action: { clearAllTags() }) {
                        Text("Clear All")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(theme.primaryBorder)
                            .cornerRadius(999)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)

                TextField("Search moments, players, hotkeys...", text: $searchText)
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.surfaceBackground)
            .cornerRadius(6)
            .padding(.horizontal, 16)

            // Zoom controls
            HStack(spacing: 8) {
                Button(action: {
                    canvasZoom = max(0.3, canvasZoom - 0.1)
                }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(canvasZoom <= 0.3)

                Text("\(Int(canvasZoom * 100))%")
                    .font(.system(size: 9))
                    .foregroundColor(theme.tertiaryText)
                    .frame(width: 35)

                Button(action: {
                    canvasZoom = min(1.5, canvasZoom + 0.1)
                }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(canvasZoom >= 1.5)

                Spacer()

                Button(action: {
                    isZoomToolActive.toggle()
                }) {
                    Image(systemName: isZoomToolActive ? "scope.fill" : "scope")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(isZoomToolActive ? theme.accent : .white)
            }
            .foregroundColor(theme.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surfaceBackground)

            // Active Tag Indicator
            if let active = activeTag {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Text("Recording: \(active.momentCategory)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    let duration = getCurrentVideoTimestamp() - active.startTimestampMs
                    Text(formatDurationMs(duration))
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(theme.error.opacity(0.2))
                .cornerRadius(6)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Canvas view with positioned buttons
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Canvas background
                    Rectangle()
                        .fill(theme.primaryBackground)
                        .frame(width: 2000, height: 1500)

                    // Render moment buttons at their positions (only those with x,y set)
                    ForEach(tagButtons.filter { $0.x != nil && $0.y != nil }) { button in
                        captureCanvasMomentButton(button: button)
                            .position(
                                x: button.x!,
                                y: button.y!
                            )
                    }

                    // Render layer buttons at their positions (only those with x,y set)
                    ForEach(labelButtons.filter { $0.x != nil && $0.y != nil }) { button in
                        captureCanvasLayerButton(button: button)
                            .position(
                                x: button.x!,
                                y: button.y!
                            )
                    }

                    // Instructions when empty (no positioned items)
                    if tagButtons.filter({ $0.x != nil && $0.y != nil }).isEmpty &&
                       labelButtons.filter({ $0.x != nil && $0.y != nil }).isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 32))
                                .foregroundColor(theme.primaryBorder)

                            Text("No items on canvas")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(theme.tertiaryText)

                            Text("Items must be positioned in blueprint editor first")
                                .font(.system(size: 10))
                                .foregroundColor(theme.tertiaryText)
                        }
                        .position(x: 1000, y: 300)
                    }
                }
                .frame(width: 2000, height: 1500, alignment: .topLeading)
                .coordinateSpace(name: "captureCanvas")
                .scaleEffect(canvasZoom, anchor: .topLeading)
                .frame(minWidth: 2000 * canvasZoom, minHeight: 1500 * canvasZoom, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { location in
                    if isZoomToolActive {
                        handleZoomClick(at: location)
                    }
                }
            }
            .background(theme.primaryBackground)

            Spacer()

            // Footer
            HStack {
                Text("Linked to hotkey profile: Analyst · 1")
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                Button(action: {
                    editingMoment = MomentButton(
                        id: "new-moment-placeholder",
                        category: "",
                        color: "2979ff",
                        hotkey: nil
                    )
                }) {
                    Text("Create Moment")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Center Video Area
    private func centerVideoArea(geometry: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            // Video player with integrated controls - calculated height like MaxView
            VStack(spacing: 0) {
                // Top bar with angle selector
                HStack {
                    Text("Multi-Angle Viewer · Angle A selected · Hotkeys active")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)

                    Spacer()

                    HStack(spacing: 8) {
                        ForEach(0..<min(videoAngles.count, 4), id: \.self) { index in
                            Button(action: {
                                selectedAngleIndex = index
                                selectedAngle = videoAngles[index].name
                                // Switch to the selected angle in single-angle mode
                                playerManager.switchToAngle(index)
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedAngleIndex == index ? theme.accent : theme.primaryBorder)
                                        .frame(width: 20, height: 20)

                                    Text("\(index + 1)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(theme.primaryText)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(theme.secondaryBackground)

                // Video display
                ZStack {
                    Color.black

                    if !videoAngles.isEmpty, let player = playerManager.getPlayer(at: selectedAngleIndex) {
                        VideoPlayerView(player: player, videoGravity: .resizeAspect)
                            .onAppear {
                                print("🎬 TaggingView: VideoPlayerView appeared for angle \(selectedAngleIndex)")
                            }
                    } else {
                        // Placeholder when no video loaded
                        VStack(spacing: 12) {
                            Image(systemName: "film")
                                .font(.system(size: 60))
                                .foregroundColor(theme.primaryBorder)

                            if videoAngles.isEmpty {
                                Text("No video loaded")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.tertiaryText)

                                Text("Import videos to begin creating moments")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.tertiaryText)
                            } else {
                                Text("Loading video...")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.tertiaryText)

                                Text("\(videoAngles.count) video(s) found")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.tertiaryText)
                            }
                        }
                    }
                }

                // Playback controls
                playbackControls
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(theme.secondaryBackground)
            }
            .frame(height: geometry.size.height - 300 - 8 - 24) // Subtract timeline (300) + spacing (8) + padding (24) - matches MaxView
            .background(theme.secondaryBackground)
            .cornerRadius(8)

            // Timeline area - fixed height exactly like MaxViewScreen
            TimelineViewer()
                .frame(height: 300)
        }
    }


    // MARK: - Right Sidebar (Tag Details)
    private var rightSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Circle()
                    .fill(selectedTag != nil ? theme.accent : theme.tertiaryText)
                    .frame(width: 8, height: 8)

                Text(selectedTag != nil ? "Selected Moment" : "No Moment Selected")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                if selectedTag != nil {
                    Button(action: { selectedTag = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let tag = selectedTag {
                        // Show tag details
                        selectedTagDetails(tag: tag)
                    } else {
                        // Empty state
                        emptyTagState
                    }
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Selected Tag Details
    private func selectedTagDetails(tag: Moment) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tag Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Text(tag.momentCategory)
                    .font(.system(size: 13))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.surfaceBackground)
                    .cornerRadius(6)
            }

            // Time Range
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Range")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                if let endMs = tag.endTimestampMs, let durationMs = tag.durationMs {
                    Text("\(formatTimestampMs(tag.startTimestampMs)) → \(formatTimestampMs(endMs))")
                        .font(.system(size: 12))
                        .foregroundColor(theme.primaryText)
                    Text("Duration: \(formatDurationMs(durationMs))")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                } else {
                    Text("Active (started at \(formatTimestampMs(tag.startTimestampMs)))")
                        .font(.system(size: 12))
                        .foregroundColor(theme.success)
                }
            }

            // Labels
            VStack(alignment: .leading, spacing: 8) {
                Text("Layers (\(tag.layers.count))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                if tag.layers.isEmpty {
                    Text("No layers attached")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                } else {
                    ForEach(tag.layers) { label in
                        Text("• \(label.layerType)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.primaryText)
                    }
                }
            }

            // Players
            MomentPlayersSection(momentId: tag.id, projectId: navigationState.currentProject?.id)

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Notes")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)

                    Spacer()

                    // Save button
                    Button(action: {
                        saveMomentNotes(momentId: tag.id, notes: selectedMomentNotes)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Save")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.accent)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                TextEditor(text: $selectedMomentNotes)
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)
                    .frame(height: 100)
                    .padding(8)
                    .background(theme.surfaceBackground)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.primaryBorder, lineWidth: 1)
                    )
                    .onAppear {
                        // Load notes when the view appears
                        selectedMomentNotes = tag.notes ?? ""
                    }
            }

            Divider().background(theme.primaryBorder)

            // Clip Information
            if let clip = getClipForTag(tag) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clip")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "film")
                                .font(.system(size: 10))
                                .foregroundColor(theme.tertiaryText)
                            Text(clip.title)
                                .font(.system(size: 11))
                                .foregroundColor(theme.primaryText)
                        }

                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(theme.tertiaryText)
                            Text("\(clip.formattedStartTime) · \(clip.formattedDuration)")
                                .font(.system(size: 11))
                                .foregroundColor(theme.tertiaryText)
                        }
                    }
                }

                Divider().background(theme.primaryBorder)
            }

            // Quick Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Actions")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                if let clip = getClipForTag(tag) {
                    Button(action: { playClip(clip) }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Play Clip")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.accent)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { exportClip(clip) }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Export Clip")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(theme.success)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { addToPlaylist(clip) }) {
                        HStack {
                            Image(systemName: "plus.rectangle.on.folder")
                            Text("Add to Playlist")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(theme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider().background(theme.primaryBorder)
                }

                Button(action: { deleteTag(tag) }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Moment & Clip")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyTagState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.system(size: 32))
                .foregroundColor(theme.tertiaryText)

            Text("No moment selected")
                .font(.system(size: 13))
                .foregroundColor(theme.tertiaryText)

            Text("Click a moment on the timeline to view details")
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Tag Management
    private func loadTagDetails(momentId: String) {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            return
        }

        // Load all tags and find the matching one
        let tags = DatabaseManager.shared.getMoments(gameId: gameId)
        selectedTag = tags.first { $0.id == momentId }

        if let tag = selectedTag {
            print("✅ Selected moment: \(tag.momentCategory)")
            // Load notes into the editable state
            selectedMomentNotes = tag.notes ?? ""

            // Auto-open clip player window if clip exists
            if let clip = getClipForTag(tag) {
                playClip(clip)
            }
        }
    }

    private func clearAllTags() {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            toastManager.showError("No game loaded")
            return
        }

        let result = DatabaseManager.shared.deleteAllMoments(gameId: gameId)
        switch result {
        case .success:
            toastManager.show(message: "All tags cleared", icon: "trash.fill", backgroundColor: "5adc8c")
            selectedTag = nil
            loadTags()
            // Notify timeline to refresh
            NotificationCenter.default.post(name: NSNotification.Name("TagCreated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("ClipCreated"), object: nil)
        case .failure(let error):
            toastManager.showError("Failed to clear tags: \(error)")
        }
    }

    private func deleteTag(_ tag: Moment) {
        let result = DatabaseManager.shared.deleteMoment(momentId: tag.id)
        switch result {
        case .success:
            toastManager.showSuccess("Tag deleted")
            selectedTag = nil
            // Notify timeline to refresh
            NotificationCenter.default.post(name: NSNotification.Name("TagCreated"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("ClipCreated"), object: nil)
        case .failure(let error):
            toastManager.showError("Failed to delete tag: \(error)")
        }
    }

    // MARK: - Clip Management
    private func getClipForTag(_ tag: Moment) -> Clip? {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            return nil
        }

        let clips = DatabaseManager.shared.getClips(gameId: gameId)
        // Find clip that matches this tag's time range
        return clips.first { clip in
            clip.startTimeMs == tag.startTimestampMs &&
            clip.endTimeMs == tag.endTimestampMs
        }
    }

    private func saveMomentNotes(momentId: String, notes: String) {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNotes = trimmedNotes.isEmpty ? nil : trimmedNotes

        print("📝 Saving notes for moment \(momentId): \(finalNotes ?? "(empty)")")

        let result = DatabaseManager.shared.updateMomentNotes(momentId: momentId, notes: finalNotes)

        switch result {
        case .success:
            print("✅ Notes saved successfully")
            toastManager.show(message: "Notes saved", icon: "checkmark.circle.fill", backgroundColor: "2979ff")
            // Reload tags to reflect changes in the list
            loadTags()
        case .failure(let error):
            print("❌ Failed to save notes: \(error)")
            toastManager.show(message: "Failed to save notes", icon: "exclamationmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func playClip(_ clip: Clip) {
        // Use shared clip player manager
        ClipPlayerManager.shared.openClipPlayer(clip: clip, navigationState: navigationState)
    }

    private func openClipPlayerForId(_ clipId: String) {
        // Find the clip by ID and open it
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("❌ No project/game available")
            return
        }

        let clips = DatabaseManager.shared.getClips(gameId: gameId)
        if let clip = clips.first(where: { $0.id == clipId }) {
            print("🎬 Opening clip player for: \(clip.title)")
            ClipPlayerManager.shared.openClipPlayer(clip: clip, navigationState: navigationState)
        } else {
            print("⚠️ Could not find clip with ID \(clipId)")
        }
    }

    private func exportClip(_ clip: Clip) {
        toastManager.show(message: "Export functionality coming soon", icon: "square.and.arrow.down", backgroundColor: "2979ff")
        print("📦 Export clip: \(clip.title)")
    }

    private func addToPlaylist(_ clip: Clip) {
        toastManager.show(message: "Playlist functionality coming soon", icon: "plus.rectangle.on.folder", backgroundColor: "2979ff")
        print("📂 Add to playlist: \(clip.title)")
    }

    // MARK: - Playback Controls
    private var playbackControls: some View {
        PlaybackControls(playerManager: playerManager, showTimeline: true)
    }

    private func formatTime(_ time: CMTime) -> String {
        let totalSeconds = Int(CMTimeGetSeconds(time))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((CMTimeGetSeconds(time).truncatingRemainder(dividingBy: 1)) * 100)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d:%02d", minutes, seconds, milliseconds)
        }
    }

    // MARK: - Keyboard Shortcut Handler
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard isHotkeysActive else { return .ignored }

        // Don't handle hotkeys if typing in a text field
        if isTextFieldFocused() {
            return .ignored
        }

        let key = keyPress.characters.uppercased()

        // Handle spacebar for play/pause
        if keyPress.characters == " " {
            playerManager.togglePlayPause()
            return .handled
        }

        // Check tag buttons first
        if let tagButton = tagButtons.first(where: { $0.hotkey == key }) {
            toggleTag(category: tagButton.category)
            return .handled
        }

        // Check label buttons (only if tag is active)
        if activeTag != nil {
            if let labelButton = labelButtons.first(where: { $0.hotkey == key }) {
                addLabelToActiveTag(layerType: labelButton.layerType)
                return .handled
            }
        }

        return .ignored
    }

    private func isTextFieldFocused() -> Bool {
        guard let window = NSApp.keyWindow else {
            return false
        }

        if let firstResponder = window.firstResponder {
            // Check if first responder is a text input field
            if firstResponder is NSTextView ||
               firstResponder is NSTextField ||
               String(describing: type(of: firstResponder)).contains("TextField") ||
               String(describing: type(of: firstResponder)).contains("TextEditor") {
                return true
            }
        }

        return false
    }


    private func formatDurationMs(_ ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatTimestampMs(_ ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Action Handlers

    private func handleGoHome() {
        print("🏠 Going home...")
        Task { @MainActor in
            await navigationState.navigate(to: .home)
        }
    }

    private func handleImportVideos() {
        guard let project = navigationState.currentProject,
              let bundle = ProjectManager.shared.currentProject else {
            print("⚠️ No project open for video import")
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.message = "Select video files to import"
        panel.prompt = "Import"

        panel.begin { response in
            if response == .OK {
                let urls = panel.urls
                print("📥 Importing \(urls.count) videos...")

                let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id)

                guard let gId = gameId else {
                    print("❌ No game found for project")
                    return
                }

                let result = ProjectManager.shared.importVideos(from: urls, gameId: gId)

                switch result {
                case .success(let videoIds):
                    print("✅ Successfully imported \(videoIds.count) videos")
                    // Reload videos
                    loadVideos()

                case .failure(let error):
                    print("❌ Failed to import videos: \(error.localizedDescription)")
                    let alert = NSAlert()
                    alert.messageText = "Video Import Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    private func handleExportClips() {
        print("📤 Export clips - not yet implemented")
        toastManager.show(message: "Export functionality coming soon", icon: "square.and.arrow.down", backgroundColor: "2979ff")
    }

    private func handleLayoutsMenu() {
        print("🎛️ Layouts menu - not yet implemented")
        toastManager.show(message: "Layouts menu coming soon", icon: "square.grid.2x2", backgroundColor: "2979ff")
    }

    private func handleProjectSettings() {
        print("⚙️ Opening settings...")
        showSettings = true
    }

    // MARK: - Navigation Handler

    private func handleNavigationChange(_ item: MainNavItem) {
        Task { @MainActor in
            switch item {
            case .maxView:
                await navigationState.navigate(to: .maxView)
            case .tagging:
                // Already on capture/moments
                break
            case .playback:
                await navigationState.navigate(to: .playback)
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

    // MARK: - Canvas Helper Functions

    private func captureCanvasMomentButton(button: MomentButton) -> some View {
        Button(action: { toggleTag(category: button.category) }) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.primaryText)

                Text(button.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.primaryText)

                if let hotkey = button.hotkey {
                    Text(hotkey)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: button.color))
            .cornerRadius(6)
            .overlay(
                activeTag?.momentCategory == button.category ?
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white, lineWidth: 2)
                    : nil
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func captureCanvasLayerButton(button: LayerButton) -> some View {
        Button(action: { addLabelToActiveTag(layerType: button.layerType) }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(theme.primaryText)
                    .frame(width: 8, height: 8)

                Text(button.layerType)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.primaryText)

                if let hotkey = button.hotkey {
                    Text(hotkey)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: button.color).opacity(activeTag == nil ? 0.5 : 1.0))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(activeTag == nil)
    }

    private func getDefaultMomentPosition(for moment: MomentButton) -> CGPoint {
        guard let index = tagButtons.firstIndex(where: { $0.id == moment.id }) else {
            return CGPoint(x: 200, y: 200)
        }

        let column = index % 5
        let row = index / 5

        let x = 150 + CGFloat(column) * 200
        let y = 150 + CGFloat(row) * 100

        return CGPoint(x: x, y: y)
    }

    private func getDefaultLayerPosition(for layer: LayerButton) -> CGPoint {
        guard let index = labelButtons.firstIndex(where: { $0.id == layer.id }) else {
            return CGPoint(x: 200, y: 600)
        }

        let column = index % 6
        let row = index / 6

        let x = 150 + CGFloat(column) * 180
        let y = 700 + CGFloat(row) * 80

        return CGPoint(x: x, y: y)
    }

    private func handleZoomClick(at location: CGPoint) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if canvasZoom < 1.5 {
                canvasZoom = min(1.5, canvasZoom + 0.3)
            }
            zoomFocusPoint = location
        }
        print("🔍 Zoomed to \(Int(canvasZoom * 100))% at location (\(Int(location.x)), \(Int(location.y)))")
    }
}

// Flow layout for label buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Moment Players Selection Section

struct MomentPlayersSection: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let momentId: String
    let projectId: String?

    @State private var availablePlayers: [Player] = []
    @State private var selectedPlayerIds: Set<String> = []
    @State private var isLoading = true

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Players")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                if !selectedPlayerIds.isEmpty {
                    Text("\(selectedPlayerIds.count) selected")
                        .font(.system(size: 9))
                        .foregroundColor(theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.1))
                        .cornerRadius(3)
                }
            }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if availablePlayers.isEmpty {
                Text("No players in project")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(availablePlayers, id: \.id) { player in
                            let playerId = player.id.uuidString
                            let isSelected = selectedPlayerIds.contains(playerId)

                            Button(action: {
                                togglePlayer(playerId)
                            }) {
                                HStack(spacing: 8) {
                                    // Checkbox
                                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 14))
                                        .foregroundColor(isSelected ? theme.accent : theme.tertiaryText)

                                    // Jersey number
                                    Text("#\(player.number)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(theme.tertiaryText)
                                        .frame(width: 30, alignment: .leading)

                                    // Player name
                                    Text(player.name)
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.primaryText)

                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? theme.accent.opacity(0.08) : theme.surfaceBackground)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? theme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        guard let projectId = projectId else {
            isLoading = false
            return
        }

        // Load available players
        availablePlayers = DatabaseManager.shared.getPlayersForProject(projectId: projectId)

        // Load currently selected players for this moment
        let momentPlayers = DatabaseManager.shared.getPlayersForMoment(momentId: momentId)
        selectedPlayerIds = Set(momentPlayers.map { $0.id.uuidString })

        isLoading = false
    }

    private func togglePlayer(_ playerId: String) {
        if selectedPlayerIds.contains(playerId) {
            selectedPlayerIds.remove(playerId)
        } else {
            selectedPlayerIds.insert(playerId)
        }

        // Save to database
        let playerIdsArray = Array(selectedPlayerIds)
        let result = DatabaseManager.shared.attachPlayersToMoment(momentId: momentId, playerIds: playerIdsArray)

        switch result {
        case .success:
            print("✅ Updated players for moment \(momentId)")
        case .failure(let error):
            print("❌ Failed to update players: \(error)")
        }
    }
}

#Preview {
    MomentsView()
        .environmentObject(NavigationState())
        .frame(width: 1440, height: 900)
}
