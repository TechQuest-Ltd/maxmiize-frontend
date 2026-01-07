//
//  ColorPickerControl.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI

struct ColorPickerControl: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedColor: Color
    let label: String

    var theme: ThemeColors {
        themeManager.colors
    }
    
    private var colors: [Color] {
        [
            theme.accent, // Blue
            theme.error, // Red
            theme.warning, // Orange
            theme.warning, // Yellow
            theme.success, // Green
            Color(hex: "00bcd4"), // Teal
            Color(hex: "9c27b0"), // Purple
            theme.tertiaryText  // Gray
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stroke Color")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.quaternaryText)
            }

            // Color swatches
            HStack(spacing: 8) {
                ForEach(0..<colors.count, id: \.self) { index in
                    ColorSwatch(
                        color: colors[index],
                        isSelected: colorsMatch(colors[index], selectedColor)
                    ) {
                        selectedColor = colors[index]
                    }
                }
            }
        }
    }

    private func colorsMatch(_ color1: Color, _ color2: Color) -> Bool {
        // Simple color comparison
        return color1 == color2
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    @EnvironmentObject var themeManager: ThemeManager
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct ColorPickerControl_Previews: PreviewProvider {
    static var previews: some View {
        ColorPickerControl(
            selectedColor: .constant(Color(hex: "2979ff")),
            label: "Timeline accent"
        )
        .padding()
        .background(Color(hex: "0d0d0d"))
    }
}
