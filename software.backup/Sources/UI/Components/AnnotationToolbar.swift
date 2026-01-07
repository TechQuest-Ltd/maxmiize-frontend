//
//  AnnotationToolbar.swift
//  maxmiize-v1
//
//  Created by TechQuest
//

import SwiftUI

struct AnnotationToolbar: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedTool: AnnotationToolType
    @ObservedObject var annotationManager: AnnotationManager

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        HStack(spacing: 16) {
            // Mode indicator
            HStack(spacing: 6) {
                Text(selectedTool == .select ? "MOVE MODE" : "DRAW MODE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(selectedTool == .select ? theme.accent : theme.success)
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedTool == .select ? theme.accent.opacity(0.15) : theme.success.opacity(0.15))
                    .cornerRadius(4)
            }

            Divider()
                .frame(height: 24)
                .background(theme.secondaryBorder)

            // Drawing tools section
            HStack(spacing: 8) {
                // SELECT TOOL - Move mode (toggleable)
                ToolButton(
                    tool: .select,
                    isSelected: selectedTool == .select
                ) {
                    // Toggle: if already selected, deselect (no tool active)
                    // Note: We don't have a "none" state, so keep select as minimum
                    if selectedTool == .select {
                        // Stay in select mode - it's the default safe state
                    } else {
                        selectedTool = .select
                    }
                }

                Divider()
                    .frame(width: 1, height: 24)
                    .background(theme.secondaryBorder)

                // DRAWING TOOLS (all toggleable)
                ToolButton(
                    tool: .arrow,
                    isSelected: selectedTool == .arrow
                ) {
                    toggleTool(.arrow)
                }

                ToolButton(
                    tool: .pen,
                    isSelected: selectedTool == .pen
                ) {
                    toggleTool(.pen)
                }

                ToolButton(
                    tool: .circle,
                    isSelected: selectedTool == .circle
                ) {
                    toggleTool(.circle)
                }

                ToolButton(
                    tool: .rectangle,
                    isSelected: selectedTool == .rectangle
                ) {
                    toggleTool(.rectangle)
                }

                ToolButton(
                    tool: .text,
                    isSelected: selectedTool == .text
                ) {
                    toggleTool(.text)
                }

                ToolButton(
                    tool: .ruler,
                    isSelected: selectedTool == .ruler
                ) {
                    toggleTool(.ruler)
                }

                ToolButton(
                    tool: .grid1,
                    isSelected: selectedTool == .grid1
                ) {
                    toggleTool(.grid1)
                }

                ToolButton(
                    tool: .grid2,
                    isSelected: selectedTool == .grid2
                ) {
                    toggleTool(.grid2)
                }

                ToolButton(
                    tool: .grid3,
                    isSelected: selectedTool == .grid3
                ) {
                    toggleTool(.grid3)
                }
            }

            Spacer()

            // Right side controls
            HStack(spacing: 12) {
                // Color picker button
                ColorPickerButton(annotationManager: annotationManager)

                // Stroke width control (combined display + button)
                StrokeWidthControl(annotationManager: annotationManager)

                // Opacity slider button
                OpacityButton(annotationManager: annotationManager)

                Divider()
                    .frame(height: 20)
                    .background(theme.secondaryBorder)

                // Undo
                Button {
                    annotationManager.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(annotationManager.canUndo ? theme.tertiaryText : theme.disabled)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!annotationManager.canUndo)

                // Redo
                Button {
                    annotationManager.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(annotationManager.canRedo ? theme.tertiaryText : theme.disabled)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!annotationManager.canRedo)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(theme.primaryBackground)
        .overlay(
            Rectangle()
                .stroke(theme.secondaryBorder, lineWidth: 1)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Toggle Tool

    private func toggleTool(_ tool: AnnotationToolType) {
        if selectedTool == tool {
            // Tool is already selected, toggle it off (return to select mode)
            selectedTool = .select
            print("🔄 Toggled off \(tool.rawValue), returning to Select mode")
        } else {
            // Activate the tool
            selectedTool = tool
            print("✏️ Activated \(tool.rawValue) tool")
        }
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let tool: AnnotationToolType
    let isSelected: Bool
    let action: () -> Void

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 36, height: 36)
                }

                Image(systemName: tool.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? Color.white : theme.tertiaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Color Picker Button

struct ColorPickerButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var annotationManager: AnnotationManager
    @State private var showPopover = false
    
    var theme: ThemeColors {
        themeManager.colors
    }
    
    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Circle()
                .fill(annotationManager.selectedColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(theme.primaryBorder, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stroke Color")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                ColorPickerControl(
                    selectedColor: $annotationManager.selectedColor,
                    label: ""
                )
            }
            .padding(16)
            .frame(width: 280)
            .background(theme.surfaceBackground)
        }
    }
}

// MARK: - Stroke Width Control

struct StrokeWidthControl: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var annotationManager: AnnotationManager
    @State private var showPopover = false
    
    var theme: ThemeColors {
        themeManager.colors
    }
    
    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 6) {
                // Stroke width display
                HStack(spacing: 4) {
                    Text("\(Int(annotationManager.strokeWidth))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                    Text("px")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.tertiaryText)
                }
                
                Divider()
                    .frame(width: 1, height: 16)
                    .background(theme.secondaryBorder)
                
                // Slider icon
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.surfaceBackground)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Stroke Width")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                SliderControl(
                    label: "Thickness",
                    value: Binding(
                        get: { Double(annotationManager.strokeWidth) },
                        set: { annotationManager.strokeWidth = CGFloat($0) }
                    ),
                    range: 1...20,
                    valueLabel: "\(Int(annotationManager.strokeWidth)) px"
                )
            }
            .padding(16)
            .frame(width: 280)
            .background(theme.surfaceBackground)
        }
    }
}

// MARK: - Opacity Button

struct OpacityButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var annotationManager: AnnotationManager
    @State private var showPopover = false
    
    var theme: ThemeColors {
        themeManager.colors
    }
    
    var body: some View {
        Button {
            showPopover.toggle()
        } label: {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.tertiaryText)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Opacity")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                
                SliderControl(
                    label: "Transparency",
                    value: $annotationManager.opacity,
                    range: 0...1,
                    valueLabel: "\(Int(annotationManager.opacity * 100))%"
                )
            }
            .padding(16)
            .frame(width: 280)
            .background(theme.surfaceBackground)
        }
    }
}

// MARK: - Preview

struct AnnotationToolbar_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationToolbar(selectedTool: .constant(.arrow), annotationManager: AnnotationManager.shared)
            .background(Color(hex: "1a1b1d"))
    }
}
