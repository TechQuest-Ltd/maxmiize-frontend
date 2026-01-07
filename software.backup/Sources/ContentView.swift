//
//  ContentView.swift
//  maxmiize-v1
//
//  Created by John Niyontwali on 20/11/2025.
//

import SwiftUI

// Custom button style to remove all backgrounds and borders
struct CleanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct ContentView: View {
    @EnvironmentObject var navigationState: NavigationState
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var autoSaveManager = AutoSaveManager.shared
    @State private var showSettings: Bool = false
    @State private var showExportSheet: Bool = false

    // Determine if toolbar should be shown
    private var shouldShowToolbar: Bool {
        switch navigationState.currentScreen {
        case .home, .createAnalysisWizard:
            return false
        default:
            return true
        }
    }

    var body: some View {
        ZStack {
            switch navigationState.currentScreen {
            case .home:
                HomeScreenView()
            case .createAnalysisWizard:
                CreateAnalysisWizardView()
            case .maxView:
                MaxViewScreen()
            case .tagging:
                MomentsView()
            case .moments:
                MomentsView()
            case .playback:
                PlaybackView()
            case .notes:
                NotesView()
            case .playlist:
                PlaylistView()
            case .annotation:
                AnnotationView()
            case .sorter:
                SorterView()
            case .codeWindow:
                CodeWindowView()
            case .blueprints, .templates:
                BlueprintEditorView()
            case .rosterManagement:
                RosterManagementView()
            case .liveCapture:
                PlaceholderView(title: "Live Capture", icon: "record.circle")
            }
        }
        .id(navigationState.refreshTrigger)
        .toolbar {
            if shouldShowToolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    // Logo - use light logo in light mode, dark logo in dark mode
                    Image(themeManager.isLightMode ? "LightLogo" : "LongLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)

                    // Divider
                    Rectangle()
                        .fill(themeManager.colors.primaryBorder)
                        .frame(width: 1, height: 14)

                    // Home button
                    Button(action: {
                        Task { @MainActor in
                            await navigationState.navigate(to: .home)
                        }
                    }) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 13))
                            .foregroundColor(themeManager.colors.secondaryText)
                    }
                    .buttonStyle(CleanButtonStyle())
                    .help("Home")

                    // Divider
                    Rectangle()
                        .fill(themeManager.colors.primaryBorder)
                        .frame(width: 1, height: 14)

                    // Project info
                    if let project = navigationState.currentProject {
                        if let thumbnail = project.thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }

                        Text(project.displayTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.colors.primaryText)
                    }
                }
                .padding(.horizontal, 16)
                .background(Color.clear)
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(themeManager.colors.success)
                        .frame(width: 6, height: 6)

                    Text("Auto-Saved • " + autoSaveManager.lastSavedText)
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.colors.tertiaryText)
                }
                .padding(.horizontal, 16)
                .background(Color.clear)
            }

            ToolbarItemGroup(placement: .automatic) {
                HStack(spacing: 12) {
                    Button(action: {}) {
                        ZStack {
                            Circle()
                                .fill(themeManager.colors.accent)
                                .frame(width: 20, height: 20)
                            
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color.white)
                        }
                        .frame(width: 20, height: 20)
                    }
                    .buttonStyle(CleanButtonStyle())
                    .help("Import")

                    Button(action: { showExportSheet = true }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.colors.secondaryText)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(CleanButtonStyle())
                    .help("Export")

                    Button(action: {}) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.colors.secondaryText)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(CleanButtonStyle())
                    .help("Layouts")

                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.colors.secondaryText)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(CleanButtonStyle())
                    .help("Settings")
                }
                .padding(.leading, 16)
                .padding(.trailing, 16)
                .background(Color.clear)
            }
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet()
        }
    }
}

// Placeholder view for screens not yet implemented
struct PlaceholderView: View {
    @EnvironmentObject var navigationState: NavigationState
    let title: String
    let icon: String
    
    var theme: ThemeColors {
        ThemeManager.shared.colors
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(theme.tertiaryText)

            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(theme.primaryText)

            Text("Coming Soon")
                .font(.system(size: 18))
                .foregroundColor(theme.tertiaryText)

            Button(action: {
                Task { @MainActor in
                    await navigationState.navigate(to: .home)
                }
            }) {
                HStack {
                    Image(systemName: "house.fill")
                        .font(.system(size: 12))
                    Text("Go Home")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(theme.accent)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.primaryBackground)
    }
}

#Preview {
    ContentView()
        .environmentObject(NavigationState())
        .environmentObject(ThemeManager.shared)
        .frame(width: 1440, height: 910)
}
