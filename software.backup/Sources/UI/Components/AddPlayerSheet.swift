//
//  AddPlayerSheet.swift
//  maxmiize-v1
//
//  Created by TechQuest on 24/12/2025.
//

import SwiftUI

struct AddPlayerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    let teamId: String
    let allPositions: [Position]
    let onPlayerAdded: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var jerseyNumber = ""
    @State private var selectedPositionId = ""
    @State private var heightCm = ""
    @State private var weightKg = ""
    @State private var dateOfBirth = Date()
    @State private var nationality = ""
    @State private var colorIndicator = "3b82f6"
    @State private var notes = ""

    @State private var showError = false
    @State private var errorMessage = ""

    let availableColors = ["3b82f6", "10b981", "f59e0b", "ef4444", "8b5cf6", "ec4899"]

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
                    Text("Add New Player")
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
                            Text("Basic Information")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            // First Name
                            VStack(alignment: .leading, spacing: 4) {
                                Text("First name")
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.tertiaryText)

                                TextField("Enter first name", text: $firstName)
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

                                TextField("Enter last name", text: $lastName)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 13))
                                    .foregroundColor(theme.primaryText)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(theme.secondaryBackground)
                                    .cornerRadius(6)
                            }

                            HStack(spacing: 8) {
                                // Jersey Number
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Jersey number")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.tertiaryText)

                                    TextField("10", text: $jerseyNumber)
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
                                                selectedPositionId = position.id
                                            }) {
                                                Text("\(position.code) - \(position.name)")
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            if let position = allPositions.first(where: { $0.id == selectedPositionId }) {
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
                                                    .strokeBorder(theme.primaryText, lineWidth: 2)
                                                    .opacity(colorIndicator == color ? 1 : 0)
                                            )
                                            .onTapGesture {
                                                colorIndicator = color
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

                                    TextField("178", text: $heightCm)
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

                                    TextField("75", text: $weightKg)
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

                                DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
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

                                TextField("Enter nationality", text: $nationality)
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

                                TextEditor(text: $notes)
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

                    Button(action: { savePlayer() }) {
                        Text("Add Player")
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
        .frame(width: 500, height: 700)
        .overlay(
            CustomModal(
                isPresented: $showError,
                type: .error,
                title: "Error",
                message: errorMessage
            )
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func savePlayer() {
        // Validate required fields
        guard !firstName.isEmpty else {
            errorMessage = "Please enter a first name"
            showError = true
            return
        }

        guard !lastName.isEmpty else {
            errorMessage = "Please enter a last name"
            showError = true
            return
        }

        guard !jerseyNumber.isEmpty, let jerseyNum = Int(jerseyNumber) else {
            errorMessage = "Please enter a valid jersey number"
            showError = true
            return
        }

        // Optional fields
        let height = Int(heightCm)
        let weight = Int(weightKg)

        let result = GlobalTeamsManager.shared.createPlayer(
            teamId: teamId,
            firstName: firstName,
            lastName: lastName,
            jerseyNumber: jerseyNum,
            positionId: selectedPositionId.isEmpty ? nil : selectedPositionId,
            heightCm: height,
            weightKg: weight,
            dateOfBirth: formatDate(dateOfBirth),
            nationality: nationality.isEmpty ? nil : nationality,
            dominantFoot: nil,
            colorIndicator: colorIndicator,
            notes: notes.isEmpty ? nil : notes
        )

        switch result {
        case .success:
            onPlayerAdded()
            isPresented = false
        case .failure(let error):
            errorMessage = "Failed to create player: \(error.localizedDescription)"
            showError = true
        }
    }
}
