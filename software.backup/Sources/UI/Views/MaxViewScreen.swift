//
//  MaxViewScreen.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MaxViewScreen: View {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var focusManager = VideoPlayerFocusManager.shared
    @ObservedObject private var autoSaveManager = AutoSaveManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedMainNav: MainNavItem = .maxView
    @State private var isLeftSidebarCollapsed: Bool = false
    @State private var isRightSidebarCollapsed: Bool = false
    @State private var videoCount: Int = 0
    @State private var showSettings: Bool = false
    
    var theme: ThemeColors {
        themeManager.colors
    }

    private var sessionInfo: String {
        if videoCount == 0 {
            return "No videos imported • Auto-save ready"
        } else if videoCount == 1 {
            return "Auto-save every 30 seconds • 1 video angle"
        } else {
            return "Auto-save every 30 seconds • \(videoCount) video angles"
        }
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
                    .onAppear {
                        loadProjectVideos()
                    }

                GeometryReader { geometry in
                    HStack(spacing: 12) {
                        // Left Sidebar Navigator with integrated collapse button
                        if !isLeftSidebarCollapsed {
                            ZStack(alignment: .topTrailing) {
                                LeftSidebarNavigator()
                                    .transition(.move(edge: .leading).combined(with: .opacity))

                                // Compact collapse button overlay
                                CollapseSidebarButton(
                                    direction: .left,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            isLeftSidebarCollapsed.toggle()
                                        }
                                    }
                                )
                                .padding(.top, 6)
                                .padding(.trailing, 6)
                            }
                        } else {
                            // Compact expand button when collapsed
                            CollapseSidebarButton(
                                direction: .right,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isLeftSidebarCollapsed.toggle()
                                    }
                                }
                            )
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        // Center Content Area - Video Grid and Timeline
                        VStack(spacing: 8) {
                            // Video Grid Viewer - calculated height
                            VideoGridViewer()
                                .frame(height: geometry.size.height - 300 - 8 - 24) // Subtract timeline (300) + spacing (8) + padding (24)

                            // Timeline Viewer
                            TimelineViewer()
                                .frame(height: 300)
                        }
                        .frame(maxWidth: .infinity)

                        // Right Sidebar Panel with integrated collapse button
                        if !isRightSidebarCollapsed {
                            ZStack(alignment: .topLeading) {
                                RightSidebarPanel()
                                    .transition(.move(edge: .trailing).combined(with: .opacity))

                                // Compact collapse button overlay
                                CollapseSidebarButton(
                                    direction: .right,
                                    action: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            isRightSidebarCollapsed.toggle()
                                        }
                                    }
                                )
                                .padding(.top, 6)
                                .padding(.leading, 6)
                            }
                        } else {
                            // Compact expand button when collapsed
                            CollapseSidebarButton(
                                direction: .left,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isRightSidebarCollapsed.toggle()
                                    }
                                }
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.all, 12)
                }
            }
        }
        .onAppear {
            // Set keyboard focus to main player when this view appears
            focusManager.setFocus(.mainPlayer)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectTag"))) { notification in
            if let momentId = notification.userInfo?["tagId"] as? String {
                openClipForMoment(momentId)
            }
        }
    }

    // MARK: - Project Data Loading
    private func loadProjectVideos() {
        guard let project = navigationState.currentProject else {
            videoCount = 0
            return
        }

        // Get video count from database for current project
        videoCount = DatabaseManager.shared.getVideoCount(projectId: project.id)
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
                // TODO: Support multiple games - for now use first game or create one
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
                // Already on MaxView
                break
            case .tagging:
                await navigationState.navigate(to: .moments)
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

    // MARK: - Clip Player
    private func openClipForMoment(_ momentId: String) {
        // Use shared clip player manager
        ClipPlayerManager.shared.openClipForMoment(momentId, navigationState: navigationState)
    }
}

// MARK: - Collapse Sidebar Button Component

struct CollapseSidebarButton: View {
    @EnvironmentObject var themeManager: ThemeManager

    enum Direction {
        case left, right

        var iconName: String {
            switch self {
            case .left: return "chevron.left.2"
            case .right: return "chevron.right.2"
            }
        }

        var tooltipText: String {
            switch self {
            case .left: return "Collapse sidebar"
            case .right: return "Expand sidebar"
            }
        }
    }

    let direction: Direction
    let action: () -> Void
    @State private var isHovered: Bool = false

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.iconName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(isHovered ? theme.secondaryText : theme.tertiaryText)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(theme.secondaryBackground.opacity(isHovered ? 0.95 : 0.85))
                )
                .overlay(
                    Circle()
                        .stroke(
                            isHovered ? theme.accent.opacity(0.5) : theme.primaryBorder,
                            lineWidth: isHovered ? 1 : 0.5
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .help(direction == .left ? "Collapse sidebar" : "Expand sidebar")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    MaxViewScreen()
        .environmentObject(NavigationState())
        .frame(width: 1440, height: 1062)
}
