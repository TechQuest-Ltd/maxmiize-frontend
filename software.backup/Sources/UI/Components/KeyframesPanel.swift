//
//  KeyframesPanel.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI

struct KeyframesPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var annotationManager: AnnotationManager
    @Binding var enableAnimation: Bool
    @Binding var currentTime: Double
    @State private var isExpanded: Bool = true

    private let startTime: Double = 744.0  // 00:12:44.00
    private let endTime: Double = 747.0    // 00:12:47.00

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
                    Text("KEYFRAMES")
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
                // Enable Animation toggle
                HStack {
                    Text("Enable Animation")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Toggle("", isOn: $enableAnimation)
                        .labelsHidden()
                        .toggleStyle(CustomToggleStyle())
                        .scaleEffect(0.8)
                }

                // Timeline
                VStack(spacing: 8) {
                // Time labels
                HStack {
                    Text(formatTime(startTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)

                    Spacer()

                    Text(formatTime(endTime))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                }

                // Keyframe timeline
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.secondaryBorder)
                        .frame(height: 24)

                    // Keyframe markers
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // Start marker
                            KeyframeMarker()
                                .offset(x: 0)

                            Spacer()

                            // Middle marker
                            KeyframeMarker()

                            Spacer()

                            // End marker
                            KeyframeMarker()
                                .offset(x: -8)
                        }
                        .frame(width: geometry.size.width)
                    }
                    .frame(height: 24)

                    // Playhead
                    let progress = (currentTime - startTime) / (endTime - startTime)
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(theme.accent)
                            .frame(width: 2, height: 24)
                            .offset(x: geometry.size.width * progress)
                    }
                    .frame(height: 24)
                }
                .frame(height: 24)
            }

            // Control buttons
            HStack {
                Spacer()

                // Minus button
                Button {
                    annotationManager.removeKeyframeForSelectedAnnotation()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(annotationManager.selectedAnnotation != nil ? Color.white : theme.tertiaryText)
                        .frame(width: 24, height: 24)
                        .background(annotationManager.selectedAnnotation != nil ? theme.accent.opacity(0.6) : theme.secondaryBorder)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(annotationManager.selectedAnnotation == nil)

                // Plus button
                Button {
                    annotationManager.addKeyframeForSelectedAnnotation()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(annotationManager.selectedAnnotation != nil ? Color.white : theme.tertiaryText)
                        .frame(width: 24, height: 24)
                        .background(annotationManager.selectedAnnotation != nil ? theme.accent : theme.secondaryBorder)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(annotationManager.selectedAnnotation == nil)
            }
            }
        }
        .padding(12)
        .background(theme.surfaceBackground)
        .cornerRadius(10)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let hundredths = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d:%02d.%02d", 0, minutes, secs, hundredths)
    }
}

// MARK: - Keyframe Marker

struct KeyframeMarker: View {
    @EnvironmentObject var themeManager: ThemeManager
    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.accent)
                .frame(width: 8, height: 8)

            Circle()
                .stroke(theme.primaryBackground, lineWidth: 2)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Preview

struct KeyframesPanel_Previews: PreviewProvider {
    static var previews: some View {
        KeyframesPanel(
            annotationManager: AnnotationManager.shared,
            enableAnimation: .constant(true),
            currentTime: .constant(745.5)
        )
        .padding()
        .background(Color(hex: "0d0d0d"))
    }
}
