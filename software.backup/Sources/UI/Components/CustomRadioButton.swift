//
//  CustomRadioButton.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import SwiftUI

struct CustomRadioButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let isSelected: Bool
    let label: String
    let action: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(isSelected ? "●" : "○")
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? theme.accent : theme.tertiaryText)

                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomRadioButtonGroup: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedIndex: Int
    let options: [String]

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<options.count, id: \.self) { index in
                CustomRadioButton(
                    isSelected: selectedIndex == index,
                    label: options[index],
                    action: { selectedIndex = index }
                )
            }
        }
    }
}

struct CustomRadioButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CustomRadioButton(
                isSelected: true,
                label: "Single Game (multi-angle)",
                action: {}
            )

            CustomRadioButtonGroup(
                selectedIndex: .constant(0),
                options: ["Single Game (multi-angle)", "Multiple Games", "Combine Games"]
            )
        }
        .padding()
        .background(Color(hex: "1a1b1d"))
    }
}
