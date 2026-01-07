//
//  LayerConfigModal.swift
//  maxmiize-v1
//
//  Layer configuration modal for creating/editing layer buttons
//

import SwiftUI

struct LayerConfigModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    let layer: LayerButton?
    let onSave: (LayerButton) -> Void

    @State private var layerType: String
    @State private var color: String
    @State private var hotkey: String
    @Environment(\.dismiss) var dismiss

    private let availableColors = ["2979ff", "ff5252", "5adc8c", "ffd24c", "9c27b0", "ff9800", "03a9f4", "00bcd4"]

    init(layer: LayerButton?, onSave: @escaping (LayerButton) -> Void) {
        self.layer = layer
        self.onSave = onSave

        _layerType = State(initialValue: layer?.layerType ?? "")
        _color = State(initialValue: layer?.color ?? "2979ff")
        _hotkey = State(initialValue: layer?.hotkey ?? "")
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(layer == nil ? "New Layer" : "Edit Layer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(24)
            .background(theme.secondaryBackground)

            Divider()
                .background(theme.primaryBorder)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Layer Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Layer Name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        TextField("e.g., Shot, Pass, Transition", text: $layerType)
                            .font(.system(size: 14))
                            .foregroundColor(theme.primaryText)
                            .padding(12)
                            .background(theme.surfaceBackground)
                            .cornerRadius(8)
                            .textFieldStyle(.plain)
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(availableColors, id: \.self) { colorHex in
                                Button(action: {
                                    color = colorHex
                                }) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: colorHex))
                                        .frame(height: 48)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(color == colorHex ? theme.primaryText : Color.clear, lineWidth: 3)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }

                    // Hotkey
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keyboard Shortcut (Optional)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        TextField("e.g., S, P, T", text: $hotkey)
                            .font(.system(size: 14))
                            .foregroundColor(theme.primaryText)
                            .padding(12)
                            .background(theme.surfaceBackground)
                            .cornerRadius(8)
                            .textFieldStyle(.plain)
                    }
                }
                .padding(24)
            }

            Divider()
                .background(theme.primaryBorder)

            // Footer
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.primaryBorder)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: saveLayer) {
                    Text(layer == nil ? "Create Layer" : "Save Changes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(layerType.isEmpty ? theme.tertiaryText : theme.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(layerType.isEmpty)
            }
            .padding(24)
            .background(theme.secondaryBackground)
        }
        .frame(width: 500, height: 600)
        .background(theme.primaryBackground)
    }

    private func saveLayer() {
        let newLayer = LayerButton(
            id: layer?.id ?? UUID().uuidString,
            layerType: layerType,
            color: color,
            hotkey: hotkey.isEmpty ? nil : hotkey.uppercased(),
            activates: layer?.activates,
            x: layer?.x,  // Preserve canvas position
            y: layer?.y
        )
        onSave(newLayer)
    }
}
