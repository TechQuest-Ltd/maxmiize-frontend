//
//  TopHeader.swift
//  maxmiize-v1
//
//  Created by TechQuest on 12/12/2025.
//

import SwiftUI
import AppKit

struct TopHeader: View {
    @EnvironmentObject var themeManager: ThemeManager
    let project: OpenedProject?
    let sessionInfo: String
    let lastSaved: String

    var onHome: () -> Void
    var onImport: () -> Void
    var onExport: () -> Void
    var onLayouts: () -> Void
    var onSettings: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Traffic lights area + Home button + Project Info
            HStack(spacing: 8) {
                // macOS traffic lights space - reserve space but don't add extra
                Spacer()
                    .frame(width: 76)

                // Home button - plain icon
                Button(action: onHome) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 13))
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .fastTooltip("Home", delay: 0.2)

                // Divider
                Rectangle()
                    .fill(theme.primaryBorder)
                    .frame(width: 1, height: 14)

                // Project thumbnail
                if let thumbnail = project?.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipped()
                        .cornerRadius(2)
                }

                // Project title and session info inline
                Text(project?.displayTitle ?? "No Project Selected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
                    .padding(.horizontal, 4)

                Text(sessionInfo)
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer()

            // Center: Auto-save indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(theme.success)
                    .frame(width: 6, height: 6)

                Text("Auto-Saved • " + lastSaved)
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            // Right: Action buttons - plain icons only
            HStack(spacing: 12) {
                // Import button
                Button(action: onImport) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(PlainButtonStyle())
                .fastTooltip("Import", delay: 0.2)

                // Export button
                Button(action: onExport) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .fastTooltip("Export", delay: 0.2)

                // Layouts button
                Button(action: onLayouts) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .fastTooltip("Layouts", delay: 0.2)

                // Settings button
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(PlainButtonStyle())
                .fastTooltip("Settings", delay: 0.2)
            }
            .padding(.trailing, 16)
        }
        .frame(height: 40)
        .background(theme.surfaceBackground)
    }
}

#Preview {
    TopHeader(
        project: nil,
        sessionInfo: "Session analyzed every 30 seconds • 6 camera angles linked",
        lastSaved: "00:12 ago",
        onHome: { print("Home") },
        onImport: { print("Import") },
        onExport: { print("Export") },
        onLayouts: { print("Layouts") },
        onSettings: { print("Settings") }
    )
    .frame(width: 1440)
    .background(Color.black)
}
