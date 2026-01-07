//
//  CustomLabel.swift
//  maxmiize-v1
//
//  Created by TechQuest on 10/12/2025.
//

import SwiftUI

struct CustomLabel: View {
    @EnvironmentObject var themeManager: ThemeManager
    let text: String
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    let paddingHorizontal: CGFloat
    let paddingVertical: CGFloat
    let paddingTop: CGFloat
    let paddingBottom: CGFloat
    let paddingLeading: CGFloat
    let paddingTrailing: CGFloat

    init(
        _ text: String,
        size: CGFloat = 13,
        weight: Font.Weight = .semibold,
        color: Color = Color(hex: "9a9a9a"),
        paddingHorizontal: CGFloat? = nil,
        paddingVertical: CGFloat? = nil,
        paddingTop: CGFloat = 0,
        paddingBottom: CGFloat = 0,
        paddingLeading: CGFloat = 0,
        paddingTrailing: CGFloat = 0
    ) {
        self.text = text
        self.size = size
        self.weight = weight
        self.color = color
        self.paddingHorizontal = paddingHorizontal ?? 0
        self.paddingVertical = paddingVertical ?? 0
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.paddingLeading = paddingLeading
        self.paddingTrailing = paddingTrailing
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .foregroundColor(color)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.top, paddingVertical > 0 ? paddingVertical : paddingTop)
            .padding(.bottom, paddingVertical > 0 ? paddingVertical : paddingBottom)
            .padding(.leading, paddingHorizontal > 0 ? paddingHorizontal : paddingLeading)
            .padding(.trailing, paddingHorizontal > 0 ? paddingHorizontal : paddingTrailing)
    }
}

struct CustomLabel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            CustomLabel("Default Label")

            CustomLabel("White Title", size: 16, weight: .semibold, color: .white)

            CustomLabel("Small Secondary", size: 12, weight: .regular, color: Color(hex: "85868a"))

            CustomLabel("Very Long Filename That Should Truncate In The Middle.mp4", size: 12)

            // With horizontal padding
            CustomLabel("Padded Horizontally", paddingHorizontal: 20)
                .background(Color(hex: "0d0d0d"))

            // With vertical padding
            CustomLabel("Padded Vertically", paddingVertical: 10)
                .background(Color(hex: "0d0d0d"))

            // With specific side padding
            CustomLabel("Leading Padding", paddingLeading: 20)
                .background(Color(hex: "0d0d0d"))
        }
        .padding()
        .background(Color(hex: "1a1b1d"))
    }
}
