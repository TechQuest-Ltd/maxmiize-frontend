//
//  SorterView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 23/12/2025.
//

import SwiftUI
import AVFoundation

/// Sorter view - Grid/table layout for organizing and sorting moments
/// Based on SportCode's Sorter function
struct SorterView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var playerManager = SyncedVideoPlayerManager.shared

    // Sorter state
    @State private var moments: [Moment] = []
    @State private var selectedMomentIds: Set<String> = []
    @State private var sortColumn: SorterColumn = .startTime
    @State private var sortAscending: Bool = true
    @State private var searchText: String = ""

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sorterHeader
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(theme.surfaceBackground)

            Divider()
                .background(theme.primaryBorder)

            // Table
            ScrollView {
                VStack(spacing: 0) {
                    // Table header
                    tableHeader
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(theme.cardBackground)

                    // Table rows
                    ForEach(filteredAndSortedMoments) { moment in
                        momentRow(moment: moment)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(selectedMomentIds.contains(moment.id) ? theme.accent.opacity(0.2) : Color.clear)
                            .onTapGesture {
                                toggleSelection(momentId: moment.id)
                            }

                        Divider()
                            .background(theme.primaryBorder)
                    }
                }
            }

            // Footer with actions
            sorterFooter
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(theme.surfaceBackground)
        }
        .background(theme.primaryBackground)
        .onAppear {
            loadMoments()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TagCreated"))) { _ in
            loadMoments()
        }
    }

    // MARK: - Header
    private var sorterHeader: some View {
        HStack {
            Text("Sorter")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Spacer()

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)

                TextField("Search moments...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)
                    .frame(width: 200)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(theme.primaryBorder)
            .cornerRadius(6)
        }
    }

    // MARK: - Table Header
    private var tableHeader: some View {
        HStack(spacing: 16) {
            // Select checkbox
            Button(action: toggleSelectAll) {
                Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundColor(theme.tertiaryText)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30)

            // Columns
            sortableColumnHeader(.category, title: "Moment", width: 120)
            sortableColumnHeader(.startTime, title: "Start Time", width: 100)
            sortableColumnHeader(.duration, title: "Duration", width: 80)
            sortableColumnHeader(.notes, title: "Notes", width: nil)

            // Actions column
            Text("Actions")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.tertiaryText)
                .frame(width: 80, alignment: .center)
        }
    }

    private func sortableColumnHeader(_ column: SorterColumn, title: String, width: CGFloat?) -> some View {
        Button(action: {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = true
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.tertiaryText)

                if sortColumn == column {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(theme.accent)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Table Row
    private func momentRow(moment: Moment) -> some View {
        HStack(spacing: 16) {
            // Select checkbox
            Button(action: {
                toggleSelection(momentId: moment.id)
            }) {
                Image(systemName: selectedMomentIds.contains(moment.id) ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundColor(selectedMomentIds.contains(moment.id) ? theme.accent : theme.tertiaryText)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30)

            // Moment category with color indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(colorForCategory(moment.momentCategory))
                    .frame(width: 8, height: 8)

                Text(moment.momentCategory)
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)
            }
            .frame(width: 120, alignment: .leading)

            // Start time
            Text(formatTimeMs(moment.startTimestampMs))
                .font(.system(size: 12))
                .foregroundColor(theme.secondaryText)
                .frame(width: 100, alignment: .leading)

            // Duration
            if let duration = moment.duration {
                Text(formatDuration(duration))
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .frame(width: 80, alignment: .leading)
            } else {
                Text("Active")
                    .font(.system(size: 12))
                    .foregroundColor(theme.warning)
                    .frame(width: 80, alignment: .leading)
            }

            // Notes
            Text(moment.notes ?? "-")
                .font(.system(size: 12))
                .foregroundColor(theme.tertiaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: 8) {
                // Play button
                Button(action: {
                    playMoment(moment)
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Play moment")
            }
            .frame(width: 80, alignment: .center)
        }
    }

    // MARK: - Footer
    private var sorterFooter: some View {
        HStack {
            // Selection info
            Text("\(selectedMomentIds.count) of \(moments.count) selected")
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)

            Spacer()

            // Export button
            Button(action: exportSelected) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                    Text("Export Selected")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedMomentIds.isEmpty ? theme.primaryBorder : theme.accent)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectedMomentIds.isEmpty)
        }
    }

    // MARK: - Helper Properties
    private var allSelected: Bool {
        !moments.isEmpty && selectedMomentIds.count == moments.count
    }

    private var filteredAndSortedMoments: [Moment] {
        var filtered = moments

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.momentCategory.localizedCaseInsensitiveContains(searchText) ||
                ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply sorting
        filtered.sort { moment1, moment2 in
            let ascending = sortAscending

            switch sortColumn {
            case .category:
                return ascending ? moment1.momentCategory < moment2.momentCategory : moment1.momentCategory > moment2.momentCategory
            case .startTime:
                return ascending ? moment1.startTimestampMs < moment2.startTimestampMs : moment1.startTimestampMs > moment2.startTimestampMs
            case .duration:
                let dur1 = moment1.duration ?? 0
                let dur2 = moment2.duration ?? 0
                return ascending ? dur1 < dur2 : dur1 > dur2
            case .notes:
                let notes1 = moment1.notes ?? ""
                let notes2 = moment2.notes ?? ""
                return ascending ? notes1 < notes2 : notes1 > notes2
            }
        }

        return filtered
    }

    // MARK: - Actions
    private func loadMoments() {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("⚠️ SorterView: No project or game available")
            return
        }

        moments = DatabaseManager.shared.getMoments(gameId: gameId)
        print("📊 SorterView: Loaded \(moments.count) moments")
    }

    private func toggleSelection(momentId: String) {
        if selectedMomentIds.contains(momentId) {
            selectedMomentIds.remove(momentId)
        } else {
            selectedMomentIds.insert(momentId)
        }
    }

    private func toggleSelectAll() {
        if allSelected {
            selectedMomentIds.removeAll()
        } else {
            selectedMomentIds = Set(moments.map { $0.id })
        }
    }

    private func playMoment(_ moment: Moment) {
        // Seek to moment start time
        let startTime = CMTime(seconds: Double(moment.startTimestampMs) / 1000.0, preferredTimescale: 600)
        playerManager.seek(to: startTime)
        playerManager.play()

        print("▶️ Playing moment: \(moment.momentCategory) at \(formatTimeMs(moment.startTimestampMs))")
    }

    private func exportSelected() {
        let selectedMoments = moments.filter { selectedMomentIds.contains($0.id) }
        print("📤 Exporting \(selectedMoments.count) moments")

        // TODO: Implement export functionality
        // - Export to video clips
        // - Export to playlist
        // - Export to CSV/JSON
    }

    // MARK: - Helpers
    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Offense":
            return theme.success
        case "Defense":
            return theme.error
        case "Transition":
            return theme.warning
        default:
            return theme.tertiaryText
        }
    }

    private func formatTimeMs(_ ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((ms % 1000) / 10)

        if hours > 0 {
            return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, milliseconds)
        } else {
            return String(format: "%02d:%02d:%02d", minutes, seconds, milliseconds)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types
enum SorterColumn {
    case category
    case startTime
    case duration
    case notes
}

// MARK: - Preview
#Preview {
    SorterView()
        .environmentObject(NavigationState())
        .frame(width: 1200, height: 800)
        .background(Color.black)
}
