//
//  CustomCheckbox.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import SwiftUI

struct CustomCheckbox: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isChecked: Bool
    let label: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isChecked ? theme.success : theme.primaryBackground)
                        .frame(width: 16, height: 16)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isChecked ? theme.success : theme.secondaryBorder, lineWidth: 1)
                        .frame(width: 16, height: 16)

                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.white)
                    }
                }

                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomCheckbox_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            CustomCheckbox(
                isChecked: .constant(true),
                label: "Place games sequentially"
            )
            CustomCheckbox(
                isChecked: .constant(false),
                label: "Keep games separate but switchable (tabs in analysis mode)"
            )
        }
        .padding()
        .background(Color(hex: "1a1b1d"))
        .environmentObject(ThemeManager.shared)
    }
}
