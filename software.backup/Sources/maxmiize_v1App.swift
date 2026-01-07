//
//  maxmiize_v1App.swift
//  maxmiize-v1
//
//  Created by John Niyontwali on 20/11/2025.
//

import SwiftUI
import AppKit

@main
struct maxmiize_v1App: App {
    @StateObject private var navigationState = NavigationState()
    @State private var showingSettings = false
    @State private var recentProjects: [AnalysisProject] = []

    init() {
        // Setup audio configuration for video playback
        setupAudioConfiguration()

        // Test C++ integration on app startup
        VideoEngineTest.runTests()
    }

    var body: some Scene {
        WindowGroup("Maxmiize") {
            ContentView()
                .environmentObject(navigationState)
                .environmentObject(ThemeManager.shared)
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                        .environmentObject(ThemeManager.shared)
                }
                .task {
                    // Load recent projects asynchronously to avoid blocking UI
                    recentProjects = ProjectManager.shared.getRecentProjects(limit: 10)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1440, height: 910)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Settings...") {
                    showingSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) {
                Button("Create New Analysis") {
                    Task { @MainActor in
                        await navigationState.navigate(to: .createAnalysisWizard)
                    }
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Open Analysis...") {
                    openAnalysisPicker()
                }
                .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    ForEach(recentProjects) { project in
                        Button(project.title) {
                            navigationState.openProject(id: project.id)
                        }
                    }

                    if recentProjects.isEmpty {
                        Text("No Recent Projects")
                            .foregroundColor(.secondary)
                    }
                }
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    navigationState.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }

    private func setupAudioConfiguration() {
        // macOS audio setup - ensure proper audio routing for video playback
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                SyncedVideoPlayerManager.shared.restoreAudioSession()
            }
        }

        print("✅ Audio configuration setup complete")
    }

    private func openAnalysisPicker() {
        let panel = NSOpenPanel()
        panel.message = "Select an analysis project folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        panel.begin { response in
            if response == .OK {
                // Handle opening the selected analysis folder
                // For now, just navigate to home
                Task { @MainActor in
                    await navigationState.navigate(to: .home)
                }
            }
        }
    }
}
