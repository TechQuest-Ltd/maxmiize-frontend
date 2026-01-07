//
//  QuickActionsPanel.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI

struct QuickActionsPanel: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var annotationManager: AnnotationManager
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
                    HStack(spacing: 6) {
                        Text("QUICK ACTIONS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.quaternaryText)
                            .tracking(0.5)

                        // Maximize icon
                        Image(systemName: "m.square.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(theme.quaternaryText)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(theme.quaternaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                // Action buttons row 1
                HStack(spacing: 8) {
                    QuickActionButton(
                        icon: "trash",
                        label: "Delete Layer",
                        isDisabled: annotationManager.selectedAnnotation == nil
                    ) {
                        if let selected = annotationManager.selectedAnnotation {
                            annotationManager.removeAnnotation(selected)
                            annotationManager.selectedAnnotationId = nil
                        }
                    }

                    QuickActionButton(
                        icon: "doc.on.doc",
                        label: "Duplicate",
                        isDisabled: annotationManager.selectedAnnotation == nil
                    ) {
                        if let selected = annotationManager.selectedAnnotation {
                            annotationManager.duplicateAnnotation(selected)
                        }
                    }
                }

                // Action buttons row 2
                HStack(spacing: 8) {
                    QuickActionButton(
                        icon: "arrow.up.and.down.and.arrow.left.and.right",
                        label: "Move",
                        isDisabled: annotationManager.selectedAnnotation == nil || annotationManager.selectedAnnotation?.isLocked == true
                    ) {
                        // Move action - annotation is already movable via drag
                        print("📍 Annotation is movable - drag to reposition")
                    }

                    QuickActionButton(
                        icon: "lock.rotation",
                        label: annotationManager.selectedAnnotation?.isLocked == true ? "Unlock" : "Lock",
                        isDisabled: annotationManager.selectedAnnotation == nil
                    ) {
                        if let selected = annotationManager.selectedAnnotation {
                            annotationManager.toggleLock(for: selected)
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

// MARK: - Quick Action Button

struct QuickActionButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let label: String
    var isDisabled: Bool = false
    let action: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDisabled ? theme.disabled : theme.tertiaryText)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isDisabled ? theme.disabled : .white)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.primaryBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.secondaryBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Preview

struct QuickActionsPanel_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionsPanel(annotationManager: AnnotationManager.shared)
            .padding()
            .background(Color(hex: "0d0d0d"))
    }
}
