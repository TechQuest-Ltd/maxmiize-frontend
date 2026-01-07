//
//  CreateAnalysisWizardView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CreateAnalysisWizardView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var wizardState = WizardState()
    @State private var showModal = false
    @State private var modalType: ModalType = .success
    @State private var modalTitle = ""
    @State private var modalMessage = ""
    @State private var modalButtons: [ModalButton] = []
    @State private var isCreatingProject = false
    @ObservedObject private var themeManager = ThemeManager.shared

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Section
                headerSection

                // Step Content
                ScrollView {
                    HStack(spacing: 0) {
                        Spacer()
                            .frame(width: 72) // Match header padding

                        stepContent

                        Spacer()
                    }
                    .padding(.top, 32)
                }
                .frame(maxHeight: .infinity)
            }

            // Modal overlay
            CustomModal(
                isPresented: $showModal,
                type: modalType,
                title: modalTitle,
                message: modalMessage,
                buttons: modalButtons
            )
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo and Title
            HStack(spacing: 16) {
                // Logo
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)

                Text("Create New Analysis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }
            .padding(.horizontal, 72)
            .padding(.top, 48)

            // Step Indicators
            HStack(spacing: 170) {
                ForEach(WizardStep.allCases, id: \.rawValue) { step in
                    StepIndicator(
                        step: step,
                        currentStep: wizardState.currentStep
                    )
                }
            }
            .padding(.horizontal, 72)
            .padding(.top, 42)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 31)
    }

    // MARK: - Step Content
    @ViewBuilder
    private var stepContent: some View {
        switch wizardState.currentStep {
        case .analysisDetails:
            AnalysisDetailsStep(wizardState: wizardState)
        case .importVideos:
            ImportVideosStep(wizardState: wizardState)
        case .templateRoster:
            TemplateRosterStep(
                wizardState: wizardState,
                isCreatingProject: $isCreatingProject,
                onCreateProject: handleCreateProject
            )
        }
    }

    // MARK: - Actions
    private func handleCreateProject() {
        isCreatingProject = true

        let result = wizardState.saveProject()

        isCreatingProject = false

        switch result {
        case .success(let projectId):
            print("✅ Project created with ID: \(projectId)")

            // Get the project bundle that was just created
            guard let bundle = ProjectManager.shared.currentProject else {
                print("❌ Project bundle not found after creation")
                return
            }

            // Get thumbnail from bundle if available
            var thumbnailImage: NSImage?
            let thumbnailsDir = bundle.thumbnailsPath
            if let firstThumbnail = try? FileManager.default.contentsOfDirectory(at: thumbnailsDir, includingPropertiesForKeys: nil).first {
                thumbnailImage = NSImage(contentsOf: firstThumbnail)
            }
            // Set current project in navigation state
            navigationState.currentProject = OpenedProject(
                id: projectId,
                name: bundle.name,
                sport: bundle.sport,
                season: bundle.season,
                thumbnail: thumbnailImage
            )

            // Reset wizard state for next project
            wizardState.resetWizard()

            // Navigate directly to MaxView to show the project
            Task { @MainActor in
                await navigationState.navigate(to: .maxView)
            }

        case .failure(let error):
            // Error with detailed message
            modalType = .error
            modalTitle = "Failed to Create Project"
            modalMessage = error.localizedDescription
            modalButtons = [
                ModalButton(title: "OK", style: .primary) {
                    showModal = false
                }
            ]
            showModal = true
        }
    }

}

// MARK: - Step Indicator Component
struct StepIndicator: View {
    let step: WizardStep
    let currentStep: WizardStep

    private var stepState: StepState {
        if step.rawValue < currentStep.rawValue {
            return .completed
        } else if step == currentStep {
            return .active
        } else {
            return .inactive
        }
    }

    private enum StepState {
        case completed
        case active
        case inactive

        func borderColor(theme: ThemeColors) -> Color {
            switch self {
            case .completed: return theme.success
            case .active: return theme.accent
            case .inactive: return theme.secondaryBorder
            }
        }

