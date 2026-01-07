//
//  LayersPanel.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI

struct LayersPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var annotationManager: AnnotationManager
    @State private var isExpanded: Bool = true
    var onSeekToTime: ((Int64) -> Void)?

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
                    HStack(spacing: 6) {
                        Text("LAYERS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.quaternaryText)
                            .tracking(0.5)

                        // Maximize icon
                        Image(systemName: "m.square.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.quaternaryText)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("\(annotationManager.annotations.filter { $0.isVisible }.count) Visible")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.quaternaryText)

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.quaternaryText)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                // Annotation Layers label
                Text("Annotation Layers")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)

                // Layers list
                VStack(spacing: 6) {
                    ForEach(annotationManager.annotations.indices, id: \.self) { index in
                        LayerRowFromAnnotation(
                            annotation: annotationManager.annotations[index],
                            annotationManager: annotationManager,
                            onSeekToTime: onSeekToTime
                        )
                    }

                    if annotationManager.annotations.isEmpty {
                        Text("No annotations yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.quaternaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }
                }
            }
        }
        .padding(12)
        .background(theme.surfaceBackground)
        .cornerRadius(10)
    }
}

// MARK: - Layer Row From Annotation

struct LayerRowFromAnnotation: View {
    @EnvironmentObject var themeManager: ThemeManager
    let annotation: any Annotation
    @ObservedObject var annotationManager: AnnotationManager
    var onSeekToTime: ((Int64) -> Void)?

    private var iconName: String {
        if annotation is ArrowAnnotation {
            return "arrow.up.right"
        } else if annotation is CircleAnnotation {
            return "circle"
        } else if annotation is RectangleAnnotation {
            return "rectangle"
        } else if annotation is FreehandAnnotation {
            return "pencil.line"
        } else if annotation is TextAnnotation {
            return "textformat"
        } else if annotation is RulerAnnotation {
            return "ruler"
        } else if let grid = annotation as? GridAnnotation {
            switch grid.gridType {
            case .grid2x2: return "square.grid.2x2"
            case .grid3x3: return "square.grid.3x3"
            case .grid4x4: return "grid"
            }
        }
        return "questionmark"
    }

    var theme: ThemeColors {
        themeManager.colors
    }
    
    // Format milliseconds to MM:SS.mmm
    private func formatTime(_ milliseconds: Int64) -> String {
        let totalSeconds = Double(milliseconds) / 1000.0
        let minutes = Int(totalSeconds / 60)
        let seconds = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
        let ms = Int((totalSeconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, ms)
    }
    
    private var timeRangeText: String {
        let startTime = formatTime(annotation.startTimeMs)
        if annotation.endTimeMs == 0 {
            return "\(startTime) → End"
        } else {
            let endTime = formatTime(annotation.endTimeMs)
            return "\(startTime) → \(endTime)"
        }
    }

    var body: some View {
        Button {
            // Clicking anywhere on the card (except buttons) seeks to timestamp
            onSeekToTime?(annotation.startTimeMs)
        } label: {
            HStack(spacing: 8) {
                // Tool icon
                ZStack {
                    Circle()
                        .fill(annotation.color)
                        .frame(width: 22, height: 22)

                    Image(systemName: iconName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.white)
                }

                // Layer name and timestamp in one line
                VStack(alignment: .leading, spacing: 2) {
                    Text(annotation.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)

                    // Timestamp display
                    HStack(spacing: 3) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(theme.quaternaryText)

                        Text(timeRangeText)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.quaternaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Visibility toggle
                Button {
                    annotationManager.toggleVisibility(for: annotation)
                } label: {
                    Image(systemName: annotation.isVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())

                // Lock toggle
                Button {
                    annotationManager.toggleLock(for: annotation)
                } label: {
                    Image(systemName: annotation.isLocked ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(theme.primaryBackground)
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

struct LayersPanel_Previews: PreviewProvider {
    static var previews: some View {
        LayersPanel(annotationManager: AnnotationManager.shared)
            .padding()
            .background(Color(hex: "0d0d0d"))
    }
}
