//
//  AddTeamSheet.swift
//  maxmiize-v1
//
//  Created by TechQuest on 24/12/2025.
//

import SwiftUI

struct AddTeamSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    let onTeamAdded: () -> Void

    @State private var teamName = ""
    @State private var shortName = ""
    @State private var organization = ""
    @State private var primaryColor = "2979ff"

    @State private var showError = false
    @State private var errorMessage = ""

    let availableColors = ["2979ff", "3b82f6", "10b981", "f59e0b", "ef4444", "8b5cf6", "ec4899"]

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            theme.secondaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Add New Team")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.tertiaryText)
                            .frame(width: 24, height: 24)
                            .background(theme.surfaceBackground)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(theme.surfaceBackground)

                ScrollView {
                    VStack(spacing: 16) {
                        // Basic Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Team Information")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            // Team Name
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Team name")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                TextField("Enter team name", text: $teamName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.primaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                            }

                            // Short Name
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Short name (optional)")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                TextField("e.g., LAL, MCI", text: $shortName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.primaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                            }

                            // Organization
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Organization (optional)")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                TextField("Enter organization name", text: $organization)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.primaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                            }

                            // Primary Color
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Primary color")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                HStack(spacing: 8) {
                                    ForEach(availableColors, id: \.self) { color in
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(theme.primaryText, lineWidth: 2)
                                                    .opacity(primaryColor == color ? 1 : 0)
                                            )
                                            .onTapGesture {
                                                primaryColor = color
                                            }
                                    }
                                }
                            }
                        }
                        .padding(.all, 12)
                        .background(theme.surfaceBackground)
                        .cornerRadius(10)
                    }
                    .padding(.all, 20)
                }

                // Footer Actions
                HStack(spacing: 12) {
                    Button(action: { isPresented = false }) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.surfaceBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(theme.secondaryBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { saveTeam() }) {
                        Text("Create Team")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.accent)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.all, 20)
                .background(theme.surfaceBackground)
            }
        }
        .frame(width: 450, height: 500)
        .overlay(
            CustomModal(
                isPresented: $showError,
                type: .error,
                title: "Error",
                message: errorMessage
            )
        )
    }

    private func saveTeam() {
        // Validate required fields
        guard !teamName.isEmpty else {
            errorMessage = "Please enter a team name"
            showError = true
            return
        }

        // Get Basketball sport ID (basketball-only app)
        let sportTypes = GlobalTeamsManager.shared.getSportTypes()
        guard let basketballSport = sportTypes.first(where: { $0.name == "Basketball" }) else {
            errorMessage = "Basketball sport type not found. Please check database setup."
            showError = true
            return
        }

        let result = GlobalTeamsManager.shared.createTeam(
            name: teamName,
            shortName: shortName.isEmpty ? nil : shortName,
            organization: organization.isEmpty ? nil : organization,
            sportTypeId: basketballSport.id,
            primaryColor: "#\(primaryColor)"
        )

        switch result {
        case .success:
            onTeamAdded()
            isPresented = false
        case .failure(let error):
            errorMessage = "Failed to create team: \(error.localizedDescription)"
            showError = true
        }
    }
}
