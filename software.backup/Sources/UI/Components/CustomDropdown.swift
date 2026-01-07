//
//  CustomDropdown.swift
//  maxmiize-v1
//
//  Created by TechQuest on 09/12/2025.
//

import SwiftUI

struct CustomDropdown: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    @Binding var selectedValue: String
    let options: [String]
    let placeholder: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Picker(selection: $selectedValue, label: EmptyView()) {
            Text(placeholder)
                .tag("")
                .foregroundColor(theme.tertiaryText)

            ForEach(options, id: \.self) { option in
                Text(option)
                    .tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .opacity(0)
        .frame(maxWidth: .infinity)
        .overlay(
            HStack {
                Text(selectedValue.isEmpty ? placeholder : selectedValue)
                    .font(.system(size: 14))
                    .foregroundColor(selectedValue.isEmpty ? theme.tertiaryText : theme.primaryText)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.surfaceBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )
            .allowsHitTesting(false)
        )
    }
}

//struct CustomDropdown_Previews: PreviewProvider {
//    @State static var selectedValue = "Endzone"
//
//    static var previews: some View {
//        CustomDropdown(
//            label: "Test Dropdown",
//            selectedValue: .constant("Endzone"),
//            options: ["Main Broadcast", "Endzone", "Tactical", "Sideline"],
//            placeholder: "Select option"
//        )
//        .padding()
//        .background(theme.secondaryBackground)
//    }
//}

#Preview {
    CustomDropdown(label: "Angle", selectedValue: .constant("Endzone"), options: ["A","b","C"], placeholder: "Please Enter the angle")
        .environmentObject(ThemeManager.shared)
}
