//
//  LeftSidebarNavigator.swift
//  maxmiize-v1
//
//  Created by TechQuest on 13/12/2025.
//

import SwiftUI

struct LeftSidebarNavigator: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject var navigationState: NavigationState
    @State private var isProjectExplorerExpanded = true
    @State private var isTagsEventsExpanded = true
    @State private var isNotesLabelsExpanded = true
    @State private var moments: [Moment] = []
    @State private var tagCounts: [(name: String, color: String, count: Int)] = []
    @State private var notes: [Note] = []
    @State private var momentLookup: [String: Moment] = [:]

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // NAVIGATOR header
                Text("NAVIGATOR")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(theme.tertiaryText)
                    .tracking(0.88)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 2)

                // Project Explorer Section
                SidebarSection(
                    title: "Project Explorer",
                    badge: "Active",
                    badgeColor: theme.accent.opacity(0.16),
                    badgeTextColor: theme.secondaryText,
                    isExpanded: $isProjectExplorerExpanded
                ) {
                    VStack(spacing: 4) {
                        // Selected session
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.primaryText)

                                Text("Matchday 24 · Main Ses…")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.primaryText)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("4 cams")
                                .font(.system(size: 10))
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accent)
                                .cornerRadius(999)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(theme.accent.opacity(0.14))
                        .cornerRadius(8)

                        // Other items
                        SidebarItem(
                            icon: "rectangle.3.group",
                            title: "Lineup & Formations",
                            subtitle: "Scene"
                        )

                        SidebarItem(
                            icon: "chart.bar",
                            title: "KPIs & Metrics",
                            subtitle: "Data View"
                        )
                    }
                    .padding(.bottom, 2)
                }


                // Tags & Events Section
                SidebarSection(
                    title: "Moments & Events",
                    isExpanded: $isTagsEventsExpanded
                ) {
                    VStack(spacing: 4) {
                        if tagCounts.isEmpty {
                            Text("No moments tagged yet")
                                .font(.system(size: 11))
                                .foregroundColor(theme.tertiaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(tagCounts, id: \.name) { tag in
                                TagItem(
                                    color: Color(hex: tag.color),
                                    label: tag.name,
                                    count: "\(tag.count) moment\(tag.count == 1 ? "" : "s")"
                                )
                            }
                        }
                    }
                    .padding(.bottom, 2)
                }

                // Notes Section
                SidebarSection(
                    title: "Notes",
                    icon: "note.text",
                    isExpanded: $isNotesLabelsExpanded
                ) {
                    VStack(spacing: 4) {
                        if notes.isEmpty {
                            Text("No notes added yet")
                                .font(.system(size: 11))
                                .foregroundColor(theme.tertiaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(notes.prefix(5), id: \.id) { note in
                                if let moment = momentLookup[note.momentId] {
                                    NoteMomentItem(
                                        notes: note.content,
                                        timestamp: formatTimestamp(moment.startTimestampMs)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
        }
        .frame(width: 280)
        .padding(10)
        .background(theme.secondaryBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.85), radius: 20, x: 0, y: 18)
        .onAppear {
            loadData()
        }
        .onChange(of: navigationState.currentProject?.id) { _ in
            loadData()
        }
    }

    private func loadData() {
        guard let project = navigationState.currentProject else {
            moments = []
            tagCounts = []
            notes = []
            momentLookup = [:]
            return
        }

        // Get the first game ID for this project
        guard let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("⚠️ No game found for project")
            return
        }

        // Load moments
        moments = DatabaseManager.shared.getMoments(gameId: gameId)
        print("📊 Loaded \(moments.count) moments for sidebar")

        // Create moment lookup dictionary for fast access
        momentLookup = Dictionary(uniqueKeysWithValues: moments.map { ($0.id, $0) })

        // Calculate tag counts
        var tagCountsDict: [String: (color: String, count: Int)] = [:]
        for moment in moments {
            let category = moment.momentCategory
            if var existing = tagCountsDict[category] {
                existing.count += 1
                tagCountsDict[category] = existing
            } else {
                // Default colors for categories
                let color = getCategoryColor(category)
                tagCountsDict[category] = (color: color, count: 1)
            }
        }
        tagCounts = tagCountsDict.map { (name: $0.key, color: $0.value.color, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        // Load notes from database (not from moment.notes field)
        notes = DatabaseManager.shared.getAllNotes(gameId: gameId)
            .sorted { $0.createdAt > $1.createdAt }

        print("📊 Tag counts: \(tagCounts.count), Notes: \(notes.count)")
    }

    private func getCategoryColor(_ category: String) -> String {
        switch category.lowercased() {
        case "offense": return "2979ff"
        case "defense": return "f5c14e"
        case "transition", "transitions": return "5adc8c"
        default: return "666666"
        }
    }

    private func formatTimestamp(_ timestampMs: Int64) -> String {
        let totalSeconds = Int(timestampMs / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Sidebar Section
struct SidebarSection<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    var icon: String?
    var badge: String?
    var badgeColor: Color?
    var badgeTextColor: Color?
    @Binding var isExpanded: Bool
    let content: Content

    init(
        title: String,
        icon: String? = nil,
        badge: String? = nil,
        badgeColor: Color? = nil,
        badgeTextColor: Color? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.badge = badge
        self.badgeColor = badgeColor
        self.badgeTextColor = badgeTextColor
        self._isExpanded = isExpanded
        self.content = content()
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 4) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundColor(theme.primaryText)
                    }

                    Text(title)
                        .font(.system(size: 12, weight: icon != nil ? .bold : .regular))
                        .foregroundColor(theme.secondaryText)
                }

                Spacer()

                if let badge = badge, let badgeColor = badgeColor, let badgeTextColor = badgeTextColor {
                    Text(badge)
                        .font(.system(size: 11))
                        .foregroundColor(badgeTextColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .cornerRadius(999)
                } else {
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        Text("⌃")
                            .font(.system(size: 11))
                            .foregroundColor(theme.tertiaryText)
                            .rotationEffect(.degrees(isExpanded ? 0 : 180))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Content
            if isExpanded {
                content
                    .padding(.horizontal, 8)
            }
        }
        .background(theme.tertiaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Sidebar Item
struct SidebarItem: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let subtitle: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .cornerRadius(8)
    }
}


// MARK: - Tag Item
struct TagItem: View {
    @EnvironmentObject var themeManager: ThemeManager
    let color: Color
    let label: String
    let count: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)

                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(theme.secondaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.cardBackground)
            .cornerRadius(999)

            Spacer()

            Text(count)
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    @EnvironmentObject var themeManager: ThemeManager
    let color: Color
    let label: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(theme.secondaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.cardBackground)
        .cornerRadius(999)
    }
}

// MARK: - Note Moment Item
struct NoteMomentItem: View {
    @EnvironmentObject var themeManager: ThemeManager
    let notes: String
    let timestamp: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(notes)
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText)
                .lineLimit(2)

            Text(timestamp)
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(theme.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Playlist Item
struct PlaylistItem: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let count: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
            }

            Spacer()

            Text(count)
                .font(.system(size: 10))
                .foregroundColor(theme.tertiaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.cardBackground)
                .cornerRadius(999)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

#Preview {
    LeftSidebarNavigator()
        .environmentObject(NavigationState())
        .frame(height: 900)
        .background(Color.black)
}
