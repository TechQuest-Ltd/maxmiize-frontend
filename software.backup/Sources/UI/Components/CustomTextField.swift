//
//  CustomTextField.swift
//  maxmiize-v1
//
//  Created by TechQuest on 10/12/2025.
//

import SwiftUI

struct CustomTextField: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    let placeholder: String
    @Binding var text: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(theme.primaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(theme.primaryBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )
    }
}

struct CustomTextField_Previews: PreviewProvider {
    @State static var text = ""

    static var previews: some View {
        VStack(spacing: 20) {
            CustomTextField(
                label: "Test Field",
                placeholder: "Enter text",
                text: .constant("")
            )

            CustomTextField(
                label: "With Text",
                placeholder: "Enter text",
                text: .constant("Sample text")
            )
        }
        .padding()
        .background(Color(hex: "0d0d0d"))
        .environmentObject(ThemeManager.shared)
    }
}
