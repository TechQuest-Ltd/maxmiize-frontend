//
//  HomeScreenView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HomeScreenView: View {
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var recentProjects: [AnalysisProject] = []
    @State private var showSettings: Bool = false
    
    var theme: ThemeColors {
        themeManager.colors
    }

    private func loadRecentProjects() {
        Task { @MainActor in
            recentProjects = ProjectManager.shared.getRecentProjects()
        }
    }

    private func removeProject(_ projectId: String) {
        let result = ProjectManager.shared.removeProject(projectId: projectId)

        switch result {
        case .success:
            print("✅ Project removed successfully")
            // Refresh the recent projects list
            loadRecentProjects()

        case .failure(let error):
            print("❌ Failed to remove project: \(error.localizedDescription)")

            // Show error alert
            let alert = NSAlert()
            alert.messageText = "Failed to Delete Project"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func openAnalysisFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select a .proj bundle to open"
        panel.prompt = "Open"

        // Filter to only show .proj bundles
        panel.allowedContentTypes = [UTType(filenameExtension: "proj")!]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                print("📂 Opening project bundle from: \(url.path)")

                // Open project using ProjectManager
                let result = ProjectManager.shared.openProject(at: url)

                switch result {
                case .success(let bundle):
                    print("✅ Successfully opened project: \(bundle.name)")

                    // Get thumbnail from bundle
                    var thumbnailImage: NSImage?
                    let thumbnailsDir = bundle.thumbnailsPath
                    if let firstThumbnail = try? FileManager.default.contentsOfDirectory(at: thumbnailsDir, includingPropertiesForKeys: nil).first {
                        thumbnailImage = NSImage(contentsOf: firstThumbnail)
                    }

                    // Update navigation state with opened project
                    navigationState.currentProject = OpenedProject(
                        id: bundle.projectId,
                        name: bundle.name,
                        sport: bundle.sport,
                        season: bundle.season,
                        thumbnail: thumbnailImage
                    )

                    // Navigate to MaxView
                    Task { @MainActor in
                        await navigationState.navigate(to: .maxView)
                    }

                case .failure(let error):
                    print("❌ Failed to open project: \(error.localizedDescription)")

                    // Show error alert
                    let alert = NSAlert()
                    alert.messageText = "Failed to Open Project"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    private func importAnalysisFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.zip, .package]
        panel.message = "Select an analysis package file to import"
        panel.prompt = "Import"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                print("Importing analysis from: \(url.path)")
                // TODO: Import and extract analysis package
            }
        }
    }

    var body: some View {
        ZStack {
            // Background - extend to all edges
            theme.primaryBackground
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Main Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        // Header Section
                        headerSection

                        // Action Cards
                        actionCardsSection

                        // Recent Analysis Section
                        recentAnalysisSection
                    }
                    .frame(maxWidth: 920)
                    .padding(.top, 48)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Footer
                footerSection
            }
            .padding(.horizontal, 72)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.primaryBackground.ignoresSafeArea(.all))
        .ignoresSafeArea(.all, edges: .top)
        .hideTitlebarSeparator(backgroundColor: theme.primaryBackground)
        .onAppear {
            loadRecentProjects()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Logo
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)

            // Title
            Text("Welcome to Maxmiize")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(theme.primaryText)

            // Subtitle
            Text("Start a new analysis or jump back into your recent projects.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.tertiaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Action Cards Section
    private var actionCardsSection: some View {
        HStack(spacing: 36) {
            ActionCard(
                icon: "plus",
                title: "New Analysis",
                subtitle: "Create a new analysis session",
                action: {
                    Task { @MainActor in
                        await navigationState.navigate(to: .createAnalysisWizard)
                    }
                }
            )

            ActionCard(
                icon: "folder.fill",
                title: "Open Analysis",
                subtitle: "Access previously saved sessions",
                action: { openAnalysisFilePicker() }
            )

            ActionCard(
                icon: "link",
                title: "Import Analysis File",
                subtitle: "Import external packages",
                action: { importAnalysisFilePicker() }
            )
        }
        .frame(height: 167)
    }

    // MARK: - Recent Analysis Section
    private var recentAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Analysis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryText)

            if recentProjects.isEmpty {
                VStack(spacing: 8) {
                    Text("No recent analysis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)

                    Text("Create a new analysis or open an existing project to get started")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(theme.surfaceBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.secondaryBorder, lineWidth: 1)
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(recentProjects) { project in
                        RecentAnalysisRow(project: project) {
                            removeProject(project.id)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 1152)
        .padding(.top, 12)
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 0) {
            // Removed divider line

            HStack {
                // Preferences Button
                Button(action: {
                    print("⚙️ Opening settings...")
                    showSettings = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))

                        Text("Preferences")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(theme.surfaceBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(theme.secondaryBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                // Status Badge
                Text("Licensed • Offline Ready")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(theme.success)
                    .cornerRadius(999)
            }
            .padding(.top, 17)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    HomeScreenView()
        .environmentObject(NavigationState())
        .environmentObject(ThemeManager.shared)
        .frame(width: 1440, height: 910)
}