        func textColor(theme: ThemeColors) -> Color {
            switch self {
            case .completed: return theme.success
            case .active: return theme.accent
            case .inactive: return theme.tertiaryText
            }
        }

        func titleColor(theme: ThemeColors) -> Color {
            switch self {
            case .completed: return .white
            case .active: return theme.tertiaryText
            case .inactive: return theme.tertiaryText
            }
        }
    }
    
    @ObservedObject private var themeManager = ThemeManager.shared

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 0) {
            // Step Number Circle
            ZStack {
                Circle()
                    .stroke(stepState.borderColor(theme: theme), lineWidth: 1)
                    .frame(width: 22, height: 22)

                Text("\(step.rawValue)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(stepState.textColor(theme: theme))
            }
            .frame(width: 22, height: 22)

            // Step Title and Subtitle
            VStack(alignment: .leading, spacing: 0) {
                Text(step.title)
                    .font(.system(size: 13, weight: step == currentStep || stepState == .completed ? .semibold : .semibold))
                    .foregroundColor(stepState.titleColor(theme: theme))

                Text(step.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(.leading, 10)
        }
    }
}

// MARK: - Analysis Details Step
struct AnalysisDetailsStep: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var wizardState: WizardState
    @EnvironmentObject var navigationState: NavigationState

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 24) {
            // Main Card
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step 1 — Analysis Details")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("Define the core information for this analysis session.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)
                }

                // Analysis Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analysis Name")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    CustomTextField(
                        label: "Analysis Name",
                        placeholder: "Enter Analysis name",
                        text: $wizardState.analysisName
                    )
                }

                // Sport
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sport")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Picker(selection: $wizardState.sport, label: EmptyView()) {
                        Text("Select sport")
                            .tag("")
                        Text("Basketball")
                            .tag("Basketball")
                        Text("Football")
                            .tag("Football")
                        Text("Soccer")
                            .tag("Soccer")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .overlay(
                        HStack {
                            Text("SF")
                                .font(.system(size: 14))
                                .foregroundColor(theme.tertiaryText)
                                .frame(width: 18, height: 18)
                                .background(theme.secondaryBackground)
                                .cornerRadius(4)
                                .padding(.trailing, 8)

                            Text(wizardState.sport.isEmpty ? "Select sport" : wizardState.sport)
                                .font(.system(size: 14))
                                .foregroundColor(wizardState.sport.isEmpty ? theme.tertiaryText : .white)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)
                        }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(theme.surfaceBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.secondaryBorder, lineWidth: 1)
                            )
                            .allowsHitTesting(false)
                    )
                }

                // Competition / Season
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Competition / Season")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Text("Optional")
                            .font(.system(size: 13))
                            .foregroundColor(theme.tertiaryText)
                    }

                    CustomTextField(
                        label: "Competition / Season",
                        placeholder: "Add competition or season name",
                        text: $wizardState.competition
                    )
                }

                // Save Location
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Save Location")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Text("Optional")
                            .font(.system(size: 13))
                            .foregroundColor(theme.tertiaryText)
                    }

                    HStack(spacing: 8) {
                        // Current location display
                        Text(wizardState.saveLocationName)
                            .font(.system(size: 14))
                            .foregroundColor(theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(theme.surfaceBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.secondaryBorder, lineWidth: 1)
                            )

                        // Choose button
                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            panel.message = "Choose where to save your project"
                            panel.prompt = "Choose"

                            panel.begin { response in
                                if response == .OK, let url = panel.url {
                                    wizardState.saveLocation = url
                                    wizardState.saveLocationName = url.lastPathComponent
                                }
                            }
                        }) {
                            Text("Choose...")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(theme.accent)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Spacer()

                // Buttons inside container
                HStack(spacing: 12) {
                    Button(action: {
                        Task { @MainActor in
                            await navigationState.navigate(to: .home)
                        }
                    }) {
                        Text("Back")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(theme.primaryBackground)
                            .cornerRadius(48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 48)
                                    .stroke(theme.secondaryBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: {
                        wizardState.nextStep()
                    }) {
                        Text("Next")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                            .padding(.horizontal, 44)
                            .padding(.vertical, 10)
                            .background(wizardState.canGoNext() ? theme.accent : theme.secondaryBorder)
                            .cornerRadius(125)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!wizardState.canGoNext())
                }
                .padding(.top, 48)
            }
            .padding(32)
            .frame(width: 890)
            .background(theme.surfaceBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )

            // Inspector Sidebar
            VStack(alignment: .leading, spacing: 12) {
                Text("Inspector")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("Additional settings for this step can appear here when needed.")
                    .font(.system(size: 13))
                    .foregroundColor(theme.tertiaryText)
                    .lineSpacing(4)

                Spacer()
            }
            .padding(24)
            .frame(width: 330)
            .background(theme.surfaceBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )

            Spacer()
        }
        .padding(.trailing, 72)
    }
}

