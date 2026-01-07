//
//  TaggingPanel.swift
//  maxmiize-v1
//
//  Created by TechQuest on 14/12/2025.
//
// NOTE: This component is temporarily disabled during the Tag/Label architecture migration.
// It will be rebuilt in a future phase to align with the new Tag and Label models.
// For now, tagging is handled directly in TaggingView.swift

import SwiftUI

struct TaggingPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var navigationState: NavigationState

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Tag Panel")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.primaryText)

            Text("This panel is being rebuilt for the new Tag/Label architecture.")
                .font(.system(size: 10))
                .foregroundColor(theme.tertiaryText)
                .padding(.top, 8)
        }
        .padding(12)
        .background(theme.surfaceBackground)
        .cornerRadius(12)
    }
}

#Preview {
    TaggingPanel()
        .environmentObject(NavigationState())
        .frame(width: 320, height: 200)
        .background(Color.black)
}
