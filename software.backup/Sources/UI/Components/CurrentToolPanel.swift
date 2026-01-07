//
//  CurrentToolPanel.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI

struct CurrentToolPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedTool: AnnotationToolType
    @Binding var strokeThickness: Double
    @Binding var opacity: Double
    @Binding var selectedColor: Color
    @Binding var endCapStyle: EndCapStyle
    @Binding var durationSeconds: Double
    @Binding var freezeDuration: Double
    @Binding var enableKeyframes: Bool
    @State private var isExpanded: Bool = true

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("CURRENT TOOL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.quaternaryText)
                        .tracking(0.5)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.quaternaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                // Active Tool dropdown
                VStack(alignment: .leading, spacing: 6) {
                Text("Active Tool")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Menu {
                    ForEach(AnnotationToolType.allCases, id: \.self) { tool in
                        Button(tool.rawValue) {
                            // Toggle: if same tool is selected, return to select mode
                            if selectedTool == tool && tool != .select {
                                selectedTool = .select
                            } else {
                                selectedTool = tool
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedTool.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 11)
                    .background(theme.surfaceBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.secondaryBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Stroke Thickness slider
            SliderControl(
                label: "Stroke Thickness",
                value: $strokeThickness,
                range: 1...20,
                valueLabel: "\(Int(strokeThickness)) px"
            )

            // Opacity slider
            SliderControl(
                label: "Opacity",
                value: $opacity,
                range: 0...1,
                valueLabel: "\(Int(opacity * 100))%"
            )

            // Duration slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Duration")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)

                    Spacer()

                    Text(durationSeconds == 0 ? "Until end" : String(format: "%.1fs", durationSeconds))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }

                HStack(spacing: 12) {
                    Slider(value: $durationSeconds, in: 0...30, step: 0.5)
                        .accentColor(theme.accent)

                    Button {
                        durationSeconds = 0 // Set to "until end"
                    } label: {
                        Image(systemName: "infinity")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(durationSeconds == 0 ? theme.accent : theme.tertiaryText)
                            .frame(width: 28, height: 28)
                            .background(durationSeconds == 0 ? theme.accent.opacity(0.15) : theme.surfaceBackground)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("How long annotations stay visible")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.quaternaryText)
            }

            // Freeze Duration
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Freeze Duration")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)

                    Spacer()

                    Text(freezeDuration == 0 ? "No freeze" : String(format: "%.1fs", freezeDuration))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                }

                HStack(spacing: 12) {
                    Slider(value: $freezeDuration, in: 0...10, step: 0.5)
                        .accentColor(theme.accent)

                    Button {
                        freezeDuration = 0 // Set to no freeze
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(freezeDuration == 0 ? theme.accent : theme.tertiaryText)
                            .frame(width: 28, height: 28)
                            .background(freezeDuration == 0 ? theme.accent.opacity(0.15) : theme.surfaceBackground)
                            .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Text("Pause video when annotation appears")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.quaternaryText)
            }

            // Enable Keyframe Animation
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyframe Animation")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)

                    Text("Move annotations frame-by-frame")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.quaternaryText)
                }

                Spacer()

                Toggle("", isOn: $enableKeyframes)
                    .labelsHidden()
                    .toggleStyle(CustomToggleStyle())
                    .scaleEffect(0.8)
            }

            // Color picker
            ColorPickerControl(
                selectedColor: $selectedColor,
                label: "Timeline accent"
            )

            // End Cap Style toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("End Cap Style")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)

                    Spacer()

                    Text("Lines & arrows")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.quaternaryText)
                }

                HStack(spacing: 8) {
                    EndCapButton(
                        style: .rounded,
                        isSelected: endCapStyle == .rounded
                    ) {
                        endCapStyle = .rounded
                    }

                    EndCapButton(
                        style: .square,
                        isSelected: endCapStyle == .square
                    ) {
                        endCapStyle = .square
                    }
                }
            }
            }
        }
        .padding(12)
        .background(theme.surfaceBackground)
        .cornerRadius(10)
    }
}

// MARK: - Slider Control

struct SliderControl: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueLabel: String

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                Spacer()

                Text(valueLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.primaryText)
            }

            Slider(value: $value, in: range)
                .accentColor(theme.accent)
        }
    }
}

// MARK: - End Cap Button

struct EndCapButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let style: EndCapStyle
    let isSelected: Bool
    let action: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: action) {
            Text(style.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isSelected ? Color.white : theme.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(isSelected ? theme.accent : theme.surfaceBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.secondaryBorder, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct CurrentToolPanel_Previews: PreviewProvider {
    static var previews: some View {
        CurrentToolPanel(
            selectedTool: .constant(.arrow),
            strokeThickness: .constant(4.0),
            opacity: .constant(0.7),
            selectedColor: .constant(Color(hex: "2979ff")),
            endCapStyle: .constant(.rounded),
            durationSeconds: .constant(5.0),
            freezeDuration: .constant(0),
            enableKeyframes: .constant(false)
        )
        .padding()
        .background(Color(hex: "0d0d0d"))
    }
}
