//
//  RosterManagementView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//  Enhanced roster management with full edit capabilities matching design
//

import SwiftUI

struct RosterManagementView: View {
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var toastManager = ToastManager()

    // Team and Player Data
    @State private var teams: [Team] = []
    @State private var players: [PlayerInfo] = []
    @State private var selectedTeam: Team?
    @State private var selectedPlayer: PlayerInfo?

    // Dynamic Position Data (loaded from database based on team sport)
    @State private var sportType: SportType?
    @State private var positionGroups: [PositionGroup] = []
    @State private var allPositions: [Position] = []
    @State private var selectedPositionGroup: PositionGroup?

    // UI State
    @State private var searchText: String = ""
    @State private var selectedMainNav: MainNavItem = .roster
    @State private var showAddTeam = false
    @State private var showAddPlayer = false
    @State private var showSettings = false
    @State private var activeSheet: ActiveSheet? = nil

    enum ActiveSheet: Identifiable {
        case addTeam
        case addPlayer

        var id: Int {
            switch self {
            case .addTeam: return 1
            case .addPlayer: return 2
            }
        }
    }

    // Edit mode state
    @State private var isEditingPlayer = false
    @State private var editedFirstName = ""
    @State private var editedLastName = ""
    @State private var editedJerseyNumber = ""
    @State private var editedPositionId = ""
    @State private var editedHeightCm = ""
    @State private var editedWeightKg = ""
    @State private var editedDateOfBirth = Date()
    @State private var editedNationality = ""
    @State private var editedColorIndicator = "3b82f6"
    @State private var editedNotes = ""

    let availableColors = ["3b82f6", "10b981", "f59e0b", "ef4444", "8b5cf6", "ec4899"]

    var filteredPlayers: [PlayerInfo] {
        var result = players

        if let group = selectedPositionGroup {
            result = result.filter { $0.positionGroup?.id == group.id }
        }

        if !searchText.isEmpty {
            result = result.filter { player in
                player.firstName.localizedCaseInsensitiveContains(searchText) ||
                player.lastName.localizedCaseInsensitiveContains(searchText) ||
                "\(player.jerseyNumber)".contains(searchText)
            }
        }

        return result
    }
    
    @ObservedObject private var themeManager = ThemeManager.shared

