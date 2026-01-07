//
//  AnnotationView.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI
import AVFoundation
import AppKit
import UniformTypeIdentifiers

struct AnnotationView: View {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject var annotationManager = AnnotationManager.shared
    @ObservedObject var playerManager = SyncedVideoPlayerManager.shared
    @ObservedObject private var focusManager = VideoPlayerFocusManager.shared
    @ObservedObject private var autoSaveManager = AutoSaveManager.shared
    @State private var enableAnimation: Bool = true
    @State private var currentTime: Double = 744.0 // 00:12:44
    @State private var selectedMainNav: MainNavItem = .annotation
    @State private var showSettings: Bool = false
    @State private var videoCount: Int = 0
    @State private var autoSaveTimer: Timer?
    @State private var debounceSaveTimer: Timer?
    @State private var lastVisibleAnnotationsCount: Int = 0
    @State private var projectVideos: [(id: String, cameraAngle: String, filePath: String)] = []

    private var sessionInfo: String {
        if videoCount == 0 {
            return "No videos imported • Auto-save ready"
        } else if videoCount == 1 {
            return "Auto-save every 30 seconds • 1 video angle"
        } else {
            return "Auto-save every 30 seconds • \(videoCount) video angles"
        }
    }

    @ObservedObject private var themeManager = ThemeManager.shared
    
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

                // Main content area
                GeometryReader { geometry in
                    HStack(spacing: 12) {
                        // Left: Multi-angle viewer
                        multiAngleViewerSection
                            .frame(width: geometry.size.width - 320 - 24 - 12)

                        // Right: Control panel
                        rightControlPanel
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 12)
                    .padding(.top, 12)
                }

                // Bottom: Playback controls
                playbackControls

