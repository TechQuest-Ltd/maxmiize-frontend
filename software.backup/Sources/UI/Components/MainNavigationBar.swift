//
//  MainNavigationBar.swift
//  maxmiize-v1
//
//  Created by TechQuest on 12/12/2025.
//

import SwiftUI

enum MainNavItem: String, CaseIterable {
    case maxView = "MaxView"
    case tagging = "Capture"
    case playback = "Playback"
    case notes = "Notes"
    case playlist = "Playlist"
    case annotation = "Annotation"
    case sorter = "Sorter"
    case codeWindow = "Code Window"
    case templates = "Blueprints"
    case roster = "Roster"
    case liveCapture = "Live Capture"

    var isSpecial: Bool {
        return self == .liveCapture
    }
}

struct MainNavigationBar: View {
    @Binding var selectedItem: MainNavItem
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 11) {
                // Main navigation pills (MaxView through Annotation)
                ForEach([MainNavItem.maxView, .tagging, .playback, .notes, .playlist, .annotation], id: \.self) { item in
                    Button(action: {
                        selectedItem = item
                    }) {
                        Text(item.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(selectedItem == item ? Color.white : theme.primaryText)
                            .frame(width: 89, height: 33)
                            .background(pillBackground(for: item))
                            .cornerRadius(25)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Vertical divider
                Rectangle()
                    .fill(theme.primaryBorder)
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 15)

                // Additional pills (Templates, Roster, Live Capture)
                ForEach([MainNavItem.templates, .roster, .liveCapture], id: \.self) { item in
                    Button(action: {
                        selectedItem = item
                    }) {
                        Text(item.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(textColor(for: item))
                            .frame(width: 89, height: 33)
                            .background(pillBackground(for: item))
                            .overlay(
                                item.isSpecial ? RoundedRectangle(cornerRadius: 25)
                                    .stroke(theme.error, lineWidth: 1) : nil
                            )
                            .cornerRadius(25)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(width: geometry.size.width * 0.95, height: 56)
            .padding(.horizontal, 24)
            .background(theme.secondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(theme.primaryBorder, lineWidth: 1)
            )
            .cornerRadius(15)
            .frame(maxWidth: .infinity) // Center the container
        }
        .frame(height: 56)
    }

    private func pillBackground(for item: MainNavItem) -> Color {
        if selectedItem == item {
            return theme.accent // Active - blue
        } else if item.isSpecial {
            return Color(hex: "52242b") // Live Capture - dark red (special case)
        } else {
            return theme.accentSecondary // Inactive - muted blue
        }
    }
    
    private func textColor(for item: MainNavItem) -> Color {
        if selectedItem == item {
            return Color.white // Selected items always have white text
        } else if item.isSpecial {
            // Live Capture always has white text (dark red background)
            return Color.white
        } else {
            return theme.primaryText // Regular unselected items
        }
    }
}

#Preview {
    MainNavigationBar(selectedItem: .constant(.maxView))
        .frame(width: 1440)
        .environmentObject(ThemeManager.shared)
}