    var theme: ThemeColors {
        themeManager.colors
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
                        // Left Sidebar - Teams & Positions
                        sidebarSection
                            .frame(width: min(max(geometry.size.width * 0.20, 260), 300))

                        // Middle - Player Table
                        playerTableSection
                            .frame(maxWidth: .infinity)

                        // Right Sidebar - Player Details
                        if selectedPlayer != nil {
                            playerDetailsSection
                                .frame(width: min(max(geometry.size.width * 0.25, 320), 380))
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.all, 12)
                    .animation(.easeInOut(duration: 0.2), value: selectedPlayer != nil)
                }
            }
        }
        .onAppear {
            loadTeams()
        }
        .overlay(
            Group {
                if toastManager.showToast {
                    ToastNotification(
                        message: toastManager.toastMessage,
                        icon: toastManager.toastIcon,
                        backgroundColor: toastManager.toastBackgroundColor
                    )
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            },
            alignment: .top
        )
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAddPlayer) {
            if let team = selectedTeam {
                AddPlayerSheet(
                    isPresented: $showAddPlayer,
                    teamId: team.id,
                    allPositions: allPositions,
                    onPlayerAdded: {
                        if let selectedTeam = selectedTeam {
                            loadPlayers(for: selectedTeam)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showAddTeam) {
            AddTeamSheet(
                isPresented: $showAddTeam,
                onTeamAdded: {
                    loadTeams()
                }
            )
        }
    }

    // MARK: - Sidebar Section
    private var sidebarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Teams Section
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("TEAMS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                    Spacer()
                    Text("\(teams.count) teams")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(.horizontal, 11)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(teams) { team in
                            let playerCount = selectedTeam?.id == team.id ? players.count : 0
                            TeamRow(
                                name: team.name,
                                count: "\(playerCount) players",
                                isSelected: selectedTeam?.id == team.id
                            )
                            .onTapGesture {
                                selectTeam(team)
                            }
                        }
                    }
                }
                .padding(.horizontal, 9)

                Button(action: {
                    print("🔘 Add Team button clicked")
                    activeSheet = .addTeam
                    print("🔘 activeSheet set to: \(String(describing: activeSheet))")
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                        Text("Add Team")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.secondaryBorder)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 9)
            }
            .padding(.top, 11)
            .padding(.bottom, 22)

            Divider()
                .background(theme.secondaryBorder)

            // Positions Section (Football)
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("POSITIONS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                    Spacer()
                    Text("Optional")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(.horizontal, 11)

                VStack(spacing: 0) {
                    ForEach(positionGroups) { group in
                        let count = players.filter { $0.positionGroup?.id == group.id }.count
                        PositionRow(
                            name: group.name,
                            count: count,
                            isSelected: selectedPositionGroup?.id == group.id
                        )
                        .onTapGesture {
                            if selectedPositionGroup?.id == group.id {
                                selectedPositionGroup = nil
                            } else {
                                selectedPositionGroup = group
                            }
                        }
                    }
                }
                .padding(.horizontal, 9)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    // MARK: - Player Table Section
    private var playerTableSection: some View {
        VStack(spacing: 0) {
            // Header with team name and player count
            HStack {
                Text(selectedTeam?.name ?? "Roster")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("•")
                    .foregroundColor(theme.tertiaryText)

                Text("\(filteredPlayers.count) players")
                    .font(.system(size: 13))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                // Search and Add Player
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.tertiaryText)
                            .font(.system(size: 13))

                        TextField("Search players...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.surfaceBackground)
                    .cornerRadius(6)
                    .frame(width: 200)

                    Button(action: { showAddPlayer = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("Add Player")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.accent)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(selectedTeam == nil)
                    .opacity(selectedTeam == nil ? 0.5 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.secondaryBackground)

            // Table Header
            HStack(spacing: 0) {
                Text("Player Name")
                    .frame(width: 160, alignment: .leading)
                Text("#")
                    .frame(width: 62)
                Text("Position")
                    .frame(width: 76)
                Text("Height / Weight")
                    .frame(width: 120)
                Text("Nationality")
                    .frame(width: 83)

                if selectedPlayer == nil {
                    Text("Notes")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer()
                        .frame(maxWidth: .infinity)
                }

                Text("Linked")
                    .frame(width: 80)

                Spacer()
                    .frame(width: 24)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(theme.tertiaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.surfaceBackground)

            // Player Rows
            if selectedTeam == nil {
                EmptyStateView(
                    icon: "person.3",
                    title: "No Team Selected",
                    subtitle: "Select a team from the sidebar to view players"
                )
            } else if filteredPlayers.isEmpty {
                EmptyStateView(
                    icon: "person.badge.plus",
                    title: searchText.isEmpty ? "No Players" : "No Results",
                    subtitle: searchText.isEmpty ? "Add players to this team" : "Try a different search"
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredPlayers) { player in
                            PlayerTableRowEnhanced(
                                player: player,
                                isSelected: selectedPlayer?.id == player.id,
                                showNotes: selectedPlayer == nil
                            )
                            .onTapGesture {
                                selectPlayer(player)
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

    // MARK: - Player Details Section (Enhanced with Editing)
    private var playerDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let player = selectedPlayer {
                // Close button header
                HStack {
                    Text("Basic Info")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Button(action: { selectedPlayer = nil }) {
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
                        // Basic Info Section
                        VStack(alignment: .leading, spacing: 12) {
                            // First Name
                            VStack(alignment: .leading, spacing: 4) {
                                Text("First name")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                TextField("Enter first name", text: $editedFirstName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.primaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                            }

                            // Last Name
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last name")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                TextField("Enter last name", text: $editedLastName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.primaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                            }

                            HStack(spacing: 6) {
                                // Jersey Number
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Jersey number")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.tertiaryText)

                                    TextField("", text: $editedJerseyNumber)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.primaryText)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(theme.secondaryBackground)
                                        .cornerRadius(6)
                                }

                                // Position
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Position")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.tertiaryText)

                                    Menu {
                                        ForEach(allPositions) { position in
                                            Button(action: {
                                                editedPositionId = position.id
                                            }) {
                                                Text("\(position.code) - \(position.name)")
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            if let position = allPositions.first(where: { $0.id == editedPositionId }) {
                                                Text("\(position.code) - \(position.name)")
                                                    .foregroundColor(theme.primaryText)
                                            } else {
                                                Text("Select position")
                                                    .foregroundColor(theme.tertiaryText)
                                            }
                                            Spacer()
                                        }
                                        .font(.system(size: 13))
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(theme.secondaryBackground)
                                        .cornerRadius(6)
                                    }
                                }
                            }

                            // Color Indicator
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Color indicator")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                HStack(spacing: 8) {
                                    ForEach(availableColors, id: \.self) { color in
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(Color.white, lineWidth: 2)
                                                    .opacity(editedColorIndicator == color ? 1 : 0)
                                            )
                                            .onTapGesture {
                                                editedColorIndicator = color
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.all, 12)
                        .background(theme.surfaceBackground)
                        .cornerRadius(10)

                        // Physical & Profile
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Physical & profile")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Height (cm)")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.tertiaryText)

                                    TextField("178", text: $editedHeightCm)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.primaryText)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(theme.secondaryBackground)
                                        .cornerRadius(6)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Weight (kg)")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.tertiaryText)

                                    TextField("75", text: $editedWeightKg)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .font(.system(size: 13))
                                        .foregroundColor(theme.primaryText)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(theme.secondaryBackground)
                                        .cornerRadius(6)
                                }
                            }

                            // Date of Birth
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Date of birth")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                DatePicker("", selection: $editedDateOfBirth, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .colorScheme(.dark)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                            }

                            // Nationality
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nationality")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                TextField("Enter nationality", text: $editedNationality)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.primaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.all, 12)
                        .background(theme.surfaceBackground)
                        .cornerRadius(10)

                        // Notes
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Additional information")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                TextEditor(text: $editedNotes)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.primaryText)
                                    .scrollContentBackground(.hidden)
                                    .background(theme.secondaryBackground)
                                    .frame(height: 80)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.all, 12)
                        .background(theme.surfaceBackground)
                        .cornerRadius(10)

                        // Actions
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Actions")
                                .font(.system(size: 11))
                                .foregroundColor(theme.tertiaryText)

                            Text("Commit or share changes")
                                .font(.system(size: 11))
                                .foregroundColor(theme.tertiaryText)
                                .padding(.bottom, 4)

                            VStack(spacing: 8) {
                                Button(action: { savePlayerChanges() }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.system(size: 11))
                                        Text("Save Changes")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(theme.accent)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: { exportPlayerData() }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 11))
                                        Text("Export Player Data")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(theme.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: { deletePlayer(player) }) {
                                    HStack {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                        Text("Delete Player")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundColor(theme.error)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
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
    private func loadTeams() {
        teams = GlobalTeamsManager.shared.getTeams()
        print("📊 RosterManagementView: Loaded \(teams.count) teams")

        if let firstTeam = teams.first {
            selectTeam(firstTeam)
        }
    }

    private func selectTeam(_ team: Team) {
        selectedTeam = team
        selectedPlayer = nil
        selectedPositionGroup = nil

        // Load sport type and positions for this team's sport
        let sports = GlobalTeamsManager.shared.getSportTypes()
        sportType = sports.first { $0.id == team.sportTypeId }

        if let sportId = sportType?.id {
            positionGroups = GlobalTeamsManager.shared.getPositionGroups(sportTypeId: sportId)
            allPositions = GlobalTeamsManager.shared.getAllPositionsForSport(sportTypeId: sportId)
        }

        loadPlayers(for: team)
    }

    private func loadPlayers(for team: Team) {
        players = GlobalTeamsManager.shared.getPlayers(teamId: team.id)
        print("📊 RosterManagementView: Loaded \(players.count) players for team \(team.name)")
    }

    private func selectPlayer(_ player: PlayerInfo) {
        selectedPlayer = player
        // Populate edit fields
        editedFirstName = player.firstName
        editedLastName = player.lastName
        editedJerseyNumber = "\(player.jerseyNumber)"
        editedPositionId = player.position?.id ?? ""
        editedHeightCm = player.heightCm.map { "\($0)" } ?? ""
        editedWeightKg = player.weightKg.map { "\($0)" } ?? ""
        editedNationality = player.nationality ?? ""
        editedColorIndicator = player.colorIndicator ?? "3b82f6"
        editedNotes = player.notes ?? ""
        // Parse date of birth if available
        if let dob = player.dateOfBirth, let date = parseDateString(dob) {
            editedDateOfBirth = date
        }
    }

    private func parseDateString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func savePlayerChanges() {
        guard let player = selectedPlayer else { return }

        // Parse numbers
        let jerseyNum = Int(editedJerseyNumber) ?? player.jerseyNumber
        let height = Int(editedHeightCm)
        let weight = Int(editedWeightKg)

        let result = GlobalTeamsManager.shared.updatePlayer(
            playerId: player.id,
            firstName: editedFirstName,
            lastName: editedLastName,
            jerseyNumber: jerseyNum,
            positionId: editedPositionId.isEmpty ? nil : editedPositionId,
            heightCm: height,
            weightKg: weight,
            dateOfBirth: formatDate(editedDateOfBirth),
            nationality: editedNationality.isEmpty ? nil : editedNationality,
            dominantFoot: nil,
            colorIndicator: editedColorIndicator,
            notes: editedNotes.isEmpty ? nil : editedNotes
        )

        switch result {
        case .success:
            toastManager.show(message: "Player updated successfully", icon: "checkmark.circle.fill", backgroundColor: "5adc8c")
            if let team = selectedTeam {
                loadPlayers(for: team)
            }
        case .failure(let error):
            toastManager.show(message: "Failed to update player", icon: "xmark.circle.fill", backgroundColor: "ff5252")
            print("Error: \(error)")
        }
    }

    private func deletePlayer(_ player: PlayerInfo) {
        let result = GlobalTeamsManager.shared.deletePlayer(playerId: player.id)

        switch result {
        case .success:
            toastManager.show(message: "Player deleted successfully", icon: "checkmark.circle.fill", backgroundColor: "5adc8c")
            if let team = selectedTeam {
                loadPlayers(for: team)
            }
            if selectedPlayer?.id == player.id {
                selectedPlayer = nil
            }
        case .failure:
            toastManager.show(message: "Failed to delete player", icon: "xmark.circle.fill", backgroundColor: "ff5252")
        }
    }

    private func exportPlayerData() {
        toastManager.show(message: "Player data export coming soon", icon: "arrow.down.doc.fill", backgroundColor: "3b82f6")
    }

    private func handleImportCSV() {
        toastManager.show(message: "CSV import coming soon", icon: "doc.badge.arrow.up.fill", backgroundColor: "3b82f6")
    }

    private func handleExportRoster() {
        toastManager.show(message: "Roster export coming soon", icon: "square.and.arrow.up.fill", backgroundColor: "3b82f6")
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
            // Already on roster
            break
        case .liveCapture:
            await navigationState.navigate(to: .liveCapture)
        }
        }
    }
}

// MARK: - Supporting Views

struct EmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let subtitle: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(theme.tertiaryText)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.tertiaryText)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PlayerTableRowEnhanced: View {
    @EnvironmentObject var themeManager: ThemeManager
    let player: PlayerInfo
    let isSelected: Bool
    let showNotes: Bool

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(player.fullName)
                .frame(width: 160, alignment: .leading)
                .lineLimit(1)
            Text("\(player.jerseyNumber)")
                .frame(width: 62)
            Text(player.positionCode)
                .frame(width: 76)
            Text(player.heightWeight.isEmpty ? "—" : player.heightWeight)
                .font(.system(size: 12))
                .frame(width: 120)
            Text(player.nationality ?? "—")
                .frame(width: 83)

            if showNotes {
                Group {
                    if let notes = player.notes, !notes.isEmpty {
                        Text(notes.count > 40 ? String(notes.prefix(40)) + "..." : notes)
                            .foregroundColor(theme.primaryText)
                    } else {
                        Text("—")
                            .foregroundColor(theme.tertiaryText)
                    }
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 4) {
                if let colorHex = player.colorIndicator {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 8, height: 8)
                }
                Image(systemName: "video.fill")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)
                Text("0")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }
            .frame(width: 80)

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
}

struct LinkedTagRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let name: String
    let time: String
    let color: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 8, height: 8)

            Text(name)
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText)

            Spacer()

            Text(time)
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(theme.secondaryBackground)
        .cornerRadius(4)
    }
}

struct TeamRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let name: String
    let count: String
    let isSelected: Bool

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack {
            Circle()
                .fill(isSelected ? theme.accent : theme.secondaryBorder)
                .frame(width: 9, height: 9)

            Text(name)
                .font(.system(size: 13))
                .foregroundColor(theme.primaryText)

            Spacer()

            Text(count)
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(isSelected ? theme.secondaryBorder.opacity(0.5) : Color.clear)
        .cornerRadius(6)
    }
}

struct PositionRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let name: String
    let count: Int
    let isSelected: Bool

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack {
            Circle()
                .fill(isSelected ? theme.accent : theme.secondaryBorder)
                .frame(width: 9, height: 9)

            Text(name)
                .font(.system(size: 13))
                .foregroundColor(theme.primaryText)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(isSelected ? theme.secondaryBorder.opacity(0.5) : Color.clear)
        .cornerRadius(6)
    }
}

#Preview {
    RosterManagementView()
        .environmentObject(NavigationState())
        .frame(width: 1440, height: 1062)
}
