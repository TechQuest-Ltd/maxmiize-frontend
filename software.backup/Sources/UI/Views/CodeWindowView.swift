//
//  CodeWindowView.swift
//  maxmiize-v1
//
//  Created by TechQuest on 23/12/2025.
//

import SwiftUI

/// CodeWindow - Interface for creating custom moments and layers
/// Similar to SportCode's CodeWindow feature
struct CodeWindowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var navigationState: NavigationState

    // State for custom moments
    @State private var customMoments: [MomentButton] = []
    @State private var customLayers: [LayerButton] = []

    // Form state for creating new moment
    @State private var newMomentName: String = ""
    @State private var newMomentColor: Color = Color(hex: "2979ff")
    @State private var newMomentHotkey: String = ""
    @State private var newMomentDeactivates: [String] = []

    // Form state for creating new layer
    @State private var newLayerName: String = ""
    @State private var newLayerColor: Color = Color(hex: "2979ff")
    @State private var newLayerHotkey: String = ""
    @State private var newLayerActivates: [String] = []

    // UI state
    @State private var selectedTab: CodeTab = .moments
    @State private var showColorPicker: Bool = false

    enum CodeTab {
        case moments
        case layers
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(theme.surfaceBackground)

            Divider()
                .background(theme.primaryBorder)

            // Tab selector
            HStack(spacing: 0) {
                tabButton(title: "Moments", tab: .moments)
                tabButton(title: "Layers", tab: .layers)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(theme.cardBackground)

            Divider()
                .background(theme.primaryBorder)

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    if selectedTab == .moments {
                        momentCreator
                        momentsList
                    } else {
                        layerCreator
                        layersList
                    }
                }
                .padding(24)
            }
        }
        .background(theme.primaryBackground)
        .onAppear {
            loadCustomCodes()
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Code Window")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Text("Create custom moments and layers for your analysis")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()
        }
    }

    // MARK: - Tab Button
    private func tabButton(title: String, tab: CodeTab) -> some View {
        Button(action: {
            selectedTab = tab
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(selectedTab == tab ? .white : theme.tertiaryText)

                Rectangle()
                    .fill(selectedTab == tab ? theme.accent : Color.clear)
                    .frame(height: 2)
            }
            .frame(width: 120)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Moment Creator
    private var momentCreator: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create New Moment")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryText)

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                TextField("e.g., Fast Break, Corner Kick", text: $newMomentName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
            }

            // Color picker
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)

                    ColorPicker("", selection: $newMomentColor)
                        .labelsHidden()
                        .frame(width: 100, height: 32)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Hotkey (optional)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)

                    TextField("e.g., F", text: $newMomentHotkey)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 12))
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.primaryBorder)
                        .cornerRadius(6)
                        .frame(width: 100)
                }
            }

            // Create button
            Button(action: createMoment) {
                Text("Create Moment")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(newMomentName.isEmpty ? theme.primaryBorder : theme.accent)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(newMomentName.isEmpty)
        }
        .padding(20)
        .background(theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Layer Creator
    private var layerCreator: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create New Layer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryText)

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                TextField("e.g., Goal, Assist, Foul", text: $newLayerName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
            }

            // Color picker
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)

                    ColorPicker("", selection: $newLayerColor)
                        .labelsHidden()
                        .frame(width: 100, height: 32)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Hotkey (optional)")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)

                    TextField("e.g., G", text: $newLayerHotkey)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 12))
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.primaryBorder)
                        .cornerRadius(6)
                        .frame(width: 100)
                }
            }

            // Create button
            Button(action: createLayer) {
                Text("Create Layer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(newLayerName.isEmpty ? theme.primaryBorder : theme.accent)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(newLayerName.isEmpty)
        }
        .padding(20)
        .background(theme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Moments List
    private var momentsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Moments (\(customMoments.count))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryText)

            if customMoments.isEmpty {
                Text("No custom moments yet. Create one above!")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                    ForEach(customMoments) { moment in
                        momentCard(moment)
                    }
                }
            }
        }
    }

    // MARK: - Layers List
    private var layersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Layers (\(customLayers.count))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.primaryText)

            if customLayers.isEmpty {
                Text("No custom layers yet. Create one above!")
                    .font(.system(size: 12))
                    .foregroundColor(theme.tertiaryText)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                    ForEach(customLayers) { layer in
                        layerCard(layer)
                    }
                }
            }
        }
    }

    // MARK: - Moment Card
    private func momentCard(_ moment: MomentButton) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: moment.color))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(moment.category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.primaryText)

                if let hotkey = moment.hotkey {
                    Text("Hotkey: \(hotkey)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                }
            }

            Spacer()

            Button(action: {
                deleteMoment(moment)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(theme.primaryBorder)
        .cornerRadius(8)
    }

    // MARK: - Layer Card
    private func layerCard(_ layer: LayerButton) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: layer.color))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(layer.layerType)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.primaryText)

                if let hotkey = layer.hotkey {
                    Text("Hotkey: \(hotkey)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                }
            }

            Spacer()

            Button(action: {
                deleteLayer(layer)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(theme.error)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(theme.primaryBorder)
        .cornerRadius(8)
    }

    // MARK: - Actions
    private func loadCustomCodes() {
        // TODO: Load from database/UserDefaults
        print("📋 Loading custom moments and layers")
    }

    private func createMoment() {
        let colorHex = newMomentColor.toHex()
        let newMoment = MomentButton(
            category: newMomentName,
            color: colorHex,
            hotkey: newMomentHotkey.isEmpty ? nil : newMomentHotkey,
            mutualExclusiveWith: newMomentDeactivates.isEmpty ? nil : newMomentDeactivates
        )

        customMoments.append(newMoment)

        // TODO: Save to database
        print("✅ Created moment: \(newMomentName)")

        // Reset form
        newMomentName = ""
        newMomentColor = theme.accent
        newMomentHotkey = ""
        newMomentDeactivates = []
    }

    private func createLayer() {
        let colorHex = newLayerColor.toHex()
        let newLayer = LayerButton(
            layerType: newLayerName,
            color: colorHex,
            hotkey: newLayerHotkey.isEmpty ? nil : newLayerHotkey,
            activates: newLayerActivates.isEmpty ? nil : newLayerActivates
        )

        customLayers.append(newLayer)

        // TODO: Save to database
        print("✅ Created layer: \(newLayerName)")

        // Reset form
        newLayerName = ""
        newLayerColor = theme.accent
        newLayerHotkey = ""
        newLayerActivates = []
    }

    private func deleteMoment(_ moment: MomentButton) {
        customMoments.removeAll { $0.id == moment.id }
        // TODO: Delete from database
        print("🗑️ Deleted moment: \(moment.category)")
    }

    private func deleteLayer(_ layer: LayerButton) {
        customLayers.removeAll { $0.id == layer.id }
        // TODO: Delete from database
        print("🗑️ Deleted layer: \(layer.layerType)")
    }
}

// MARK: - Color Extension
extension Color {
    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "000000" }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - Preview
#Preview {
    CodeWindowView()
        .environmentObject(NavigationState())
        .frame(width: 1200, height: 800)
        .background(Color.black)
}