                // Bottom: Annotation toolbar
                annotationToolbar
            }
        }
        .onAppear {
            // Set keyboard focus to main player when this view appears
            focusManager.setFocus(.mainPlayer)

            setupKeyboardShortcuts()
            loadProjectVideos()

            // Load annotations for current project
            if let project = navigationState.currentProject {
                annotationManager.setCurrentProject(project.id)
                annotationManager.loadAnnotations(projectId: project.id)
                print("📂 Loading annotations for project: \(project.name)")
            }

            // Start auto-save timer (save every 30 seconds)
            startAutoSave()
            
            // Setup app lifecycle observers for critical saves
            setupLifecycleObservers()
        }
        .onChange(of: navigationState.currentProject?.id) { oldProjectId, newProjectId in
            // Save annotations for the old project before switching
            if let oldProjectId = oldProjectId, oldProjectId != newProjectId {
                annotationManager.saveAnnotations(projectId: oldProjectId)
                print("💾 Saved annotations before switching projects")
            }

            // Reload annotations when project changes
            guard let newProjectId = newProjectId,
                  let project = navigationState.currentProject else {
                // Clear annotations if no project (loadAnnotations with empty data)
                annotationManager.setCurrentProject(nil)
                annotationManager.loadAnnotations(projectId: "")
                print("🧹 Cleared annotations (no project loaded)")
                return
            }

            // Only reload if project actually changed
            if oldProjectId != newProjectId {
                annotationManager.setCurrentProject(project.id)
                annotationManager.loadAnnotations(projectId: project.id)
                loadProjectVideos() // Reload videos for angle selector
                print("🔄 Reloaded annotations for project: \(project.name)")
            }
        }
        .onDisappear {
            // Stop auto-save timer
            stopAutoSave()

            // Stop debounce timer
            debounceSaveTimer?.invalidate()

            // Force synchronous save when leaving the view
            if let project = navigationState.currentProject {
                annotationManager.forceSaveAnnotationsSync(projectId: project.id)
                print("💾 Force saved annotations on view disappear")
            }
            
            // Remove lifecycle observers
            NotificationCenter.default.removeObserver(self, name: NSApplication.willTerminateNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSApplication.willResignActiveNotification, object: nil)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Project Data Loading

    private func loadProjectVideos() {
        guard let project = navigationState.currentProject else {
            videoCount = 0
            projectVideos = []
            return
        }

        // Load videos once and cache in state
        let videos = DatabaseManager.shared.getVideos(projectId: project.id)
        videoCount = videos.count
        projectVideos = videos.map { (id: $0.videoId, cameraAngle: $0.cameraAngle, filePath: $0.filePath) }
        print("📹 Loaded \(videoCount) videos for project: \(project.name)")
    }

    // MARK: - Action Handlers

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

                // Get the first game ID for this project
                let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id)

                guard let gId = gameId else {
                    print("❌ No game found for project")
                    return
                }

                // Import videos using ProjectManager
                let result = ProjectManager.shared.importVideos(from: urls, gameId: gId)

                switch result {
                case .success(let videoIds):
                    print("✅ Successfully imported \(videoIds.count) videos")
                    // Reload video count
                    loadProjectVideos()

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
        // TODO: Implement export functionality
    }

    private func handleLayoutsMenu() {
        print("🎛️ Layouts menu - not yet implemented")
        // TODO: Implement layout presets menu
    }

    private func handleProjectSettings() {
        print("⚙️ Opening settings...")
        showSettings = true
    }

    private func handleGoHome() {
        print("🏠 Going home...")
        Task { @MainActor in
            await navigationState.navigate(to: .home)
        }
    }

    // MARK: - Navigation Handler

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
                await navigationState.navigate(to: .playlist)
            case .annotation:
                // Already on annotation
                break
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

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        // Monitor keyboard events for tool switching and commands
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""

            // SPACEBAR - Play/Pause video (only if context is appropriate)
            if event.keyCode == 49 { // Spacebar keycode
                if self.shouldHandleSpacebar() {
                    self.playerManager.togglePlayPause()
                    print("⏯️ Spacebar: Toggled play/pause")
                    return nil
                }
                // Let spacebar pass through (e.g., for text fields)
                return event
            }

            // Check for Cmd+R (reload)
            if event.modifierFlags.contains(.command) && characters == "r" {
                self.reloadAnnotationView()
                return nil
            }

            // Regular tool shortcuts (without modifiers) - with toggle support
            // Don't handle if text field is focused
            if !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.option) && !event.modifierFlags.contains(.control) {
                // Check if text field is focused before handling tool shortcuts
                if self.shouldHandleSpacebar() {
                    switch characters {
                    case "v":
                        // V = Select/Move mode (already in select? stay in select - it's the default)
                        annotationManager.currentTool = .select
                        return nil
                    case "a":
                        // A = Arrow tool (toggle)
                        toggleTool(.arrow)
                        return nil
                    case "p":
                        // P = Pen tool (toggle)
                        toggleTool(.pen)
                        return nil
                    case "c":
                        // C = Circle tool (toggle)
                        toggleTool(.circle)
                        return nil
                    case "r":
                        // R = Rectangle tool (toggle, without Cmd)
                        toggleTool(.rectangle)
                        return nil
                    case "t":
                        // T = Text tool (toggle)
                        toggleTool(.text)
                        return nil
                    default:
                        return event
                    }
                }
            }

            return event
        }
    }

    private func reloadAnnotationView() {
        // Reload videos from project
        playerManager.pause()

        // Force refresh the multi-angle viewer
        if let project = navigationState.currentProject,
           let bundle = ProjectManager.shared.currentProject {
            let loadedVideos = DatabaseManager.shared.getVideos(projectId: project.id)

            if !loadedVideos.isEmpty {
                let videoURLs = Array(loadedVideos.prefix(4)).map { videoInfo -> URL in
                    bundle.bundlePath.appendingPathComponent(videoInfo.filePath)
                }

                Task { @MainActor in
                    await playerManager.setupPlayers(videoURLs: videoURLs)

                    // Reset playback time
                    playerManager.seek(to: .zero)
                }
                annotationManager.currentTimeMs = 0

                print("🔄 Reloaded annotation view - \(videoURLs.count) videos")
            }
        }
    }

    private func toggleTool(_ tool: AnnotationToolType) {
        if annotationManager.currentTool == tool {
            // Tool is already active, toggle it off (return to select mode)
            annotationManager.currentTool = .select
            print("🔄 Toggled off \(tool.rawValue), returning to Select mode")
        } else {
            // Activate the tool
            annotationManager.currentTool = tool
            print("✏️ Activated \(tool.rawValue) tool")
        }
    }

    /// Determines if spacebar should trigger play/pause
    private func shouldHandleSpacebar() -> Bool {
        guard let window = NSApp.keyWindow else {
            print("⚠️ No key window - ignoring spacebar")
            return false
        }

        // Only handle spacebar on screens with video players
        let videoScreens: [AppScreen] = [.annotation, .moments, .playback, .maxView]
        guard videoScreens.contains(navigationState.currentScreen) else {
            print("⚠️ Not on video screen (\(navigationState.currentScreen)) - ignoring spacebar")
            return false
        }

        // Check if first responder is a text input field
        if let firstResponder = window.firstResponder {
            // Don't handle spacebar if typing in text field, text view, or search field
            if firstResponder is NSTextView ||
               firstResponder is NSTextField ||
               String(describing: type(of: firstResponder)).contains("TextField") ||
               String(describing: type(of: firstResponder)).contains("TextEditor") {
                print("⚠️ Text field focused - ignoring spacebar")
                return false
            }
        }

        // Check if a modal/sheet is presented
        if window.className.contains("Sheet") || window.className.contains("Modal") {
            print("⚠️ Modal/sheet open - ignoring spacebar")
            return false
        }

        print("✅ Context OK - handling spacebar on \(navigationState.currentScreen)")
        return true
    }

    // MARK: - Auto-Save

    private func startAutoSave() {
        // Save every 30 seconds automatically
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if let project = navigationState.currentProject {
                annotationManager.saveAnnotations(projectId: project.id)
                print("💾 Auto-saved \(annotationManager.annotations.count) annotations")
            }
        }
    }

    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    private func setupLifecycleObservers() {
        // Save when app is about to terminate
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            guard let project = navigationState.currentProject else { return }
            
            // Force synchronous save on app termination
            annotationManager.forceSaveAnnotationsSync(projectId: project.id)
            print("💾 Critical save on app termination")
        }
        
        // Save when app goes to background
        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            guard let project = navigationState.currentProject else { return }
            
            // Async save when going to background
            annotationManager.saveAnnotations(projectId: project.id)
            print("💾 Background save triggered")
        }
    }

    private func debouncedSave() {
        // Cancel existing timer
        debounceSaveTimer?.invalidate()

        // Create new timer that will save 2 seconds after last change
        debounceSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            if let project = navigationState.currentProject {
                annotationManager.saveAnnotations(projectId: project.id)
                print("💾 Debounced save triggered - saved \(annotationManager.annotations.count) annotations")
            }
        }
    }

    // MARK: - Video Viewer Section

    private var multiAngleViewerSection: some View {
        VStack(spacing: 0) {
            // Header
            viewerHeader

            // Single video with angle selector
            MultiAngleViewerGrid(playerManager: playerManager)
                .background(theme.primaryBackground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    private var viewerHeader: some View {
        HStack {
            Text("Video Viewer")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.primaryText)

            Text("Annotation Tools Active")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.accent)

            Spacer()
            
            // Camera angle selector
            if projectVideos.count > 1 {
                HStack(spacing: 8) {
                    ForEach(Array(projectVideos.enumerated()), id: \.offset) { index, video in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                playerManager.switchToAngle(index)
                            }
                        }) {
                            Text(video.cameraAngle.capitalized)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(playerManager.activePlayerIndex == index ? .white : theme.tertiaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    playerManager.activePlayerIndex == index
                                        ? theme.accent
                                        : theme.surfaceBackground
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.secondaryBackground)
    }

    // MARK: - Right Control Panel

    private var rightControlPanel: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    CurrentToolPanel(
                        selectedTool: $annotationManager.currentTool,
                        strokeThickness: Binding(
                            get: { Double(annotationManager.strokeWidth) },
                            set: { annotationManager.strokeWidth = CGFloat($0) }
                        ),
                        opacity: $annotationManager.opacity,
                        selectedColor: $annotationManager.selectedColor,
                        endCapStyle: $annotationManager.endCapStyle,
                        durationSeconds: $annotationManager.annotationDurationSeconds,
                        freezeDuration: $annotationManager.freezeDuration,
                        enableKeyframes: $annotationManager.enableKeyframes
                    )

                    LayersPanel(
                        annotationManager: annotationManager,
                        onSeekToTime: { timeMs in
                            // Seek to the annotation's timestamp
                            playerManager.seek(to: CMTime(value: timeMs, timescale: 1000))
                        }
                    )

                    KeyframesPanel(
                        annotationManager: annotationManager,
                        enableAnimation: $enableAnimation,
                        currentTime: $currentTime
                    )

                    QuickActionsPanel(annotationManager: annotationManager)
                }
                .padding(12)
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 320)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        PlaybackControls(playerManager: playerManager, showTimeline: true)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(theme.primaryBackground)
    }

    // MARK: - Annotation Toolbar

    private var annotationToolbar: some View {
        AnnotationToolbar(selectedTool: $annotationManager.currentTool, annotationManager: annotationManager)
    }
}

// MARK: - Supporting Types

enum AnnotationToolType: String, CaseIterable {
    case select = "Select"
    case arrow = "Arrow"
    case pen = "Pen"
    case circle = "Circle"
    case rectangle = "Rectangle"
    case text = "Text"
    case ruler = "Ruler"
    case grid1 = "Grid 1"
    case grid2 = "Grid 2"
    case grid3 = "Grid 3"

    var iconName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .pen: return "pencil"
        case .circle: return "circle"
        case .rectangle: return "rectangle"
        case .text: return "textformat"
        case .ruler: return "ruler"
        case .grid1: return "grid"
        case .grid2: return "square.grid.2x2"
        case .grid3: return "square.grid.3x3"
        }
    }
}

enum EndCapStyle: String, CaseIterable {
    case rounded = "Rounded"
    case square = "Square"
}

// MARK: - Preview

struct AnnotationView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationView()
    }
}
