//
//  NotesView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 03/01/2026.
//

import SwiftUI

struct NotesView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var toastManager = ToastManager()

    // Data state
    @State private var notes: [Note] = []
    @State private var moments: [Moment] = []
    @State private var momentLookup: [String: Moment] = [:]  // Performance optimization
    @State private var selectedNote: Note? = nil

    // Filter state
    @State private var selectedAttachmentType: NoteAttachmentType? = nil
    @State private var selectedMomentId: String? = nil
    @State private var searchText: String = ""

    // UI state
    @State private var selectedMainNav: MainNavItem = .notes
    @State private var showSettings = false
    @State private var showAddNote = false
    @State private var editedContent = ""
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var theme: ThemeColors {
        themeManager.colors
    }

    var filteredNotes: [Note] {
        var result = notes

        // Filter by attachment type
        if let type = selectedAttachmentType {
            result = result.filter { note in
                note.attachedTo.contains { $0.type == type }
            }
        }

        // Filter by moment
        if let momentId = selectedMomentId {
            result = result.filter { $0.momentId == momentId }
        }

        // Search filter
        if !searchText.isEmpty {
            result = result.filter { note in
                note.content.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
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

                GeometryReader { geometry in
                    HStack(spacing: 12) {
                        // Left Sidebar - Filters
                        sidebarSection
                            .frame(width: min(max(geometry.size.width * 0.20, 260), 300))

                        // Middle - Notes Table
                        notesTableSection
                            .frame(maxWidth: .infinity)

                        // Right Sidebar - Note Details
                        if selectedNote != nil {
                            noteDetailsSection
                                .frame(width: min(max(geometry.size.width * 0.25, 320), 380))
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(12)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            loadNotes()
            loadMoments()
        }
        .toast(manager: toastManager)
    }

    // MARK: - Sidebar Section
    private var sidebarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            attachmentTypeFilter

            Divider()
                .background(theme.secondaryBorder)

            momentFilter

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    private var attachmentTypeFilter: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("ATTACHMENT TYPE")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                if selectedAttachmentType != nil {
                    Button(action: { selectedAttachmentType = nil }) {
                        Text("Clear")
                            .font(.system(size: 11))
                            .foregroundColor(theme.accent)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 11)
            .padding(.top, 8)

            VStack(spacing: 0) {
                FilterRow(
                    name: "All Notes",
                    count: notes.count,
                    isSelected: selectedAttachmentType == nil
                )
                .onTapGesture {
                    selectedAttachmentType = nil
                }

                FilterRow(
                    name: "Moments",
                    count: momentNotesCount,
                    isSelected: selectedAttachmentType == .moment
                )
                .onTapGesture {
                    selectedAttachmentType = .moment
                }

                FilterRow(
                    name: "Layers",
                    count: layerNotesCount,
                    isSelected: selectedAttachmentType == .layer
                )
                .onTapGesture {
                    selectedAttachmentType = .layer
                }

                FilterRow(
                    name: "Players",
                    count: playerNotesCount,
                    isSelected: selectedAttachmentType == .player
                )
                .onTapGesture {
                    selectedAttachmentType = .player
                }
            }
            .padding(.horizontal, 9)
        }
        .padding(.bottom, 22)
    }

    private var momentFilter: some View {
        VStack(alignment: .leading, spacing: 11) {
            momentFilterHeader

            momentFilterList
        }
        .padding(.top, 8)
    }

    private var momentFilterHeader: some View {
        HStack {
            Text("MOMENTS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.tertiaryText)

            Spacer()

            if selectedMomentId != nil {
                Button(action: { selectedMomentId = nil }) {
                    Text("Clear")
                        .font(.system(size: 11))
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 11)
    }

    private var momentFilterList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(momentsWithNotes) { moment in
                    MomentFilterRow(
                        moment: moment,
                        noteCount: noteCountForMoment(moment.id),
                        isSelected: selectedMomentId == moment.id,
                        onTap: {
                            if selectedMomentId == moment.id {
                                selectedMomentId = nil
                            } else {
                                selectedMomentId = moment.id
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 9)
        }
    }

    private var momentsWithNotes: [Moment] {
        let momentsList = Array(moments.prefix(20))
        return momentsList.filter { moment in
            noteCountForMoment(moment.id) > 0
        }
    }

    private func noteCountForMoment(_ momentId: String) -> Int {
        notes.filter { $0.momentId == momentId }.count
    }

    // Count notes attached to moments
    private var momentNotesCount: Int {
        // All notes belong to a moment (they all have momentId)
        // But we count those specifically attached to moments in the attachedTo array
        notes.filter { note in
            note.attachedTo.contains { $0.type == .moment }
        }.count
    }

    // Count notes attached to layers
    private var layerNotesCount: Int {
        notes.filter { note in
            note.attachedTo.contains { $0.type == .layer }
        }.count
    }

    // Count notes attached to players
    private var playerNotesCount: Int {
        notes.filter { note in
            note.playerId != nil || note.attachedTo.contains { $0.type == .player }
        }.count
    }

    // MARK: - Notes Table Section
    private var notesTableSection: some View {
        VStack(spacing: 0) {
            // Header with count and search
            HStack {
                Text("All Notes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Text("\(filteredNotes.count) notes")
                    .font(.system(size: 13))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.tertiaryText)
                        .font(.system(size: 13))

                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13))
                        .foregroundColor(theme.primaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.surfaceBackground)
                .cornerRadius(6)
                .frame(width: 200)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.secondaryBackground)

            // Table Header
            HStack(spacing: 0) {
                Text("Content")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Attached To")
                    .frame(width: 150, alignment: .leading)
                Text("Created")
                    .frame(width: 120, alignment: .leading)
                Text("Modified")
                    .frame(width: 120, alignment: .leading)

                Spacer()
                    .frame(width: 24)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(theme.tertiaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surfaceBackground)

            // Notes Rows
            if filteredNotes.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    title: "No Notes Found",
                    subtitle: searchText.isEmpty ? "Notes will appear here" : "Try a different search"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredNotes) { note in
                            NoteTableRow(
                                note: note,
                                moment: momentLookup[note.momentId],
                                isSelected: selectedNote?.id == note.id
                            )
                            .onTapGesture {
                                selectNote(note)
                            }
                        }
                    }
                    .background(theme.primaryBackground)
                }
            }
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Note Details Section
    private var noteDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let note = selectedNote {
                // Close button header
                HStack {
                    Text("Note Details")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Button(action: { selectedNote = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.tertiaryText)
                            .frame(width: 24, height: 24)
                            .background(theme.secondaryBackground)
                            .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 11)
                .padding(.top, 11)
                .padding(.bottom, 9)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Content Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Content")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            TextEditor(text: $editedContent)
                                .font(.system(size: 12))
                                .foregroundColor(theme.primaryText)
                                .scrollContentBackground(.hidden)
                                .background(theme.secondaryBackground)
                                .frame(height: 150)
                                .cornerRadius(6)
                        }
                        .padding(.all, 12)
                        .background(theme.surfaceBackground)
                        .cornerRadius(10)

                        // Attachments Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Attached to")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            ForEach(note.attachedTo, id: \.id) { attachment in
                                HStack {
                                    Image(systemName: iconForAttachmentType(attachment.type))
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.accent)
                                        .frame(width: 20)

                                    Text(attachment.type.rawValue.capitalized)
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.primaryText)

                                    Spacer()
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(theme.secondaryBackground)
                                .cornerRadius(6)
                            }
                        }
                        .padding(.all, 12)
                        .background(theme.surfaceBackground)
                        .cornerRadius(10)

                        // Metadata Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Metadata")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Created:")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.tertiaryText)
                                    Spacer()
                                    Text(formatDate(note.createdAt))
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.primaryText)
                                }

                                if let modified = note.modifiedAt {
                                    HStack {
                                        Text("Modified:")
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.tertiaryText)
                                        Spacer()
                                        Text(formatDate(modified))
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.primaryText)
                                    }
                                }
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(theme.secondaryBackground)
                            .cornerRadius(6)
                        }
                        .padding(.all, 12)
                        .background(theme.surfaceBackground)
                        .cornerRadius(10)

                        // Actions
                        VStack(spacing: 8) {
                            Button(action: { saveNoteChanges() }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Save Changes")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(theme.accent)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: { deleteNote(note) }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 12))
                                    Text("Delete Note")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(theme.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(theme.error)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 9)
                    }
                    .padding(.all, 11)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Data Loading & Actions
    private func loadNotes() {
        guard let project = navigationState.currentProject else {
            print("⚠️ NotesView.loadNotes: No current project")
            notes = []
            return
        }

        // Load notes from the separate notes table
        var allNotes = DatabaseManager.shared.getAllNotesForProject(projectId: project.id)
        print("📊 NotesView: Loaded \(allNotes.count) notes from notes table")

        // Also load notes from moment/tag notes fields
        let moments = DatabaseManager.shared.getMomentsForProject(projectId: project.id)
        let momentsWithNotes = moments.filter { moment in
            guard let notes = moment.notes else { return false }
            return !notes.isEmpty
        }
        print("📊 NotesView: Found \(momentsWithNotes.count) moments with notes fields")

        // Convert moment notes to Note objects for display
        for moment in momentsWithNotes {
            guard let momentNotes = moment.notes, !momentNotes.isEmpty else { continue }
            let note = Note(
                id: "moment_note_\(moment.id)",
                momentId: moment.id,
                gameId: moment.gameId,
                content: momentNotes,
                attachedTo: [NoteAttachment(type: .moment, id: moment.id)],
                playerId: nil,
                createdAt: moment.createdAt,
                modifiedAt: moment.modifiedAt
            )
            allNotes.append(note)
        }

        // Also load notes from player notes fields (from global teams database)
        // Get all players that have notes
        let allPlayersWithNotes = GlobalTeamsManager.shared.getAllPlayersWithNotes()
        print("📊 NotesView: Found \(allPlayersWithNotes.count) total players with notes in global database")

        // Get first game ID for this project (needed for Note model)
        let firstGameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) ?? project.id

        // Convert player notes to Note objects for display
        // Note: We show ALL player notes because players are global resources that can be
        // referenced across projects. If you want to filter to only players used in THIS project,
        // we would need to track player usage in moments/layers.
        for player in allPlayersWithNotes {
            guard let playerNotes = player.notes, !playerNotes.isEmpty else { continue }
            let note = Note(
                id: "player_note_\(player.id)",
                momentId: "", // Player notes don't belong to a specific moment
                gameId: firstGameId, // Use first game or project ID as fallback
                content: playerNotes,
                attachedTo: [NoteAttachment(type: .player, id: player.id)],
                playerId: player.id,
                createdAt: Date(), // Player model doesn't have createdAt, use current date
                modifiedAt: nil
            )
            allNotes.append(note)
        }

        notes = allNotes
        print("📊 NotesView: Total notes (table + moment fields + player fields): \(notes.count)")
    }

    private func loadMoments() {
        guard let project = navigationState.currentProject else { return }
        moments = DatabaseManager.shared.getMomentsForProject(projectId: project.id)

        // Create lookup dictionary for O(1) access instead of O(n) linear search
        momentLookup = Dictionary(uniqueKeysWithValues: moments.map { ($0.id, $0) })

        print("📊 NotesView: Loaded \(moments.count) moments")
    }

    private func selectNote(_ note: Note) {
        selectedNote = note
        editedContent = note.content
    }

    private func saveNoteChanges() {
        guard let note = selectedNote else { return }

        let success = DatabaseManager.shared.updateNote(noteId: note.id, content: editedContent)

        if success {
            toastManager.show(message: "Note updated successfully", icon: "checkmark.circle.fill", backgroundColor: "5adc8c")
            loadNotes()
            // Update selectedNote with new content
            if let updatedNote = notes.first(where: { $0.id == note.id }) {
                selectedNote = updatedNote
                editedContent = updatedNote.content
            }
        } else {
            toastManager.show(message: "Failed to update note", icon: "xmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func deleteNote(_ note: Note) {
        let success = DatabaseManager.shared.deleteNote(noteId: note.id)

        if success {
            toastManager.show(message: "Note deleted successfully", icon: "checkmark.circle.fill", backgroundColor: "5adc8c")
            selectedNote = nil
            loadNotes()
        } else {
            toastManager.show(message: "Failed to delete note", icon: "xmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func iconForAttachmentType(_ type: NoteAttachmentType) -> String {
        switch type {
        case .moment: return "clock.fill"
        case .layer: return "square.stack.fill"
        case .player: return "person.fill"
        }
    }

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
                break
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

}

// MARK: - Supporting Views

struct NoteTableRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let note: Note
    let moment: Moment?
    let isSelected: Bool

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(note.content.isEmpty ? "—" : String(note.content.prefix(60)) + (note.content.count > 60 ? "..." : ""))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(note.attachedTo.prefix(2), id: \.id) { attachment in
                    HStack(spacing: 3) {
                        Image(systemName: iconFor(attachment.type))
                            .font(.system(size: 9))
                        Text(attachment.type.rawValue.prefix(1).uppercased())
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(theme.secondaryBackground)
                    .cornerRadius(4)
                }
                if note.attachedTo.count > 2 {
                    Text("+\(note.attachedTo.count - 2)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                }
            }
            .frame(width: 150, alignment: .leading)

            Text(formatShortDate(note.createdAt))
                .font(.system(size: 12))
                .frame(width: 120, alignment: .leading)

            Group {
                if let modifiedAt = note.modifiedAt {
                    Text(formatShortDate(modifiedAt))
                        .foregroundColor(.white)
                } else {
                    Text("—")
                        .foregroundColor(theme.tertiaryText)
                }
            }
            .font(.system(size: 12))
            .frame(width: 120, alignment: .leading)

            Image(systemName: "eye.fill")
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
                .frame(width: 24)
        }
        .font(.system(size: 13))
        .foregroundColor(theme.primaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? theme.secondaryBorder.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
    }

    private func iconFor(_ type: NoteAttachmentType) -> String {
        switch type {
        case .moment: return "clock.fill"
        case .layer: return "square.stack.fill"
        case .player: return "person.fill"
        }
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct FilterRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let name: String
    let count: Int
    let isSelected: Bool

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : theme.secondaryText)

            Spacer()

            Text("\(count)")
                .font(.system(size: 12))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(isSelected ? theme.secondaryBorder : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}

struct MomentFilterRow: View {
    let moment: Moment
    let noteCount: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        FilterRow(
            name: moment.momentCategory,
            count: noteCount,
            isSelected: isSelected
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    NotesView()
        .environmentObject(NavigationState())
        .frame(width: 1440, height: 1062)
}
