//
//  ExportSheet.swift
//  maxmiize-v1
//
//  Created by TechQuest on 04/01/2026.
//

import SwiftUI

struct ExportSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject var exportManager = ExportManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var exportOptions = ExportOptions()
    @State private var selectedClips: [Clip] = []
    @State private var allClips: [Clip] = []
    @State private var allMoments: [Moment] = []
    @State private var exportDestination: String = "Desktop"
    @State private var exportedFilePath: String = ""
    @State private var showSuccessMessage: Bool = false
    @State private var showErrorMessage: Bool = false
    @State private var errorText: String = ""

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                header

                if exportManager.isExporting {
                    // Progress view
                    exportProgressView
                } else if showSuccessMessage {
                    // Success view
                    successView
                } else if showErrorMessage {
                    // Error view
                    errorView
                } else {
                    // Options view
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            formatSection
                            contentSection

                            if exportOptions.format == .video {
                                videoOptionsSection
                            }

                            destinationSection
                            advancedSection
                        }
                        .padding(20)
                    }

                    // Footer buttons
                    footer
                }
            }
            .frame(width: 520, height: getModalHeight())
            .background(theme.primaryBackground)
        }
        .onAppear {
            loadData()
        }
        .onChange(of: exportManager.progress.isComplete) { isComplete in
            if isComplete {
                handleExportComplete()
            }
        }
    }

    private func getModalHeight() -> CGFloat {
        if exportManager.isExporting {
            return 220
        } else if showSuccessMessage || showErrorMessage {
            return 260
        } else {
            return 580
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(theme.accent)

            Text("Export")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.tertiaryText)
                    .frame(width: 22, height: 22)
                    .background(theme.secondaryBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(theme.secondaryBackground)
    }

    // MARK: - Format Section

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Format")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                ForEach(VideoExportFormat.allCases, id: \.self) { format in
                    FormatOptionCard(
                        format: format,
                        isSelected: exportOptions.format == format,
                        onTap: { exportOptions.format = format }
                    )
                }
            }
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Content")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                ForEach(ExportContent.allCases, id: \.self) { content in
                    ContentOptionRow(
                        content: content,
                        isSelected: exportOptions.content == content,
                        count: getContentCount(for: content),
                        onTap: { exportOptions.content = content }
                    )
                }
            }
        }
    }

    // MARK: - Video Options Section

    private var videoOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(theme.primaryBorder)

            // Quality
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
                    .textCase(.uppercase)

                HStack(spacing: 6) {
                    ForEach(VideoQuality.allCases, id: \.self) { quality in
                        QualityButton(
                            quality: quality,
                            isSelected: exportOptions.videoQuality == quality,
                            onTap: { exportOptions.videoQuality = quality }
                        )
                    }
                }
            }

            // Layout
            VStack(alignment: .leading, spacing: 8) {
                Text("Layout")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.secondaryText)
                    .textCase(.uppercase)

                HStack(spacing: 6) {
                    ForEach(VideoLayout.allCases, id: \.self) { layout in
                        LayoutButton(
                            layout: layout,
                            isSelected: exportOptions.videoLayout == layout,
                            onTap: { exportOptions.videoLayout = layout }
                        )
                    }
                }
            }

            // Merge clips option
            if exportOptions.content == .selectedClips || exportOptions.content == .allClips {
                CompactToggle(
                    isOn: $exportOptions.mergeClips,
                    label: "Merge into single video",
                    icon: "film.stack"
                )
            }
        }
    }

    // MARK: - Destination Section

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .background(theme.primaryBorder)

            Text("Save To")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .textCase(.uppercase)

            Button(action: chooseDestination) {
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)

                    Text(exportDestination)
                        .font(.system(size: 13))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.secondaryBackground)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .background(theme.primaryBorder)

            Text("Options")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.secondaryText)
                .textCase(.uppercase)

            VStack(spacing: 8) {
                if exportOptions.format == .video {
                    CompactToggle(
                        isOn: $exportOptions.includeOverlays,
                        label: "Include overlays",
                        icon: "photo.stack"
                    )
                }

                CompactToggle(
                    isOn: $exportOptions.includeTimecodes,
                    label: "Include timecodes",
                    icon: "clock"
                )

                CompactToggle(
                    isOn: $exportOptions.includeNotes,
                    label: "Include notes",
                    icon: "note.text"
                )

                if exportOptions.mergeClips {
                    CompactToggle(
                        isOn: $exportOptions.addTransitions,
                        label: "Add transitions",
                        icon: "wand.and.stars"
                    )
                }
            }
        }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(theme.success.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 38))
                        .foregroundColor(theme.success)
                }

                VStack(spacing: 4) {
                    Text("Export Complete")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("Your files have been saved successfully")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                }
            }

            Spacer()

            // Buttons
            HStack(spacing: 10) {
                Button(action: {
                    // Reveal in Finder - use the exported file path if available, otherwise the destination folder
                    let pathToReveal = exportedFilePath.isEmpty ? exportDestination : exportedFilePath
                    if FileManager.default.fileExists(atPath: pathToReveal) {
                        NSWorkspace.shared.selectFile(pathToReveal, inFileViewerRootedAtPath: URL(fileURLWithPath: pathToReveal).deletingLastPathComponent().path)
                    } else {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: exportDestination)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))

                        Text("Show in Finder")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(theme.secondaryBackground)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(theme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                // Error icon
                ZStack {
                    Circle()
                        .fill(theme.error.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 38))
                        .foregroundColor(theme.error)
                }

                VStack(spacing: 4) {
                    Text("Export Failed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text(errorText.isEmpty ? "An error occurred during export" : errorText)
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // Buttons
            HStack(spacing: 10) {
                Button(action: {
                    showErrorMessage = false
                }) {
                    Text("Try Again")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(theme.secondaryBackground)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { dismiss() }) {
                    Text("Close")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(theme.error)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
    }

    // MARK: - Progress View

    private var exportProgressView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Progress indicator
            VStack(spacing: 14) {
                ProgressView(value: exportManager.progress.percentage)
                    .progressViewStyle(.linear)
                    .tint(theme.accent)
                    .frame(maxWidth: 320)

                VStack(spacing: 4) {
                    Text(exportManager.progress.currentPhase)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(theme.primaryText)

                    Text("\(Int(exportManager.progress.percentage * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                }
            }

            Spacer()

            // Cancel button
            Button(action: {
                exportManager.cancel()
                dismiss()
            }) {
                Text("Cancel")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 7)
                    .background(theme.secondaryBackground)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Info text
            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Text(getExportInfo())
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            // Buttons
            HStack(spacing: 10) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(theme.secondaryBackground)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: startExport) {
                    Text("Export")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(theme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(theme.secondaryBackground)
    }

    // MARK: - Helper Functions

    private func loadData() {
        // Load clips and moments from database
        if let projectId = navigationState.currentProject?.id {
            allClips = DatabaseManager.shared.getClips(gameId: projectId)
            allMoments = DatabaseManager.shared.getMoments(gameId: projectId)
        }

        // Set default destination
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            exportDestination = desktopURL.path
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose export destination"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                exportDestination = url.path
            }
        }
    }

    private func getContentCount(for content: ExportContent) -> Int {
        switch content {
        case .selectedClips:
            return selectedClips.count
        case .allClips:
            return allClips.count
        case .currentMoments:
            return allMoments.filter { $0.isActive }.count
        case .allMoments:
            return allMoments.count
        case .timeline:
            return 1
        case .fullGame:
            return 1
        }
    }

    private func getExportInfo() -> String {
        let count = getContentCount(for: exportOptions.content)
        switch exportOptions.content {
        case .selectedClips:
            return "\(count) clip\(count == 1 ? "" : "s") selected"
        case .allClips:
            return "\(count) clip\(count == 1 ? "" : "s") total"
        case .currentMoments, .allMoments:
            return "\(count) moment\(count == 1 ? "" : "s")"
        case .timeline:
            return "Timeline data"
        case .fullGame:
            return "Full game"
        }
    }

    private func startExport() {
        guard let projectId = navigationState.currentProject?.id else { return }

        let clipsToExport: [Clip]
        switch exportOptions.content {
        case .selectedClips:
            clipsToExport = selectedClips
        case .allClips:
            clipsToExport = allClips
        default:
            clipsToExport = []
        }

        let momentsToExport: [Moment]
        switch exportOptions.content {
        case .currentMoments:
            momentsToExport = allMoments.filter { $0.isActive }
        case .allMoments:
            momentsToExport = allMoments
        default:
            momentsToExport = []
        }

        // Reset success/error states
        showSuccessMessage = false
        showErrorMessage = false
        errorText = ""

        exportManager.exportWithOptions(exportOptions, clips: clipsToExport, moments: momentsToExport, projectId: projectId)
    }

    private func handleExportComplete() {
        if let error = exportManager.progress.error {
            // Export failed
            errorText = error.localizedDescription
            showErrorMessage = true
            showSuccessMessage = false
        } else {
            // Export succeeded
            // Store the exported file path (use export destination for now)
            exportedFilePath = exportDestination
            showSuccessMessage = true
            showErrorMessage = false
        }
    }
}

// MARK: - Format Option Card

struct FormatOptionCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let format: VideoExportFormat
    let isSelected: Bool
    let onTap: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: format.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? theme.accent : theme.secondaryText)

                Text(format.rawValue.components(separatedBy: " ").first ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? theme.primaryText : theme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? theme.accent.opacity(0.12) : theme.secondaryBackground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Content Option Row

struct ContentOptionRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let content: ExportContent
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? theme.accent : theme.tertiaryText)

                Text(content.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(theme.tertiaryBackground)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? theme.accent.opacity(0.08) : Color.clear)
            .cornerRadius(5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quality Button

struct QualityButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let quality: VideoQuality
    let isSelected: Bool
    let onTap: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var qualityText: String {
        switch quality {
        case .high: return "1080p"
        case .medium: return "720p"
        case .low: return "480p"
        case .original: return "Original"
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text(qualityText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : theme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? theme.accent : theme.secondaryBackground)
                .cornerRadius(5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Layout Button

struct LayoutButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let layout: VideoLayout
    let isSelected: Bool
    let onTap: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var layoutText: String {
        switch layout {
        case .singleAngle: return "Single"
        case .sideBySide: return "2-Up"
        case .quad: return "Quad"
        case .stacked: return "Stack"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: layout.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? theme.accent : theme.secondaryText)

                Text(layoutText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? theme.accent.opacity(0.12) : theme.secondaryBackground)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? theme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Compact Toggle

struct CompactToggle: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isOn: Bool
    let label: String
    let icon: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 14)

                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isOn ? theme.accent : theme.tertiaryBackground)
                        .frame(width: 34, height: 20)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .offset(x: isOn ? 7 : -7)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
    }
}

#Preview {
    ExportSheet()
        .environmentObject(ThemeManager.shared)
        .environmentObject(NavigationState())
}
