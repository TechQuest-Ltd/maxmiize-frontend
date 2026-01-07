//
//  RightSidebarPanel.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import SwiftUI
import AVFoundation

struct AnnotationToolInfo: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let tool: AnnotationToolType
}

struct RightSidebarPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var timelineState = TimelineStateManager.shared
    @ObservedObject private var annotationManager = AnnotationManager.shared
    @ObservedObject private var playerManager = SyncedVideoPlayerManager.shared
    @State private var selectedViewer: String = "Angle A"
    @State private var newNoteText: String = ""
    @State private var selectedTag: String = ""
    @State private var clips: [Clip] = []
    @State private var visibleClipsCount: Int = 5 // Show 5 clips initially
    @State private var notes: [Note] = []
    @State private var selectedTool: AnnotationToolType = .select

    @State private var annotationTools: [AnnotationToolInfo] = [
        AnnotationToolInfo(name: "Arrow", icon: "arrow.up.right", tool: .arrow),
        AnnotationToolInfo(name: "Line", icon: "pencil", tool: .pen),
        AnnotationToolInfo(name: "Circle", icon: "circle", tool: .circle),
        AnnotationToolInfo(name: "Text", icon: "textformat", tool: .text),
        AnnotationToolInfo(name: "Rectangle", icon: "rectangle", tool: .rectangle),
        AnnotationToolInfo(name: "Select", icon: "cursorarrow", tool: .select)
    ]

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Clips Panel
                clipsPanel

                // Annotation Tools
                annotationToolsPanel

                // Notes Quick View
                notesQuickView
            }
        }
        .frame(width: 280)
        .padding(10)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
        .onAppear {
            loadClips()
            loadNotes()

            // Sync selected tool with annotation manager
            selectedTool = annotationManager.currentTool
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClipCreated"))) { _ in
            loadClips()
        }
        .onChange(of: timelineState.selectedClipId) { _, selectedId in
            // When a clip is selected, make sure it's visible in the list
            if let selectedId = selectedId,
               let clipIndex = clips.firstIndex(where: { $0.id == selectedId }) {
                // If selected clip is beyond visible count, expand to show it
                if clipIndex >= visibleClipsCount {
                    visibleClipsCount = clipIndex + 1
                    print("📜 Expanded clips list to show selected clip at index \(clipIndex)")
                }
            }
        }
        .onChange(of: annotationManager.currentTool) { _, newTool in
            selectedTool = newTool
        }
    }

    // MARK: - Clips Panel
    private var clipsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "scissors")
                        .font(.system(size: 11))
                        .foregroundColor(theme.accent)

                    Text("Clips")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }

                Spacer()

                Text("\(clips.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.primaryBorder)
                    .cornerRadius(10)
            }

            // Clips list
            if clips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "scissors.badge.ellipsis")
                        .font(.system(size: 24))
                        .foregroundColor(theme.tertiaryText)

                    Text("No clips yet")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)

                    Text("Press I/O to mark, C to create")
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(clips.prefix(visibleClipsCount))) { clip in
                        clipItemView(clip)
                    }

                    // Show More button if there are more clips
                    if visibleClipsCount < clips.count {
                        Button(action: {
                            withAnimation {
                                visibleClipsCount += 5
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("Show More (\(clips.count - visibleClipsCount) remaining)")
                                    .font(.system(size: 11))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(theme.surfaceBackground)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Refresh button
            Button(action: {
                loadClips()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                    Text("Refresh Clips")
                        .font(.system(size: 11))
                }
                .foregroundColor(theme.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(theme.surfaceBackground)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(theme.tertiaryBackground)
        .cornerRadius(12)
    }

    private func clipItemView(_ clip: Clip) -> some View {
        let isSelected = timelineState.selectedClipId == clip.id

        return Button(action: {
            jumpToClip(clip)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(clip.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? theme.accent : theme.primaryText)
                    .lineLimit(1)

                // Time range
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                        .foregroundColor(theme.tertiaryText)

                    Text(formatClipTime(clip))
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)

                    Spacer()

                    // Duration badge
                    Text(formatDuration(clip.duration))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.secondaryBorder)
                        .cornerRadius(4)
                }

                // Tags if present
                if !clip.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(clip.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .foregroundColor(theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accent.opacity(0.15))
                                .cornerRadius(4)
                        }

                        if clip.tags.count > 3 {
                            Text("+\(clip.tags.count - 3)")
                                .font(.system(size: 9))
                                .foregroundColor(theme.tertiaryText)
                        }
                    }
                }

                // Notes preview if present
                if !clip.notes.isEmpty {
                    Text(clip.notes)
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.accent.opacity(0.15) : theme.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.accent : theme.accent.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatClipTime(_ clip: Clip) -> String {
        let startSeconds = Int(clip.startTimeMs / 1000)
        let hours = startSeconds / 3600
        let minutes = (startSeconds % 3600) / 60
        let seconds = startSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    private func loadClips() {
        guard let project = navigationState.currentProject else {
            clips = []
            visibleClipsCount = 5
            return
        }

        // Get the first game ID for this project
        guard let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            clips = []
            visibleClipsCount = 5
            return
        }

        clips = DatabaseManager.shared.getClips(gameId: gameId)
        visibleClipsCount = 5 // Reset to show 5 clips when reloading
        print("📎 Loaded \(clips.count) clips for game \(gameId)")
    }

    private func jumpToClip(_ clip: Clip) {
        print("🎬 Jumping to clip: \(clip.title) at \(formatClipTime(clip))")
        // Post notification with clip start time
        NotificationCenter.default.post(
            name: NSNotification.Name("JumpToClip"),
            object: nil,
            userInfo: ["startTimeMs": clip.startTimeMs]
        )
    }


    // MARK: - Annotation Tools Panel
    private var annotationToolsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Annotation Tools")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: {
                    // Navigate to full annotation view
                    Task { @MainActor in
                        await navigationState.navigate(to: .annotation)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                        Text("Full View")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(theme.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Tool buttons grid
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    annotationToolButton(annotationTools[0])
                    annotationToolButton(annotationTools[1])
                    annotationToolButton(annotationTools[2])
                }

                HStack(spacing: 6) {
                    annotationToolButton(annotationTools[3])
                    annotationToolButton(annotationTools[4])
                    annotationToolButton(annotationTools[5])
                }
            }

            // Active tool info
            if selectedTool != .select {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.success)

                    Text("Active: \(selectedTool.rawValue)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.secondaryText)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(theme.surfaceBackground)
        .cornerRadius(12)
    }

    private func annotationToolButton(_ tool: AnnotationToolInfo) -> some View {
        let isSelected = selectedTool == tool.tool

        return Button(action: {
            // Toggle tool selection
            if selectedTool == tool.tool {
                // If already selected, deselect (return to select mode)
                annotationManager.currentTool = .select
                selectedTool = .select
                // Switch back to multi-angle mode
                playerManager.setSingleAngleMode(false)
                // Post notification to exit annotation mode
                NotificationCenter.default.post(name: NSNotification.Name("ExitAnnotationMode"), object: nil)
            } else {
                // Activate the tool
                annotationManager.currentTool = tool.tool
                selectedTool = tool.tool
                // Switch to single-angle mode for annotation
                playerManager.setSingleAngleMode(true)
                // Post notification to enter annotation mode
                NotificationCenter.default.post(name: NSNotification.Name("EnterAnnotationMode"), object: nil)
            }
            print("🎨 Annotation tool: \(tool.name)")
        }) {
            HStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? Color.white : theme.primaryText)

                Text(tool.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? Color.white : theme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? theme.accent : theme.secondaryBorder)
            .cornerRadius(999)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Notes Quick View
    private var notesQuickView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Notes Quick View")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: {
                    // Navigate to full notes view
                    Task { @MainActor in
                        await navigationState.navigate(to: .notes)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                        Text("View All")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(theme.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Notes list - show most recent 2 notes
            if notes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 20))
                        .foregroundColor(theme.tertiaryText)

                    Text("No notes yet")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(notes.prefix(2))) { note in
                        noteItemView(note)
                    }

                    if notes.count > 2 {
                        Text("+\(notes.count - 2) more notes")
                            .font(.system(size: 10))
                            .foregroundColor(theme.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            }

            // Add note input
            VStack(alignment: .leading, spacing: 6) {
                // Tag selector
                HStack(spacing: 6) {
                    Text("Tag:")
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)

                    TextField("Tag (optional)", text: $selectedTag)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 10))
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.secondaryBackground)
                        .cornerRadius(4)
                }

                ZStack(alignment: .topLeading) {
                    if newNoteText.isEmpty {
                        Text("Add notes or observations...")
                            .font(.system(size: 11))
                            .foregroundColor(theme.tertiaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }

                    TextEditor(text: $newNoteText)
                        .font(.system(size: 11))
                        .foregroundColor(theme.primaryText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(height: 80)
                        .padding(6)
                }
                .background(theme.surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.accent.opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(8)

                // Add button
                Button(action: addNote) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                        Text("Add Note")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(newNoteText.isEmpty ? theme.tertiaryText : theme.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newNoteText.isEmpty)
            }
        }
        .padding(12)
        .background(theme.surfaceBackground)
        .cornerRadius(12)
    }

    private func noteItemView(_ note: Note) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatNoteDate(note.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                // Show attached type
                if let attachment = note.attachedTo.first {
                    Text(attachment.type.rawValue.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.secondaryBorder)
                        .cornerRadius(999)
                }
            }

            Text(note.content)
                .font(.system(size: 11))
                .foregroundColor(theme.secondaryText)
                .lineSpacing(3)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .cornerRadius(8)
    }

    private func formatNoteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func loadNotes() {
        guard let project = navigationState.currentProject else {
            notes = []
            return
        }

        // Load recent notes from database
        notes = DatabaseManager.shared.getAllNotesForProject(projectId: project.id)
            .sorted { $0.createdAt > $1.createdAt }

        print("📝 Loaded \(notes.count) notes for quick view")
    }

    private func addNote() {
        guard !newNoteText.isEmpty,
              let project = navigationState.currentProject else {
            return
        }

        // Get first game ID
        guard let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("❌ No game found for project")
            return
        }

        // Get current playback time if available
        let currentTime = playerManager.currentTime
        let currentTimeMs = Int64(CMTimeGetSeconds(currentTime) * 1000)

        // Save to database using createNote method
        let result = DatabaseManager.shared.createNote(
            momentId: nil, // Not attached to specific moment for quick notes
            gameId: gameId,
            content: newNoteText,
            attachedTo: [],
            playerId: nil
        )

        switch result {
        case .success(let noteId):
            print("✅ Note added successfully (ID: \(noteId)) at time \(currentTimeMs)ms")
            newNoteText = ""
            selectedTag = ""
            loadNotes()
        case .failure(let error):
            print("❌ Failed to add note: \(error)")
        }
    }
}

#Preview {
    RightSidebarPanel()
        .frame(height: 900)
        .background(Color.black)
}