// MARK: - Import Videos Step
struct ImportVideosStep: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var wizardState: WizardState

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.message = "Select video files to import"

        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    wizardState.addVideo(url: url)
                }
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < wizardState.angleAssignments.count else { return "" }
                return wizardState.angleAssignments[index]
            },
            set: { newValue in
                guard index < wizardState.angleAssignments.count else { return }
                wizardState.angleAssignments[index] = newValue
            }
        )
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 24) {
            // Left Panel - Main content
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step 2 — Import Videos")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("Add one or multiple games with any number of camera angles.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                        .padding(.top, 4)

                    // Import mode section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Import mode")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(theme.primaryText)
                            .padding(.top, 12)

                        CustomRadioButtonGroup(
                            selectedIndex: $wizardState.selectedMode,
                            options: ["Single Game (multi-angle)", "Multiple Games", "Combine Games"]
                        )
                    }

                    // Video Import Mode section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Video File Handling")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(theme.primaryText)
                            .padding(.top, 12)

                        // Copy Mode
                        Button(action: {
                            wizardState.videoImportMode = .copy
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                // Radio button
                                ZStack {
                                    Circle()
                                        .fill(wizardState.videoImportMode == .copy ? theme.accent : Color.clear)
                                        .frame(width: 16, height: 16)
                                    Circle()
                                        .stroke(wizardState.videoImportMode == .copy ? theme.accent : theme.secondaryBorder, lineWidth: 2)
                                        .frame(width: 16, height: 16)
                                }
                                .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Copy")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(theme.primaryText)

                                    Text("Copy videos into project (original files remain)")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(theme.tertiaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(wizardState.videoImportMode == .copy ? theme.primaryBackground : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(wizardState.videoImportMode == .copy ? theme.accent.opacity(0.3) : theme.secondaryBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Move Mode
                        Button(action: {
                            wizardState.videoImportMode = .move
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                // Radio button
                                ZStack {
                                    Circle()
                                        .fill(wizardState.videoImportMode == .move ? theme.accent : Color.clear)
                                        .frame(width: 16, height: 16)
                                    Circle()
                                        .stroke(wizardState.videoImportMode == .move ? theme.accent : theme.secondaryBorder, lineWidth: 2)
                                        .frame(width: 16, height: 16)
                                }
                                .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Move")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(theme.primaryText)

                                    Text("Move videos into project (original files removed)")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(theme.tertiaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(wizardState.videoImportMode == .move ? theme.primaryBackground : Color.clear)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(wizardState.videoImportMode == .move ? theme.accent.opacity(0.3) : theme.secondaryBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                // Drag and Drop Area
                Button(action: {
                    openFilePicker()
                }) {
                    VStack(spacing: 4) {
                        Text("Drag videos here")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.primaryText)

                        Text("Supports multiple games, angles, matchdays, training sessions")
                            .font(.system(size: 14))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 41)
                    .padding(.horizontal, 25)
                    .background(theme.primaryBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(theme.secondaryBorder)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // Imported Videos List
                VStack(spacing: 10) {
                    ForEach(wizardState.importedVideos) { video in
                        VideoFileRow(video: video) {
                            wizardState.removeVideo(id: video.id)
                        }
                    }
                }
                .padding(.top, 8)

                Spacer()

                // Buttons inside container
                HStack(spacing: 12) {
                    if wizardState.currentStep.rawValue > 1 {
                        Button(action: {
                            wizardState.previousStep()
                        }) {
                            Text("Back")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 10)
                                .background(theme.primaryBackground)
                                .cornerRadius(43)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 43)
                                        .stroke(theme.secondaryBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    Button(action: {
                        wizardState.nextStep()
                    }) {
                        Text("Next")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.white)
                            .padding(.horizontal, 44)
                            .padding(.vertical, 10)
                            .background(theme.accent)
                            .cornerRadius(125)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 48)
            }
            .padding(25)
            .frame(width: 796)
            .background(theme.surfaceBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )

            // Right Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Angle Assignment
                VStack(alignment: .leading, spacing: 12) {
                    CustomLabel("Angle Assignment")
                 
                    VStack(spacing: 12) {
                        ForEach(Array(wizardState.importedVideos.enumerated()), id: \.element.id) { index, video in
                            VStack(alignment: .leading, spacing: 8) {
                                CustomLabel(
                                    video.name,
                                    size: 12,
                                    weight: .semibold,
                                    color: theme.tertiaryText
                                )
                                .frame(maxWidth: .infinity, alignment: .leading).padding(10)

                                CustomDropdown(
                                    label: "",
                                    selectedValue: binding(for: index),
                                    options: CameraAngle.allCases.map { $0.displayName },
                                    placeholder: "Select angle"
                                )
                            }
                        }
                    }
                }
                .padding(.bottom, 24)

                // Game Options
                VStack(alignment: .leading, spacing: 12) {
                    CustomLabel("Game Options")

                    VStack(alignment: .leading, spacing: 8) {
                        CustomCheckbox(isChecked: $wizardState.addToCombinedTimeline, label: "Add this game to Combined Timeline")
                        CustomCheckbox(isChecked: $wizardState.keepAsOwnTimeline, label: "Keep this game as its Own Timeline")
                    }
                }
                .padding(.bottom, 24)

                // Global Timeline Settings
                VStack(alignment: .leading, spacing: 12) {
                    CustomLabel("GLOBAL TIMELINE SETTINGS", size: 13, weight: .semibold, color: .white)

                    VStack(alignment: .leading, spacing: 8) {
                        CustomCheckbox(isChecked: $wizardState.placeGamesSequentially, label: "Place games sequentially")

                        CustomLabel(
                            "(Game 1 → Game 2 → Game 3)",
                            size: 13,
                            weight: .semibold,
                            color: theme.tertiaryText
                        )
                        .padding(.leading, 20)

                        CustomCheckbox(isChecked: $wizardState.keepGamesSeparate, label: "Keep games separate but switchable (tabs in analysis mode)")

                        CustomCheckbox(isChecked: $wizardState.mergeAllGames, label: "Merge all games into one unified dataset")
                    }
                }

                Spacer()
            }
            .padding(21)
            .frame(width: 300)
            .background(theme.surfaceBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )
        }
    }
}

// MARK: - Video File Row
struct VideoFileRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let video: VideoFile
    var onRemove: (() -> Void)? = nil

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let thumbnail = video.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 28)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.primaryBackground)
                        .frame(width: 48, height: 28)
                        .overlay(
                            Image(systemName: "video.fill")
                                .font(.system(size: 12))
                                .foregroundColor(theme.tertiaryText)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(video.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(video.duration)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            // Remove button
            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(theme.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Remove video")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(theme.primaryBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.secondaryBorder, lineWidth: 1)
        )
    }
}

// MARK: - Template & Roster Step
struct TemplateRosterStep: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var wizardState: WizardState
    @EnvironmentObject var navigationState: NavigationState
    @Binding var isCreatingProject: Bool
    let onCreateProject: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 24) {
            // Main Card
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Step 3 — Template & Roster")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("Choose your analysis structure and attach the squad list.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.tertiaryText)
                }

                // Template Options
                VStack(spacing: 12) {
                    // Use Default Template
                    Button(action: { wizardState.selectedTemplate = 0 }) {
                        HStack(alignment: .top, spacing: 10) {
                            // Radio button
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(wizardState.selectedTemplate == 0 ? theme.success : Color.clear)
                                    .frame(width: 16, height: 16)
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(wizardState.selectedTemplate == 0 ? theme.success : theme.secondaryBorder, lineWidth: 1)
                                    .frame(width: 16, height: 16)
                            }
                            .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Default Template")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.primaryText)

                                Text("Standard tagging structure for this sport.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.primaryBackground)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.secondaryBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Build Template from Scratch
                    Button(action: { wizardState.selectedTemplate = 1 }) {
                        HStack(alignment: .top, spacing: 10) {
                            // Radio button
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(wizardState.selectedTemplate == 1 ? theme.success : Color.clear)
                                    .frame(width: 16, height: 16)
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(wizardState.selectedTemplate == 1 ? theme.success : theme.secondaryBorder, lineWidth: 1)
                                    .frame(width: 16, height: 16)
                            }
                            .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Build Template from Scratch (New)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.primaryText)

                                Text("Create your own tags, labels, categories, and naming structure.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.primaryBackground)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.secondaryBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Choose Existing Template
                    Button(action: { wizardState.selectedTemplate = 2 }) {
                        HStack(alignment: .top, spacing: 10) {
                            // Radio button
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(wizardState.selectedTemplate == 2 ? theme.success : Color.clear)
                                    .frame(width: 16, height: 16)
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(wizardState.selectedTemplate == 2 ? theme.success : theme.secondaryBorder, lineWidth: 1)
                                    .frame(width: 16, height: 16)
                            }
                            .padding(.top, 4)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Choose Existing Template")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.primaryText)

                                Text("Load a saved template from previous projects.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.primaryBackground)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(theme.secondaryBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)

                Spacer()

                // Buttons inside container
                HStack(spacing: 12) {
                    Button(action: {
                        wizardState.previousStep()
                    }) {
                        Text("Back")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(theme.primaryBackground)
                            .cornerRadius(48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 48)
                                    .stroke(theme.secondaryBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: {
                        onCreateProject()
                    }) {
                        HStack(spacing: 8) {
                            if isCreatingProject {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isCreatingProject ? "Creating..." : "Create Project")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.primaryText)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(isCreatingProject ? theme.accent.opacity(0.7) : theme.accent)
                        .cornerRadius(40)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCreatingProject)
                }
                .padding(.top, 16)
            }
            .padding(25)
            .frame(width: 796)
            .background(theme.surfaceBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )

            // Right Sidebar - Roster
            VStack(alignment: .leading, spacing: 16) {
                CustomLabel("Roster")

                VStack(alignment: .leading, spacing: 10) {
                    // Attach Roster Checkbox
                    CustomCheckbox(
                        isChecked: $wizardState.attachRoster,
                        label: "Attach Roster"
                    )

                    // Import CSV Button
                    Button(action: {}) {
                        Text("Import CSV")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(theme.primaryBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(theme.secondaryBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()
            }
            .padding(21)
            .padding(.leading, 19)
            .frame(width: 300)
            .background(theme.surfaceBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )
        }
    }
}

struct TemplateOption: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(isSelected ? theme.accent : Color.clear)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? theme.accent : theme.tertiaryText, lineWidth: 2)
                    )

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(theme.primaryText)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? theme.surfaceBackground : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CreateAnalysisWizardView()
        .environmentObject(NavigationState())
        .frame(width: 1440, height: 900)
}
