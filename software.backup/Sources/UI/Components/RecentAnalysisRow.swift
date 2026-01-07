//
//  RecentAnalysisRow.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import SwiftUI
import AppKit

struct RecentAnalysisRow: View {
    let project: AnalysisProject
    var onRemove: (() -> Void)? = nil
    @EnvironmentObject var navigationState: NavigationState
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showDeleteConfirmation = false
    @State private var isHovering = false

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: {
            navigationState.openProject(id: project.id)
        }) {
            HStack(spacing: 12) {
                // Thumbnail
                Group {
                    if let thumbnail = project.thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.secondaryBorder)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "film")
                                    .font(.system(size: 16))
                                    .foregroundColor(theme.tertiaryText)
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.secondaryBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(project.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                if project.duration == "0h 0m" || project.duration.isEmpty {
                    Text(project.formattedLastOpened)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                } else {
                    Text("\(project.formattedLastOpened) • \(project.duration)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                }
            }

                Spacer()

                // Delete button - only show on hover
                if let onRemove = onRemove, isHovering {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Remove project")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(theme.surfaceBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onRemove?()
            }
        } message: {
            Text("This will permanently delete \"\(project.title)\" and all its resources. This action cannot be undone.")
        }
    }
}
