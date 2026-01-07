//
//  ActionCard.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import SwiftUI

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(theme.accent)
                    .frame(width: 32, height: 32)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 360, maxHeight: .infinity)
            .padding(.horizontal, 27)
            .padding(.vertical, 29)
            .background(theme.surfaceBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}
