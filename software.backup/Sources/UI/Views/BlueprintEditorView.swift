//
//  BlueprintEditorView.swift
//  maxmiize-v1
//
//  Blueprint Editor - Design moment categories, colors, and keyboard mappings
//

import SwiftUI
import UniformTypeIdentifiers

struct BlueprintEditorView: View {
    @EnvironmentObject var navigationState: NavigationState
    @State private var currentBlueprint: Blueprint
    @State private var selectedMoment: MomentButton?
    @State private var selectedLayer: LayerButton?
    @State private var editingMoment: MomentButton?
    @State private var editingLayer: LayerButton?
    @State private var snapToGrid = true
    @State private var showCategoriesOutline = false
    @State private var expandedCategories: Set<String> = ["Offense"]
    @State private var editingMomentName: String = ""
    @State private var selectedMainNav: MainNavItem = .templates
    @State private var availableMomentCategories: Set<String> = []
    @State private var showingAddCategorySheet = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor = "2979ff"
    @State private var availableLayerTypes: Set<String> = []
    @State private var canvasZoom: CGFloat = 1.0
    @State private var draggedLayerId: String?
    @State private var isZoomToolActive: Bool = false
    @State private var canvasScrollOffset: CGPoint = .zero
    @State private var currentDragOffset: CGSize = .zero
    @State private var draggingButtonId: String?
    @State private var zoomFocusPoint: CGPoint = CGPoint(x: 1000, y: 750)  // Center of canvas

    // Blueprint management
    @State private var availableBlueprints: [Blueprint] = []
    @State private var selectedBlueprintId: String?
    @State private var showingDeleteConfirmation = false
    @State private var saveStatus: SaveStatus = .none
    @State private var savedBlueprint: Blueprint?  // Track saved version for comparison
    @State private var editingBlueprintName: Bool = false
    @State private var blueprintNameText: String = ""

    enum SaveStatus: Equatable {
        case none
        case saving
        case success
        case failure(String)
    }

    // Drag and drop state
    @State private var draggedMomentId: String?
    @State private var hoveredDropZone: DropZoneType?
    @State private var hoveredDropCategory: String? = nil
    @State private var globalCursorPosition: CGPoint = .zero

    enum DropZoneType: Equatable {
        case sidebar
        case newCategory
        case extendRow
        case categoryRow(String)
    }

    private var saveButtonText: String {
        switch saveStatus {
        case .none: return "Save Blueprint"
        case .saving: return "Saving..."
        case .success: return "Saved!"
        case .failure: return "Save Failed"
        }
    }

    private var saveButtonColor: Color {
        switch saveStatus {
        case .none: return theme.accent
        case .saving: return theme.tertiaryText
        case .success: return theme.success
        case .failure: return theme.error
        }
    }

    private var hasUnsavedChanges: Bool {
        guard let saved = savedBlueprint else { return false }

        // Compare name
        if currentBlueprint.name != saved.name { return true }

        // Compare moment count and IDs
        if currentBlueprint.moments.count != saved.moments.count { return true }
        let currentMomentIds = Set(currentBlueprint.moments.map { $0.id })
        let savedMomentIds = Set(saved.moments.map { $0.id })
        if currentMomentIds != savedMomentIds { return true }

        // Compare layer count and IDs
        if currentBlueprint.layers.count != saved.layers.count { return true }
        let currentLayerIds = Set(currentBlueprint.layers.map { $0.id })
        let savedLayerIds = Set(saved.layers.map { $0.id })
        if currentLayerIds != savedLayerIds { return true }

        return false
    }

    // Grouped moments by category for SIDEBAR (only shows moments NOT on canvas)
    private var sidebarMomentsByCategory: [String: [MomentButton]] {
        var result: [String: [MomentButton]] = [:]

        // Only show moments that don't have canvas positions (x, y)
        // Moments with positions are considered "on the canvas"
        for moment in currentBlueprint.moments {
            // Skip moments that are already positioned on canvas
            if moment.x == nil && moment.y == nil {
                result[moment.category, default: []].append(moment)
            }
        }

        // Don't show empty categories - only show categories that have moments in sidebar
        // This keeps the sidebar clean and focused

        return result
    }

    // Grouped moments by category for CANVAS (only actual blueprint moments)
    private var canvasMomentsByCategory: [String: [MomentButton]] {
        Dictionary(grouping: currentBlueprint.moments) { $0.category }
    }

    // Layers for SIDEBAR (includes placeholders from DB)
    // Only show layers that don't have canvas positions (x, y)
    private var sidebarLayers: [LayerButton] {
        var result: [LayerButton] = []

        // Only add layers that don't have canvas positions (x, y)
        // Layers with positions are considered "on the canvas"
        for layer in currentBlueprint.layers {
            if layer.x == nil && layer.y == nil {
                result.append(layer)
            }
        }

        // Add placeholders for layer types that exist in DB but not in blueprint
        for layerType in availableLayerTypes {
            if !currentBlueprint.layers.contains(where: { $0.layerType == layerType }) {
                let placeholder = LayerButton(
                    id: "placeholder-layer-\(layerType)",
                    layerType: layerType,
                    color: "666666",
                    hotkey: nil,
                    activates: nil
                )
                result.append(placeholder)
            }
        }

        return result
    }

    init(blueprint: Blueprint? = nil) {
        if let blueprint = blueprint {
            _currentBlueprint = State(initialValue: blueprint)
            _selectedBlueprintId = State(initialValue: blueprint.id)
        } else {
            // Create a temporary blueprint, will be replaced on appear
            let temp = Blueprint(
                name: "New Blueprint",
                moments: DefaultMomentCategories.all,
                layers: DefaultLayerTypes.all
            )
            _currentBlueprint = State(initialValue: temp)
        }
    }
    
    @ObservedObject private var themeManager = ThemeManager.shared

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Main Navigation Bar
                MainNavigationBar(selectedItem: $selectedMainNav)
                    .onChange(of: selectedMainNav) { newValue in
                        handleNavigationChange(newValue)
                    }

                // Blueprint Header Controls (below tabs)
                blueprintHeaderControls

                // Main Content
                GeometryReader { geometry in
                    HStack(spacing: 12) {
                        // Left Sidebar - Moment Categories
                        leftSidebar
                            .frame(width: 320)

                        // Center Canvas
                        centerCanvas
                            .frame(maxWidth: .infinity)

                        // Right Sidebar - Settings
                        rightSidebar
                            .frame(width: 380)
                    }
                    .padding(12)
                }
            }

            // Global drag preview overlay (always on top, above everything)
            if let draggedId = draggingButtonId {
                dragPreviewOverlay(draggedId: draggedId)
            }
        }
        .onAppear {
            loadBlueprints()
            loadAvailableMoments()

            // Log current blueprint state
            print("📋 [BLUEPRINT LOADED] Total moments: \(currentBlueprint.moments.count)")
            for (index, moment) in currentBlueprint.moments.enumerated() {
                let isPlaceholder = moment.id.hasPrefix("placeholder-")
                print("  [\(index)] '\(moment.category)' - id: \(moment.id.prefix(8))..., placeholder: \(isPlaceholder), pos: (\(moment.x?.description ?? "nil"), \(moment.y?.description ?? "nil"))")
            }
        }
        .alert("Delete Blueprint", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteCurrentBlueprint()
            }
        } message: {
            Text("Are you sure you want to delete '\(currentBlueprint.name)'? This cannot be undone.")
        }
        .sheet(item: $editingMoment) { moment in
            MomentConfigModal(
                moment: moment,
                existingMoments: currentBlueprint.moments,
                onSave: { savedMoment in
                    if let index = currentBlueprint.moments.firstIndex(where: { $0.id == savedMoment.id }) {
                        // Update existing moment
                        currentBlueprint.moments[index] = savedMoment
                    } else {
                        // Add new moment
                        currentBlueprint.moments.append(savedMoment)
                    }

                    // Save to database and update selection after save completes
                    let isNewMoment = moment.id == "new-moment-placeholder"
                    saveBlueprintAndUpdateSelection(momentId: isNewMoment ? nil : savedMoment.id)

                    editingMoment = nil
                },
                isNewMoment: moment.id == "new-moment-placeholder"
            )
        }
        .sheet(item: $editingLayer) { layer in
            LayerConfigModal(
                layer: layer,
                onSave: { savedLayer in
                    if let index = currentBlueprint.layers.firstIndex(where: { $0.id == savedLayer.id }) {
                        // Editing existing layer in blueprint
                        currentBlueprint.layers[index] = savedLayer

                        // Save to database immediately
                        saveBlueprint()
                    } else {
                        // Creating new layer - add to available types (database)
                        availableLayerTypes.insert(savedLayer.layerType)
                        print("✅ Created new layer type: \(savedLayer.layerType)")
                        // Note: Layer is now available to drag to blueprint from sidebar
                    }
                    editingLayer = nil
                }
            )
        }
        .sheet(isPresented: $showingAddCategorySheet) {
            VStack(spacing: 20) {
                Text("Create New Category")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.primaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.secondaryText)

                    TextField("Enter category name", text: $newCategoryName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(theme.primaryText)
                        .padding(12)
                        .background(theme.surfaceBackground)
                        .cornerRadius(6)

                    Text("Color")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.secondaryText)
                        .padding(.top, 8)

                    HStack(spacing: 12) {
                        ForEach(["5adc8c", "ff5252", "2979ff", "ffd24c", "9c27b0", "ff9800", "00bcd4", "ff6f00"], id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    newCategoryColor == color ?
                                        Circle().stroke(Color.white, lineWidth: 3) : nil
                                )
                                .onTapGesture {
                                    newCategoryColor = color
                                }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button("Cancel") {
                        showingAddCategorySheet = false
                        newCategoryName = ""
                        newCategoryColor = "2979ff"
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.secondaryText)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(theme.surfaceBackground)
                    .cornerRadius(6)

                    Button("Create") {
                        createNewCategory()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(newCategoryName.isEmpty ? theme.tertiaryText : theme.accent)
                    .cornerRadius(6)
                    .disabled(newCategoryName.isEmpty)
                }
            }
            .padding(24)
            .frame(width: 400)
            .background(theme.secondaryBackground)
        }
    }

    // MARK: - Navigation Handler

    private func handleNavigationChange(_ item: MainNavItem) {
        Task { @MainActor in
            switch item {
            case .maxView:
                await navigationState.navigate(to: .maxView)
            case .tagging:
                await navigationState.navigate(to: .moments)
            case .playback:
                await navigationState.navigate(to: .playback)
            case .notes:
                await navigationState.navigate(to: .notes)
            case .playlist:
                await navigationState.navigate(to: .playlist)
            case .annotation:
                await navigationState.navigate(to: .annotation)
            case .sorter:
                await navigationState.navigate(to: .sorter)
            case .codeWindow:
                await navigationState.navigate(to: .codeWindow)
            case .templates:
                // Already on blueprints
                break
            case .roster:
                await navigationState.navigate(to: .rosterManagement)
            case .liveCapture:
                await navigationState.navigate(to: .liveCapture)
            }
        }
    }

    // MARK: - Data Loading

    private func loadBlueprints() {
        // Load all available blueprints
        availableBlueprints = DatabaseManager.shared.getBlueprints()

        // DEBUG: Print all loaded blueprints
        print("📋 DEBUG: Loaded \(availableBlueprints.count) blueprints from database")
        for blueprint in availableBlueprints {
            print("  - '\(blueprint.name)': \(blueprint.moments.count) moments, \(blueprint.layers.count) layers")
            if blueprint.name == "My blueprint" {
                print("    📊 My blueprint details:")
                print("      Moments: \(blueprint.moments.map { "\($0.name) (cat:\($0.category), x:\($0.x?.description ?? "nil"), y:\($0.y?.description ?? "nil"))" })")
                print("      Layers: \(blueprint.layers.map { "\($0.layerType) (x:\($0.x?.description ?? "nil"), y:\($0.y?.description ?? "nil"))" })")
            }
        }

        // If no blueprints exist, create a default one
        if availableBlueprints.isEmpty {
            // Load ALL categories from database (not just defaults)
            let allCategories = DatabaseManager.shared.getCategories()

            // Create placeholder moments for each category
            let categoryMoments = allCategories.map { category in
                MomentButton(
                    name: category.name,
                    category: category.name,
                    color: category.color,
                    hotkey: nil
                )
            }

            // If no categories exist, use defaults
            let moments = categoryMoments.isEmpty ? DefaultMomentCategories.all : categoryMoments

            let defaultBlueprint = Blueprint(
                id: UUID().uuidString,
                name: "Default Blueprint",
                moments: moments,
                layers: DefaultLayerTypes.all,
                createdAt: Date()
            )

            let result = DatabaseManager.shared.saveBlueprint(defaultBlueprint)
            switch result {
            case .success(let saved):
                availableBlueprints = [saved]
                print("✅ Created default blueprint with \(moments.count) categories from database")
            case .failure(let error):
                print("❌ Failed to create default blueprint: \(error)")
                availableBlueprints = [defaultBlueprint]
            }
        }

        // Select blueprint (use selected ID, or first available)
        if let selectedId = selectedBlueprintId,
           let selected = availableBlueprints.first(where: { $0.id == selectedId }) {
            currentBlueprint = selected
            savedBlueprint = selected  // Track saved version
        } else {
            currentBlueprint = availableBlueprints.first!
            selectedBlueprintId = currentBlueprint.id
            savedBlueprint = currentBlueprint  // Track saved version
        }

        print("✅ Loaded blueprint: '\(currentBlueprint.name)' with \(currentBlueprint.moments.count) moments")
    }

    private func switchBlueprint(to blueprintId: String) {
        selectedBlueprintId = blueprintId
        if let blueprint = availableBlueprints.first(where: { $0.id == blueprintId }) {
            currentBlueprint = blueprint
            savedBlueprint = blueprint  // Track saved version
            print("🔄 Switched to blueprint: \(blueprint.name)")
        }
    }

    private func createNewBlueprint() {
        // Load ALL categories from database (not just defaults)
        let allCategories = DatabaseManager.shared.getCategories()

        // Create placeholder moments for each category
        let categoryMoments = allCategories.map { category in
            MomentButton(
                name: category.name,
                category: category.name,
                color: category.color,
                hotkey: nil
            )
        }

        // If no categories exist, use defaults
        let moments = categoryMoments.isEmpty ? DefaultMomentCategories.all : categoryMoments

        let newBlueprint = Blueprint(
            id: UUID().uuidString,
            name: "New Blueprint \(availableBlueprints.count + 1)",
            moments: moments,
            layers: DefaultLayerTypes.all,
            createdAt: Date()
        )

        let result = DatabaseManager.shared.saveBlueprint(newBlueprint)
        switch result {
        case .success(let saved):
            availableBlueprints.append(saved)
            switchBlueprint(to: saved.id)
            print("✅ Created new blueprint: \(saved.name) with \(moments.count) categories from database")
        case .failure(let error):
            print("❌ Failed to create blueprint: \(error)")
        }
    }

    private func deleteCurrentBlueprint() {
        guard availableBlueprints.count > 1 else {
            print("⚠️ Cannot delete the last blueprint")
            return
        }

        let result = DatabaseManager.shared.deleteBlueprint(id: currentBlueprint.id)
        switch result {
        case .success:
            availableBlueprints.removeAll { $0.id == currentBlueprint.id }
            switchBlueprint(to: availableBlueprints.first!.id)
            print("✅ Deleted blueprint")
        case .failure(let error):
            print("❌ Failed to delete blueprint: \(error)")
        }
    }

    private func revertChanges() {
        guard let saved = savedBlueprint else {
            print("⚠️ No saved blueprint to revert to")
            return
        }
        currentBlueprint = saved
        print("↩️ Reverted to saved blueprint: \(saved.name)")
    }

    private func saveBlueprint() {
        saveBlueprintAndUpdateSelection(momentId: nil)
    }

    private func saveBlueprintAndUpdateSelection(momentId: String?) {
        saveStatus = .saving

        // Save immediately on main thread to avoid state inconsistencies
        let result = DatabaseManager.shared.saveBlueprint(currentBlueprint)
        switch result {
        case .success(let saved):
            // Update the blueprint in the list
            if let index = availableBlueprints.firstIndex(where: { $0.id == saved.id }) {
                availableBlueprints[index] = saved
            }
            currentBlueprint = saved
            savedBlueprint = saved  // Update saved version

            // Update selectedMoment to reference the new moment object from saved blueprint
            if let momentId = momentId {
                selectedMoment = saved.moments.first(where: { $0.id == momentId })
            }

            saveStatus = .success
            print("✅ Blueprint saved: \(saved.name)")

            // Reset to normal state after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                saveStatus = .none
            }

        case .failure(let error):
            saveStatus = .failure(error.localizedDescription)
            print("❌ Failed to save blueprint: \(error)")

            // Reset to normal state after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                saveStatus = .none
            }
        }
    }

    private func loadAvailableMoments() {
        guard let project = navigationState.currentProject,
              let gameId = DatabaseManager.shared.getFirstGameId(projectId: project.id) else {
            print("⚠️ BlueprintEditor: No project/game loaded")
            return
        }

        // Get categories from database
        let categories = DatabaseManager.shared.getCategories()
        availableMomentCategories = Set(categories.map { $0.name })

        // Get all moments and layers from database
        let allMoments = DatabaseManager.shared.getMoments(gameId: gameId)
        let allLayers = allMoments.flatMap { $0.layers }
        availableLayerTypes = Set(allLayers.map { $0.layerType })

        print("📊 BlueprintEditor: Found \(availableMomentCategories.count) categories from DB, \(availableLayerTypes.count) layer types")
    }

    private func createNewCategory() {
        guard !newCategoryName.isEmpty else { return }

        // Save category to database
        let result = DatabaseManager.shared.createCategory(name: newCategoryName, color: newCategoryColor)

        switch result {
        case .success(let category):
            print("✅ Created new category '\(category.name)' in database")

            // Add to available categories
            availableMomentCategories.insert(category.name)

            // Expand the new category so user can see it
            expandedCategories.insert(category.name)

        case .failure(let error):
            print("❌ Failed to create category: \(error)")
        }

        // Close the sheet and reset
        showingAddCategorySheet = false
        newCategoryName = ""
        newCategoryColor = "2979ff"
    }

    // MARK: - Drag and Drop Handling

    private func handleDrop(providers: [NSItemProvider], to destination: DropZoneType) -> Bool {
        guard !providers.isEmpty else {
            return false
        }

        // Check if dragging a moment or layer
        if let momentId = draggedMomentId {
            defer { draggedMomentId = nil }
            return handleMomentDrop(momentId: momentId, to: destination)
        } else if let layerId = draggedLayerId {
            defer { draggedLayerId = nil }
            return handleLayerDrop(layerId: layerId, to: destination)
        }

        return false
    }

    private func handleCategoryDrop(category: String, providers: [NSItemProvider]) -> Bool {
        print("🎯 [CATEGORY DROP] Drop detected on category '\(category)'")

        // Check both drag state variables (canvas uses draggingButtonId, sidebar uses draggedMomentId)
        let momentId = draggingButtonId ?? draggedMomentId
        guard let momentId = momentId else {
            print("❌ [CATEGORY DROP] No moment ID found - draggingButtonId: \(draggingButtonId?.description ?? "nil"), draggedMomentId: \(draggedMomentId?.description ?? "nil")")
            return false
        }

        print("🔍 [CATEGORY DROP] Moment ID: \(momentId)")

        // Skip placeholders - they're not real moments
        if momentId.hasPrefix("placeholder-") {
            print("⚠️ [CATEGORY DROP] Skipping placeholder moment - these are just UI indicators")
            return false
        }

        // Check if the dragged item is in the blueprint
        if let momentIndex = currentBlueprint.moments.firstIndex(where: { $0.id == momentId }) {
            let oldMoment = currentBlueprint.moments[momentIndex]

            print("📦 [CATEGORY DROP] Found moment '\(oldMoment.category)' at index \(momentIndex)")
            print("   Old state - category: '\(oldMoment.category)', x: \(oldMoment.x?.description ?? "nil"), y: \(oldMoment.y?.description ?? "nil")")

            // If dragging from canvas back to sidebar, remove canvas position
            let newX: CGFloat? = nil
            let newY: CGFloat? = nil

            // Create a new moment with the updated category (preserve name)
            let newMoment = MomentButton(
                id: oldMoment.id,
                name: oldMoment.name,  // Preserve the original name
                category: category,    // Update to new category
                color: oldMoment.color,
                hotkey: oldMoment.hotkey,
                isActive: oldMoment.isActive,
                durationType: oldMoment.durationType,
                autoDurationSeconds: oldMoment.autoDurationSeconds,
                activationTrigger: oldMoment.activationTrigger,
                deactivationTrigger: oldMoment.deactivationTrigger,
                activationLinks: oldMoment.activationLinks,
                deactivationLinks: oldMoment.deactivationLinks,
                mutualExclusiveWith: oldMoment.mutualExclusiveWith,
                leadTimeSeconds: oldMoment.leadTimeSeconds,
                lagTimeSeconds: oldMoment.lagTimeSeconds,
                x: newX,  // Remove canvas position
                y: newY   // Remove canvas position
            )

            // Update in blueprint
            currentBlueprint.moments[momentIndex] = newMoment

            print("✅ [CATEGORY DROP] Updated moment in blueprint")
            print("   New state - category: '\(newMoment.category)', x: \(newMoment.x?.description ?? "nil"), y: \(newMoment.y?.description ?? "nil")")

            // Expand the category to show the moved moment
            expandedCategories.insert(category)

            // Auto-save blueprint after category change
            saveBlueprint()

            // Clear both drag states
            draggingButtonId = nil
            draggedMomentId = nil
            currentDragOffset = .zero

            print("✅ [CATEGORY DROP] Successfully moved moment to category '\(category)' and auto-saved")

            return true
        }

        print("❌ [CATEGORY DROP] Moment ID '\(momentId)' not found in blueprint")
        return false
    }

    private func handleMomentDrop(momentId: String, to destination: DropZoneType) -> Bool {
        let draggedMoment = currentBlueprint.moments.first(where: { $0.id == momentId })
        let isInBlueprint = draggedMoment != nil

        switch destination {
        case .sidebar:
            // Only remove if coming from canvas (has x,y positions)
            // If already in sidebar (no positions), don't remove - user should drop on a category folder to change categories
            if isInBlueprint, let moment = draggedMoment {
                if moment.x != nil || moment.y != nil {
                    // Coming from canvas, remove it
                    currentBlueprint.moments.removeAll { $0.id == momentId }
                    print("🗑️ Removed moment from blueprint (was on canvas)")
                    return true
                } else {
                    // Already in sidebar, don't remove - tell user to drop on a category folder
                    print("⚠️ Moment is already in sidebar - drop on a category folder to change categories")
                    return false
                }
            }
            return false

        case .newCategory, .extendRow, .categoryRow:
            if !isInBlueprint {
                for (_, moments) in sidebarMomentsByCategory {
                    if let moment = moments.first(where: { $0.id == momentId }) {
                        let isPlaceholder = momentId.hasPrefix("placeholder-")

                        if isPlaceholder {
                            let newMoment = MomentButton(
                                id: UUID().uuidString,
                                category: moment.category,
                                color: moment.color,
                                hotkey: moment.hotkey
                            )
                            currentBlueprint.moments.append(newMoment)
                            print("✅ Added moment to blueprint")
                            return true
                        } else if !currentBlueprint.moments.contains(where: { $0.id == moment.id }) {
                            currentBlueprint.moments.append(moment)
                            print("✅ Added moment to blueprint")
                            return true
                        }
                    }
                }
            }
            return true
        }
    }

    private func handleLayerDrop(layerId: String, to destination: DropZoneType) -> Bool {
        let draggedLayer = currentBlueprint.layers.first(where: { $0.id == layerId })
        let isInBlueprint = draggedLayer != nil

        switch destination {
        case .sidebar:
            if isInBlueprint {
                currentBlueprint.layers.removeAll { $0.id == layerId }
                print("🗑️ Removed layer from blueprint")
                return true
            }
            return false

        case .newCategory, .extendRow, .categoryRow:
            if !isInBlueprint {
                if let layer = sidebarLayers.first(where: { $0.id == layerId }) {
                    let isPlaceholder = layerId.hasPrefix("placeholder-layer-")

                    if isPlaceholder {
                        let newLayer = LayerButton(
                            id: UUID().uuidString,
                            layerType: layer.layerType,
                            color: layer.color,
                            hotkey: layer.hotkey,
                            activates: layer.activates
                        )
                        currentBlueprint.layers.append(newLayer)
                        print("✅ Added layer to blueprint")
                        return true
                    } else if !currentBlueprint.layers.contains(where: { $0.id == layer.id }) {
                        currentBlueprint.layers.append(layer)
                        print("✅ Added layer to blueprint")
                        return true
                    }
                }
            }
            return true
        }
    }

    private func handleCanvasDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else {
            return false
        }

        // Check if dragging a moment or layer from sidebar
        if let momentId = draggedMomentId {
            defer { draggedMomentId = nil }

            // Check if it's from the sidebar
            for (_, moments) in sidebarMomentsByCategory {
                if let moment = moments.first(where: { $0.id == momentId }) {
                    let isPlaceholder = momentId.hasPrefix("placeholder-")

                    if isPlaceholder {
                        // Find available position for new moment
                        let preferredPosition = CGPoint(x: 500, y: 400)
                        let availablePosition = findAvailablePosition(
                            near: preferredPosition,
                            width: momentButtonWidth,
                            height: momentButtonHeight
                        )

                        var newMoment = MomentButton(
                            id: UUID().uuidString,
                            category: moment.category,
                            color: moment.color,
                            hotkey: moment.hotkey,
                            x: availablePosition.x,
                            y: availablePosition.y
                        )
                        currentBlueprint.moments.append(newMoment)
                        print("✅ Added moment to canvas at (\(availablePosition.x), \(availablePosition.y))")
                        return true
                    } else if let index = currentBlueprint.moments.firstIndex(where: { $0.id == moment.id }) {
                        // Item already in blueprint, find available position
                        let preferredPosition = CGPoint(x: 500, y: 400)
                        let availablePosition = findAvailablePosition(
                            near: preferredPosition,
                            width: momentButtonWidth,
                            height: momentButtonHeight,
                            excludeId: moment.id
                        )

                        var updatedMoment = currentBlueprint.moments[index]
                        updatedMoment.x = availablePosition.x
                        updatedMoment.y = availablePosition.y
                        currentBlueprint.moments[index] = updatedMoment
                        print("✅ Moved moment back to canvas at (\(availablePosition.x), \(availablePosition.y))")
                        return true
                    } else {
                        // New item, find available position
                        let preferredPosition = CGPoint(x: 500, y: 400)
                        let availablePosition = findAvailablePosition(
                            near: preferredPosition,
                            width: momentButtonWidth,
                            height: momentButtonHeight
                        )

                        var newMoment = moment
                        newMoment.x = availablePosition.x
                        newMoment.y = availablePosition.y
                        currentBlueprint.moments.append(newMoment)
                        print("✅ Added moment to canvas at (\(availablePosition.x), \(availablePosition.y))")
                        return true
                    }
                }
            }
        } else if let layerId = draggedLayerId {
            defer { draggedLayerId = nil }

            if let layer = sidebarLayers.first(where: { $0.id == layerId }) {
                let isPlaceholder = layerId.hasPrefix("placeholder-layer-")

                if isPlaceholder {
                    // Find available position for new layer
                    let preferredPosition = CGPoint(x: 500, y: 600)
                    let availablePosition = findAvailablePosition(
                        near: preferredPosition,
                        width: layerButtonWidth,
                        height: layerButtonHeight
                    )

                    var newLayer = LayerButton(
                        id: UUID().uuidString,
                        layerType: layer.layerType,
                        color: layer.color,
                        hotkey: layer.hotkey,
                        activates: layer.activates,
                        x: availablePosition.x,
                        y: availablePosition.y
                    )
                    currentBlueprint.layers.append(newLayer)
                    print("✅ Added layer to canvas at (\(availablePosition.x), \(availablePosition.y))")
                    return true
                } else if let index = currentBlueprint.layers.firstIndex(where: { $0.id == layer.id }) {
                    // Item already in blueprint, find available position
                    let preferredPosition = CGPoint(x: 500, y: 600)
                    let availablePosition = findAvailablePosition(
                        near: preferredPosition,
                        width: layerButtonWidth,
                        height: layerButtonHeight,
                        excludeId: layer.id
                    )

                    var updatedLayer = currentBlueprint.layers[index]
                    updatedLayer.x = availablePosition.x
                    updatedLayer.y = availablePosition.y
                    currentBlueprint.layers[index] = updatedLayer
                    print("✅ Moved layer back to canvas at (\(availablePosition.x), \(availablePosition.y))")
                    return true
                } else {
                    // New item, find available position
                    let preferredPosition = CGPoint(x: 500, y: 600)
                    let availablePosition = findAvailablePosition(
                        near: preferredPosition,
                        width: layerButtonWidth,
                        height: layerButtonHeight
                    )

                    var newLayer = layer
                    newLayer.x = availablePosition.x
                    newLayer.y = availablePosition.y
                    currentBlueprint.layers.append(newLayer)
                    print("✅ Added layer to canvas at (\(availablePosition.x), \(availablePosition.y))")
                    return true
                }
            }
        }

        return false
    }

    private func getDefaultMomentPosition(for moment: MomentButton) -> CGPoint {
        // If no position set, create a grid-based layout
        guard let index = currentBlueprint.moments.firstIndex(where: { $0.id == moment.id }) else {
            return CGPoint(x: 200, y: 200)
        }

        let column = index % 5  // 5 columns
        let row = index / 5

        let x = 150 + CGFloat(column) * 200
        let y = 150 + CGFloat(row) * 100

        return CGPoint(x: x, y: y)
    }

    private func getDefaultLayerPosition(for layer: LayerButton) -> CGPoint {
        // If no position set, create a grid-based layout below moments
        guard let index = currentBlueprint.layers.firstIndex(where: { $0.id == layer.id }) else {
            return CGPoint(x: 200, y: 600)
        }

        let column = index % 6  // 6 columns
        let row = index / 6

        let x = 150 + CGFloat(column) * 180
        let y = 700 + CGFloat(row) * 80

        return CGPoint(x: x, y: y)
    }

    private func snapToGridPosition(_ value: CGFloat) -> CGFloat {
        let gridSpacing: CGFloat = 50
        return round(value / gridSpacing) * gridSpacing
    }

    // MARK: - Collision Detection

    private let momentButtonWidth: CGFloat = 120
    private let momentButtonHeight: CGFloat = 40
    private let layerButtonWidth: CGFloat = 120
    private let layerButtonHeight: CGFloat = 40
    private let minSpacing: CGFloat = 10  // Minimum spacing between items

    /// Check if a position would overlap with any existing items on canvas
    private func isPositionOccupied(_ position: CGPoint, width: CGFloat, height: CGFloat, excludeId: String? = nil) -> Bool {
        // Check against all moments on canvas
        for moment in currentBlueprint.moments {
            guard let x = moment.x, let y = moment.y else { continue }
            if let excludeId = excludeId, moment.id == excludeId { continue }

            let rect1 = CGRect(x: position.x - minSpacing, y: position.y - minSpacing,
                             width: width + minSpacing * 2, height: height + minSpacing * 2)
            let rect2 = CGRect(x: x, y: y, width: momentButtonWidth, height: momentButtonHeight)

            if rect1.intersects(rect2) {
                return true
            }
        }

        // Check against all layers on canvas
        for layer in currentBlueprint.layers {
            guard let x = layer.x, let y = layer.y else { continue }
            if let excludeId = excludeId, layer.id == excludeId { continue }

            let rect1 = CGRect(x: position.x - minSpacing, y: position.y - minSpacing,
                             width: width + minSpacing * 2, height: height + minSpacing * 2)
            let rect2 = CGRect(x: x, y: y, width: layerButtonWidth, height: layerButtonHeight)

            if rect1.intersects(rect2) {
                return true
            }
        }

        return false
    }

    /// Find the nearest available position using a spiral search pattern
    private func findAvailablePosition(near preferredPosition: CGPoint, width: CGFloat, height: CGFloat, excludeId: String? = nil) -> CGPoint {
        // If preferred position is available, use it
        if !isPositionOccupied(preferredPosition, width: width, height: height, excludeId: excludeId) {
            return preferredPosition
        }

        // Spiral search outward from preferred position
        let step: CGFloat = 50  // Search in 50px increments
        var radius: CGFloat = step
        let maxRadius: CGFloat = 500  // Don't search too far

        while radius <= maxRadius {
            // Try positions in a circle around the preferred position
            for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                let radians = angle * .pi / 180
                let testX = preferredPosition.x + radius * cos(radians)
                let testY = preferredPosition.y + radius * sin(radians)
                let testPosition = CGPoint(x: testX, y: testY)

                // Keep positions within reasonable canvas bounds
                if testX >= 50 && testX <= 1000 && testY >= 50 && testY <= 800 {
                    if !isPositionOccupied(testPosition, width: width, height: height, excludeId: excludeId) {
                        return testPosition
                    }
                }
            }
            radius += step
        }

        // Fallback: if no position found, offset from preferred position
        return CGPoint(x: preferredPosition.x + 30, y: preferredPosition.y + 30)
    }

    private func arrangeIntoGrid() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Only arrange items that are already on the canvas (have x,y positions)
            // Don't touch items in the sidebar (x == nil && y == nil)

            // Arrange moments in a grid (3 columns)
            let momentsPerRow = 3
            let momentSpacingX: CGFloat = 130
            let momentSpacingY: CGFloat = 50
            let momentStartX: CGFloat = 100
            let momentStartY: CGFloat = 100

            var canvasMomentIndex = 0
            for index in 0..<currentBlueprint.moments.count {
                // Skip items in sidebar (no positions)
                guard currentBlueprint.moments[index].x != nil && currentBlueprint.moments[index].y != nil else {
                    continue
                }

                let row = canvasMomentIndex / momentsPerRow
                let col = canvasMomentIndex % momentsPerRow

                let x = momentStartX + CGFloat(col) * momentSpacingX
                let y = momentStartY + CGFloat(row) * momentSpacingY

                currentBlueprint.moments[index].x = x
                currentBlueprint.moments[index].y = y
                canvasMomentIndex += 1
            }

            // Arrange layers in a grid below moments (3 columns)
            let layersPerRow = 3
            let layerSpacingX: CGFloat = 130
            let layerSpacingY: CGFloat = 50
            let layerStartX: CGFloat = 100
            let layerStartY: CGFloat = 240

            var canvasLayerIndex = 0
            for index in 0..<currentBlueprint.layers.count {
                // Skip items in sidebar (no positions)
                guard currentBlueprint.layers[index].x != nil && currentBlueprint.layers[index].y != nil else {
                    continue
                }

                let row = canvasLayerIndex / layersPerRow
                let col = canvasLayerIndex % layersPerRow

                let x = layerStartX + CGFloat(col) * layerSpacingX
                let y = layerStartY + CGFloat(row) * layerSpacingY

                currentBlueprint.layers[index].x = x
                currentBlueprint.layers[index].y = y
                canvasLayerIndex += 1
            }

            print("📐 Arranged \(canvasMomentIndex) moments and \(canvasLayerIndex) layers into grid (skipped sidebar items)")
        }
    }

    private func handleZoomClick(at location: CGPoint) {
        // Zoom in on the clicked location
        withAnimation(.easeInOut(duration: 0.3)) {
            if canvasZoom < 2.0 {
                canvasZoom = min(2.0, canvasZoom + 0.3)
            }
            // Store the focus point for potential future use
            zoomFocusPoint = location
        }
        print("🔍 Zoomed to \(Int(canvasZoom * 100))% at location (\(Int(location.x)), \(Int(location.y)))")
    }

    // MARK: - Blueprint Header Controls

    private var blueprintHeaderControls: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if editingBlueprintName {
                        TextField("Blueprint name", text: $blueprintNameText, onCommit: {
                            if !blueprintNameText.trimmingCharacters(in: .whitespaces).isEmpty {
                                currentBlueprint.name = blueprintNameText
                                saveBlueprint()
                            }
                            editingBlueprintName = false
                        })
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.primaryText)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: 300)

                        Button(action: {
                            if !blueprintNameText.trimmingCharacters(in: .whitespaces).isEmpty {
                                currentBlueprint.name = blueprintNameText
                                saveBlueprint()
                            }
                            editingBlueprintName = false
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10))
                                .foregroundColor(theme.success)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            blueprintNameText = currentBlueprint.name
                            editingBlueprintName = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(theme.error)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Text(currentBlueprint.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        Button(action: {
                            blueprintNameText = currentBlueprint.name
                            editingBlueprintName = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.primaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Text("Design moment categories, colors, and keyboard mappings")
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
            }

            Spacer()

            HStack(spacing: 12) {
                // Blueprint Selector
                Menu {
                    ForEach(availableBlueprints, id: \.id) { blueprint in
                        Button(action: {
                            switchBlueprint(to: blueprint.id)
                        }) {
                            HStack {
                                Text(blueprint.name)
                                Spacer()
                                if blueprint.id == selectedBlueprintId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button(action: {
                        createNewBlueprint()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create New Blueprint")
                        }
                    }

                    if availableBlueprints.count > 1 {
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete '\(currentBlueprint.name)'")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Blueprint:")
                            .font(.system(size: 10))
                            .foregroundColor(theme.tertiaryText)

                        Text(currentBlueprint.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.primaryText)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(theme.tertiaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                if hasUnsavedChanges {
                    Text("Unsaved changes")
                        .font(.system(size: 10))
                        .foregroundColor(theme.warning)
                }

                if hasUnsavedChanges {
                    Button(action: {
                        revertChanges()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("Revert")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.primaryBorder)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: {
                    saveBlueprint()
                }) {
                    HStack(spacing: 4) {
                        if case .saving = saveStatus {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        } else if case .success = saveStatus {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10))
                        }

                        Text(saveButtonText)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(saveButtonColor)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(saveStatus == .saving)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(theme.primaryBackground)
    }

    // MARK: - Left Sidebar

    private var leftSidebar: some View {
        let isHovered = hoveredDropZone == .sidebar

        return VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("MOMENT CATEGORIES")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
                    .tracking(0.5)

                Text("Structure your moment schema")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                HStack(spacing: 8) {
                    Button(action: {
                        createNewBlueprint()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.rectangle")
                                .font(.system(size: 10))
                            Text("New Blueprint")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(theme.success)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        // Create a placeholder moment for new moment creation
                        editingMoment = MomentButton(
                            id: "new-moment-placeholder",
                            category: "",
                            color: "2979ff",
                            hotkey: nil
                        )
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text("New Moment")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(theme.accent)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider()
                .background(theme.primaryBorder)

            // Categories List
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MOMENTS
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(sidebarMomentsByCategory.keys.sorted()), id: \.self) { category in
                            categoryGroup(category: category)
                        }
                    }

                    Divider()
                        .background(theme.primaryBorder)
                        .padding(.vertical, 8)

                    // LAYERS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LAYERS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)
                            .tracking(0.5)

                        ForEach(sidebarLayers) { layer in
                            layerRow(layer: layer)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Spacer()

            // Footer
            VStack(spacing: 12) {
                Divider()
                    .background(theme.primaryBorder)

                Text("Drag moments to the canvas to include in blueprint.")
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
                    .padding(.horizontal, 16)

                Button(action: {
                    showingAddCategorySheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                        Text("Add Category")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(theme.primaryBorder)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(isHovered ? theme.error.opacity(0.2) : theme.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            isHovered
                ? RoundedRectangle(cornerRadius: 0)
                    .stroke(theme.error, lineWidth: 2)
                : nil
        )
        .onDrop(of: [.text], isTargeted: nil) { providers in
            print("⬇️ [SIDEBAR DROP] Drop on entire sidebar - providers: \(providers.count)")
            print("   Drag states - draggingButtonId: \(draggingButtonId?.description ?? "nil"), draggedMomentId: \(draggedMomentId?.description ?? "nil")")
            hoveredDropZone = nil
            return handleDrop(providers: providers, to: .sidebar)
        }
        .onHover { hovering in
            // Check all three drag states (canvas and sidebar)
            if hovering && (draggedMomentId != nil || draggedLayerId != nil || draggingButtonId != nil) {
                hoveredDropZone = .sidebar
                print("👉 [SIDEBAR HOVER] Hovering over sidebar - draggingButtonId: \(draggingButtonId?.description ?? "nil")")
            } else if !hovering && hoveredDropZone == .sidebar {
                hoveredDropZone = nil
                print("👈 [SIDEBAR HOVER] Left sidebar")
            }
        }
    }

    private func categoryGroup(category: String) -> some View {
        let moments = sidebarMomentsByCategory[category] ?? []
        let isExpanded = expandedCategories.contains(category)
        let categoryColor = moments.first?.color ?? "666666"
        let isHovered = hoveredDropCategory == category

        return VStack(alignment: .leading, spacing: 8) {
            // Category Header
            Button(action: {
                if isExpanded {
                    expandedCategories.remove(category)
                } else {
                    expandedCategories.insert(category)
                }
            }) {
                HStack {
                    Circle()
                        .fill(Color(hex: categoryColor))
                        .frame(width: 8, height: 8)

                    Text(category)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isHovered ? .white : theme.primaryText)

                    Text("\(moments.count) moments")
                        .font(.system(size: 11))
                        .foregroundColor(isHovered ? .white.opacity(0.8) : theme.tertiaryText)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(isHovered ? .white : theme.tertiaryText)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(isHovered ? theme.accent : Color.clear)
                .cornerRadius(6)
                .overlay(
                    isHovered ?
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.accent, lineWidth: 2)
                        : nil
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onDrop(of: [.text], isTargeted: nil) { providers in
                print("⬇️ [DROP TRIGGERED] Drop event on category '\(category)' with \(providers.count) providers")
                hoveredDropCategory = nil
                return handleCategoryDrop(category: category, providers: providers)
            }
            .onHover { hovering in
                // Check both drag states (canvas and sidebar)
                if hovering && (draggingButtonId != nil || draggedMomentId != nil) {
                    hoveredDropCategory = category
                    print("👉 [HOVER] Hovering over category '\(category)' - draggingButtonId: \(draggingButtonId?.description ?? "nil"), draggedMomentId: \(draggedMomentId?.description ?? "nil")")
                } else if !hovering && hoveredDropCategory == category {
                    hoveredDropCategory = nil
                    print("👈 [HOVER] Left category '\(category)'")
                }
            }

            // Moments in Category
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(moments) { moment in
                        momentRow(moment: moment)
                    }
                }
                .padding(.leading, 20)
            }
        }
    }

    private func momentRow(moment: MomentButton) -> some View {
        let isPlaceholder = moment.id.hasPrefix("placeholder-")

        return HStack {
            Circle()
                .fill(Color(hex: moment.color))
                .frame(width: 6, height: 6)

            Text(moment.name)
                .font(.system(size: 12, weight: moment.isActive ? .bold : .regular))
                .foregroundColor(isPlaceholder ? theme.tertiaryText : theme.primaryText)

            Spacer()

            if let hotkey = moment.hotkey {
                Text(hotkey)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
                    .frame(minWidth: 20)
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceBackground)
        .cornerRadius(4)
        .opacity(draggedMomentId == moment.id ? 0.5 : 1.0)
        .onTapGesture {
            selectedMoment = moment
        }
        .onDrag {
            // Don't allow dragging active moments (but placeholders are OK)
            guard !moment.isActive || isPlaceholder else {
                print("⚠️ [DRAG BLOCKED] Cannot drag active moment '\(moment.category)' - isActive: true, x: \(moment.x?.description ?? "nil"), y: \(moment.y?.description ?? "nil")")
                return NSItemProvider()
            }

            draggedMomentId = moment.id
            print("🎯 [SIDEBAR DRAG] Started dragging '\(moment.category)' from sidebar - isPlaceholder: \(isPlaceholder), isActive: \(moment.isActive), x: \(moment.x?.description ?? "nil"), y: \(moment.y?.description ?? "nil")")
            return NSItemProvider(object: moment.id as NSString)
        }
    }

    private func layerRow(layer: LayerButton) -> some View {
        let isPlaceholder = layer.id.hasPrefix("placeholder-layer-")

        return HStack {
            Circle()
                .fill(Color(hex: layer.color))
                .frame(width: 6, height: 6)

            Text(layer.layerType)
                .font(.system(size: 12))
                .foregroundColor(isPlaceholder ? theme.tertiaryText : theme.primaryText)

            Spacer()

            if let hotkey = layer.hotkey {
                Text(hotkey)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
                    .frame(minWidth: 20)
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundColor(theme.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceBackground)
        .cornerRadius(20)  // Rounded for layers
        .opacity(draggedLayerId == layer.id ? 0.5 : 1.0)
        .onTapGesture {
            selectedLayer = layer
            selectedMoment = nil
        }
        .onDrag {
            draggedLayerId = layer.id
            print("🎯 [SIDEBAR DRAG] Started dragging layer '\(layer.layerType)' from sidebar - isPlaceholder: \(isPlaceholder)")
            return NSItemProvider(object: layer.id as NSString)
        }
    }

    // MARK: - Center Canvas

    private var centerCanvas: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 16) {
                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blueprint Canvas")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.primaryText)

                    Text("Drag moments to define layout")
                        .font(.system(size: 9))
                        .foregroundColor(theme.tertiaryText)
                }

                Spacer()

                // Alignment and zoom controls
                HStack(spacing: 6) {
                    // Zoom controls
                    HStack(spacing: 3) {
                        Button(action: {
                            canvasZoom = max(0.5, canvasZoom - 0.1)
                        }) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(canvasZoom <= 0.5)

                        Text("\(Int(canvasZoom * 100))%")
                            .font(.system(size: 9))
                            .foregroundColor(theme.tertiaryText)
                            .frame(width: 35)

                        Button(action: {
                            canvasZoom = min(2.0, canvasZoom + 0.1)
                        }) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(canvasZoom >= 2.0)

                        Button(action: {
                            canvasZoom = 1.0
                        }) {
                            Text("Reset")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .frame(height: 14)
                            .background(theme.primaryBorder)

                        // Zoom tool toggle
                        Button(action: {
                            isZoomToolActive.toggle()
                        }) {
                            Image(systemName: isZoomToolActive ? "scope.fill" : "scope")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .foregroundColor(isZoomToolActive ? theme.accent : theme.primaryText)
                    }
                    .foregroundColor(theme.primaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(theme.surfaceBackground)
                    .cornerRadius(6)

                    Toggle(isOn: $snapToGrid) {
                        HStack(spacing: 4) {
                            Image(systemName: "grid")
                                .font(.system(size: 10))
                            Text("Snap to grid")
                                .font(.system(size: 10))
                        }
                    }
                    .toggleStyle(.button)
                    .foregroundColor(theme.primaryText)
                    .onChange(of: snapToGrid) { _, newValue in
                        if newValue {
                            arrangeIntoGrid()
                        }
                    }

                    Toggle(isOn: $showCategoriesOutline) {
                        Text("Show categories outline")
                            .font(.system(size: 10))
                    }
                    .toggleStyle(.button)
                    .foregroundColor(theme.primaryText)

                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "eye")
                                .font(.system(size: 10))
                            Text("Preview layout")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(theme.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.primaryBorder)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.secondaryBackground)

            // Canvas Area - Free-form positioning
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // Canvas background with grid
                    Rectangle()
                        .fill(theme.primaryBackground)
                        .frame(width: 2000, height: 1500)

                    // Grid overlay (optional, for visual reference)
                    if snapToGrid {
                        Path { path in
                            let spacing: CGFloat = 50
                            // Vertical lines
                            for x in stride(from: 0, to: 2000, by: spacing) {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: 1500))
                            }
                            // Horizontal lines
                            for y in stride(from: 0, to: 1500, by: spacing) {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: 2000, y: y))
                            }
                        }
                        .stroke(theme.surfaceBackground, lineWidth: 1)
                    }

                    // Render moment buttons at their positions (only those with x,y set)
                    ForEach(currentBlueprint.moments.filter { $0.x != nil && $0.y != nil }) { moment in
                        canvasMomentButton(moment: moment)
                            .position(
                                x: moment.x!,
                                y: moment.y!
                            )
                    }

                    // Render layer buttons at their positions (only those with x,y set)
                    ForEach(currentBlueprint.layers.filter { $0.x != nil && $0.y != nil }) { layer in
                        canvasLayerButton(layer: layer)
                            .position(
                                x: layer.x!,
                                y: layer.y!
                            )
                    }

                    // Drop zone indicator when canvas is empty (no positioned items)
                    if currentBlueprint.moments.filter({ $0.x != nil && $0.y != nil }).isEmpty &&
                       currentBlueprint.layers.filter({ $0.x != nil && $0.y != nil }).isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 48))
                                .foregroundColor(theme.primaryBorder)

                            Text("Drag moments and layers here")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.tertiaryText)

                            Text("They can be freely positioned anywhere on the canvas")
                                .font(.system(size: 12))
                                .foregroundColor(theme.tertiaryText)
                        }
                        .position(x: 1000, y: 300)
                    }
                }
                .frame(width: 2000, height: 1500, alignment: .topLeading)
                .coordinateSpace(name: "canvas")
                .scaleEffect(canvasZoom, anchor: .topLeading)
                .frame(minWidth: 2000 * canvasZoom, minHeight: 1500 * canvasZoom, alignment: .topLeading)
                .contentShape(Rectangle())  // Make entire canvas tappable
                .onTapGesture { location in
                    if isZoomToolActive {
                        handleZoomClick(at: location)
                    }
                }
                .onDrop(of: [.text], isTargeted: nil) { providers in
                    return handleCanvasDrop(providers: providers)
                }
            }
            .background(theme.primaryBackground)
            .overlay(
                // Zoom tool cursor indicator
                isZoomToolActive ?
                    Text("Click to zoom in")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.accent)
                        .cornerRadius(4)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                : nil
            )
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    private func canvasCategoryRow(category: String) -> some View {
        let moments = canvasMomentsByCategory[category] ?? []

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(Color(hex: moments.first?.color ?? "666666"))

                Text("\(category) moments")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Text("Row · \(moments.count) moments")
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
            }

            HStack(spacing: 12) {
                ForEach(moments) { moment in
                    canvasMomentButton(moment: moment)
                }
            }
        }
        .padding(16)
        .background(
            showCategoriesOutline
                ? Color(hex: canvasMomentsByCategory[category]?.first?.color ?? "666666").opacity(0.1)
                : Color.clear
        )
        .cornerRadius(8)
        .overlay(
            showCategoriesOutline
                ? RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: canvasMomentsByCategory[category]?.first?.color ?? "666666").opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                : nil
        )
    }

    private func canvasMomentButton(moment: MomentButton) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11))
                .foregroundColor(theme.primaryText)

            Text(moment.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.primaryText)

            if let hotkey = moment.hotkey {
                Text(hotkey)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: moment.color))
        .cornerRadius(6)
        .overlay(
            selectedMoment?.id == moment.id ?
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white, lineWidth: 2)
                : nil
        )
        .opacity(draggingButtonId == moment.id ? 0.3 : 1.0)
        .onTapGesture(count: 2) {
            // Double-click to edit
            editingMoment = moment
        }
        .onTapGesture {
            selectedMoment = moment
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if draggingButtonId != moment.id {
                        draggingButtonId = moment.id
                        globalCursorPosition = value.startLocation
                        let isPlaceholder = moment.id.hasPrefix("placeholder-")
                        print("🎯 [DRAG START] Moment '\(moment.category)' (id: \(moment.id)) - isPlaceholder: \(isPlaceholder), position: (\(moment.x?.description ?? "nil"), \(moment.y?.description ?? "nil"))")
                    }
                    currentDragOffset = value.translation
                }
                .onEnded { value in
                    let endLocation = value.location
                    print("🏁 [DRAG END] Moment '\(moment.category)' - end location: \(endLocation), translation: \(value.translation)")

                    // Check if drag ended in the sidebar area (left side, roughly x < 350)
                    let droppedInSidebar = endLocation.x < 350
                    print("🔍 [DRAG END] Dropped in sidebar area: \(droppedInSidebar) (x: \(endLocation.x))")

                    if droppedInSidebar {
                        // Manually trigger category drop - clear positions and deactivate
                        if let index = currentBlueprint.moments.firstIndex(where: { $0.id == moment.id }) {
                            let beforeState = currentBlueprint.moments[index]
                            print("📊 [BEFORE DROP] '\(beforeState.category)' - x: \(beforeState.x?.description ?? "nil"), y: \(beforeState.y?.description ?? "nil"), isActive: \(beforeState.isActive)")

                            var updatedMoment = currentBlueprint.moments[index]
                            updatedMoment.x = nil
                            updatedMoment.y = nil
                            updatedMoment.isActive = false  // Deactivate when moved to sidebar
                            currentBlueprint.moments[index] = updatedMoment

                            print("📊 [AFTER DROP] '\(updatedMoment.category)' - x: \(updatedMoment.x?.description ?? "nil"), y: \(updatedMoment.y?.description ?? "nil"), isActive: \(updatedMoment.isActive)")

                            // Clear selection so item can be dragged again
                            if selectedMoment?.id == moment.id {
                                selectedMoment = nil
                                print("🔓 [DESELECT] Cleared selectedMoment")
                            }

                            print("✅ [MANUAL DROP] Cleared positions, deactivated, and deselected '\(moment.category)' - moved to sidebar")
                        }
                    } else {
                        // Normal canvas repositioning
                        if let index = currentBlueprint.moments.firstIndex(where: { $0.id == moment.id }) {
                            let newX = (moment.x ?? getDefaultMomentPosition(for: moment).x) + value.translation.width / canvasZoom
                            let newY = (moment.y ?? getDefaultMomentPosition(for: moment).y) + value.translation.height / canvasZoom

                            var updatedMoment = currentBlueprint.moments[index]
                            updatedMoment.x = max(50, min(1950, newX))
                            updatedMoment.y = max(50, min(1450, newY))

                            currentBlueprint.moments[index] = updatedMoment
                            print("📍 [CANVAS UPDATE] Moment '\(moment.category)' position updated to (\(updatedMoment.x!), \(updatedMoment.y!))")
                        }
                    }

                    draggingButtonId = nil
                    currentDragOffset = .zero
                    globalCursorPosition = .zero
                    print("🧹 [CLEANUP] Cleared drag state")
                }
        )
    }

    private var dropZone: some View {
        let isHovered = hoveredDropZone == .extendRow

        return VStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 24))
                .foregroundColor(isHovered ? theme.accent : theme.tertiaryText)

            Text("Drop moments here to add to blueprint")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isHovered ? .white : theme.tertiaryText)

            Text("Drag from sidebar to add new moments")
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(isHovered ? theme.accent.opacity(0.2) : theme.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? theme.accent : theme.primaryBorder, style: StrokeStyle(lineWidth: isHovered ? 3 : 1, dash: [8]))
        )
        .onDrop(of: [.text], isTargeted: nil) { providers in
            hoveredDropZone = nil
            return handleDrop(providers: providers, to: .extendRow)
        }
        .onHover { hovering in
            if hovering && (draggedMomentId != nil || draggedLayerId != nil) {
                hoveredDropZone = .extendRow
            } else if !hovering && hoveredDropZone == .extendRow {
                hoveredDropZone = nil
            }
        }
    }

    private func canvasLayerButton(layer: LayerButton) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.primaryText)
                .frame(width: 8, height: 8)

            Text(layer.layerType)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.primaryText)

            if let hotkey = layer.hotkey {
                Text(hotkey)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: layer.color))
        .cornerRadius(20)
        .overlay(
            selectedLayer?.id == layer.id ?
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 2)
                : nil
        )
        .opacity(draggingButtonId == layer.id ? 0.3 : 1.0)
        .onTapGesture(count: 2) {
            // Double-click to edit
            editingLayer = layer
        }
        .onTapGesture {
            selectedLayer = layer
            selectedMoment = nil
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if draggingButtonId != layer.id {
                        draggingButtonId = layer.id
                        globalCursorPosition = value.startLocation
                        print("🎯 [DRAG START] Layer '\(layer.layerType)' (id: \(layer.id)) - start at \(value.startLocation)")
                    }
                    currentDragOffset = value.translation
                }
                .onEnded { value in
                    let endLocation = value.location
                    print("🏁 [DRAG END] Layer '\(layer.layerType)' - end location: \(endLocation), translation: \(value.translation)")

                    // Check if drag ended in the sidebar area (left side, roughly x < 350)
                    let droppedInSidebar = endLocation.x < 350
                    print("🔍 [DRAG END] Dropped in sidebar area: \(droppedInSidebar) (x: \(endLocation.x))")

                    if droppedInSidebar {
                        // Manually trigger sidebar drop - clear positions
                        if let index = currentBlueprint.layers.firstIndex(where: { $0.id == layer.id }) {
                            var updatedLayer = currentBlueprint.layers[index]
                            updatedLayer.x = nil
                            updatedLayer.y = nil
                            currentBlueprint.layers[index] = updatedLayer

                            // Clear selection so item can be dragged again
                            if selectedLayer?.id == layer.id {
                                selectedLayer = nil
                            }

                            print("✅ [MANUAL DROP] Cleared positions and deselected '\(layer.layerType)' - moved to sidebar")
                        }
                    } else {
                        // Normal canvas repositioning
                        if let index = currentBlueprint.layers.firstIndex(where: { $0.id == layer.id }) {
                            let newX = (layer.x ?? getDefaultLayerPosition(for: layer).x) + value.translation.width / canvasZoom
                            let newY = (layer.y ?? getDefaultLayerPosition(for: layer).y) + value.translation.height / canvasZoom

                            var updatedLayer = currentBlueprint.layers[index]
                            updatedLayer.x = max(50, min(1950, newX))
                            updatedLayer.y = max(50, min(1450, newY))

                            currentBlueprint.layers[index] = updatedLayer
                            print("📍 [CANVAS UPDATE] Layer '\(layer.layerType)' position updated to (\(updatedLayer.x!), \(updatedLayer.y!))")
                        }
                    }

                    draggingButtonId = nil
                    currentDragOffset = .zero
                    globalCursorPosition = .zero
                    print("🧹 [CLEANUP] Cleared drag state")
                }
        )
    }

    private var layerDropZone: some View {
        let isHovered = hoveredDropZone == .extendRow && draggedLayerId != nil

        return VStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 24))
                .foregroundColor(isHovered ? theme.accent : theme.tertiaryText)

            Text("Drop layers here to add to blueprint")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isHovered ? .white : theme.tertiaryText)

            HStack(spacing: 4) {
                Text("Drag from sidebar or")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Button(action: {
                    // Create a placeholder layer for new layer creation
                    editingLayer = LayerButton(
                        id: "new-layer-placeholder",
                        layerType: "",
                        color: "2979ff",
                        hotkey: nil,
                        activates: nil
                    )
                }) {
                    Text("create new layer")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(isHovered ? theme.accent.opacity(0.2) : theme.secondaryBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? theme.accent : theme.primaryBorder, style: StrokeStyle(lineWidth: isHovered ? 3 : 1, dash: [8]))
        )
        .onDrop(of: [.text], isTargeted: nil) { providers in
            hoveredDropZone = nil
            return handleDrop(providers: providers, to: .extendRow)
        }
        .onHover { hovering in
            if hovering && draggedLayerId != nil {
                hoveredDropZone = .extendRow
            } else if !hovering && hoveredDropZone == .extendRow && draggedLayerId != nil {
                hoveredDropZone = nil
            }
        }
    }

    // MARK: - Drag Preview Overlay

    @ViewBuilder
    private func dragPreviewOverlay(draggedId: String) -> some View {
        GeometryReader { geometry in
            Group {
                // Check if it's a moment or layer being dragged
                if let moment = currentBlueprint.moments.first(where: { $0.id == draggedId }) {
                    // Moment drag preview
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        Text(moment.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        if let hotkey = moment.hotkey {
                            Text(hotkey)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: moment.color))
                    .cornerRadius(6)
                    .opacity(0.9)
                    .shadow(color: Color.black.opacity(0.5), radius: 12)
                } else if let layer = currentBlueprint.layers.first(where: { $0.id == draggedId }) {
                    // Layer drag preview
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.white)
                            .frame(width: 6, height: 6)
                        Text(layer.layerType)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        if let hotkey = layer.hotkey {
                            Text(hotkey)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: layer.color))
                    .cornerRadius(20)
                    .opacity(0.9)
                    .shadow(color: Color.black.opacity(0.5), radius: 12)
                }
            }
            .position(
                x: globalCursorPosition.x + currentDragOffset.width,
                y: globalCursorPosition.y + currentDragOffset.height
            )
            .allowsHitTesting(false)  // Don't intercept clicks
        }
        .allowsHitTesting(false)
        .zIndex(9999)  // Ensure it's always on top
    }

    // MARK: - Right Sidebar

    private var rightSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Keyboard Mapping
                keyboardMapping

                Divider()
                    .background(theme.primaryBorder)

                // Tag Settings (if moment selected)
                if let moment = selectedMoment {
                    momentSettings(moment: moment)
                }

                Divider()
                    .background(theme.primaryBorder)

                // Blueprint Actions
                blueprintActions
            }
            .padding(16)
        }
        .background(theme.secondaryBackground)
        .cornerRadius(8)
    }

    private var keyboardMapping: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Keyboard Mapping")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                if let moment = selectedMoment, let hotkey = moment.hotkey {
                    Text("Click a key to assign to \"\(moment.category)\"")
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                }
            }

            // Keyboard layout
            VStack(spacing: 4) {
                // Number row
                keyboardRow(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])

                // QWERTY row
                HStack(spacing: 4) {
                    Spacer().frame(width: 20)
                    keyboardRow(keys: ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"])
                }

                // ASDF row
                HStack(spacing: 4) {
                    Spacer().frame(width: 40)
                    keyboardRow(keys: ["A", "S", "D", "F", "G", "H", "J", "K", "L"])
                }

                // ZXCV row
                HStack(spacing: 4) {
                    Spacer().frame(width: 60)
                    keyboardRow(keys: ["Z", "X", "C", "V", "B", "N", "M"])
                }
            }

            Text("Hold Option to assign secondary shortcuts. Q mapped to 1 moment")
                .font(.system(size: 10))
                .foregroundColor(theme.tertiaryText)
        }
    }

    private func keyboardRow(keys: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                keyboardKey(key: key)
            }
        }
    }

    private func keyboardKey(key: String) -> some View {
        let assignedMoment = currentBlueprint.moments.first { $0.hotkey == key }
        let isSelected = selectedMoment?.hotkey == key

        return Text(key)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isSelected ? .white : theme.tertiaryText)
            .frame(width: 28, height: 28)
            .background(
                isSelected
                    ? theme.accent
                    : (assignedMoment != nil ? theme.primaryBorder : theme.surfaceBackground)
            )
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? theme.accent : theme.primaryBorder, lineWidth: 1)
            )
    }

    private func momentSettings(moment: MomentButton) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Moment Details")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Text("Selected: \(moment.category)")
                    .font(.system(size: 10))
                    .foregroundColor(theme.tertiaryText)
            }

            // Moment name (read-only)
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                Text(moment.name)
                    .font(.system(size: 12))
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.surfaceBackground)
                    .cornerRadius(6)
            }

            // Color (read-only display)
            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.system(size: 11))
                    .foregroundColor(theme.tertiaryText)

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: moment.color))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )

                    Text("#\(moment.color)")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                }
            }

            // Hotkey (read-only)
            if let hotkey = moment.hotkey {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Keyboard Shortcut")
                        .font(.system(size: 11))
                        .foregroundColor(theme.tertiaryText)

                    Text(hotkey)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.surfaceBackground)
                        .cornerRadius(6)
                }
            }

            Divider()
                .background(theme.primaryBorder)

            Text("Click 'Edit Moment' to make changes")
                .font(.system(size: 11))
                .foregroundColor(theme.tertiaryText)
                .italic()

            // Edit and Delete buttons
            HStack(spacing: 12) {
                Button(action: {
                    editingMoment = moment
                }) {
                    HStack {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text("Edit Moment")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    // Delete moment
                    currentBlueprint.moments.removeAll { $0.id == moment.id }
                    selectedMoment = nil
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Delete")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(theme.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.error)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func iconButton(icon: String, label: String, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .white : theme.tertiaryText)
                .frame(width: 32, height: 32)
                .background(isSelected ? theme.accent : theme.surfaceBackground)
                .cornerRadius(6)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(theme.tertiaryText)
        }
    }

    private var blueprintActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Blueprint Actions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: {}) {
                    Text("Manage presets")
                        .font(.system(size: 11))
                        .foregroundColor(theme.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }

            HStack(spacing: 8) {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 10))
                        Text("Import")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(theme.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10))
                        Text("Export")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(theme.accent)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Button(action: {}) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                    Text("Reset")
                        .font(.system(size: 12))
                }
                .foregroundColor(theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(theme.primaryBorder)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Moment Configuration Modal

struct MomentConfigModal: View {
    @EnvironmentObject var themeManager: ThemeManager
    let moment: MomentButton
    let existingMoments: [MomentButton]
    let onSave: (MomentButton) -> Void
    let isNewMoment: Bool

    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var color: Color = Color(hex: "2979ff")
    @State private var hotkey: String = ""
    @State private var category: String = "Offense"
    @State private var durationType: MomentDurationType = .auto
    @State private var autoDurationSeconds: Int = 5
    @State private var activationTrigger: MomentEventTrigger = .manual
    @State private var deactivationTrigger: MomentEventTrigger = .manual
    @State private var activationLinks: Set<String> = []
    @State private var deactivationLinks: Set<String> = []
    @State private var mutualExclusiveWith: Set<String> = []
    @State private var leadTimeSeconds: Int = 0
    @State private var lagTimeSeconds: Int = 0
    @State private var errorMessage: String?

    // Available categories from existing moments
    private var availableCategories: [String] {
        let categories = Set(existingMoments.map { $0.category }).filter { !$0.isEmpty }
        return Array(categories).sorted()
    }

    init(moment: MomentButton, existingMoments: [MomentButton], onSave: @escaping (MomentButton) -> Void, isNewMoment: Bool = false) {
        self.moment = moment
        self.existingMoments = existingMoments
        self.onSave = onSave
        self.isNewMoment = isNewMoment

        // Initialize state from moment
        _name = State(initialValue: moment.name)
        _color = State(initialValue: Color(hex: moment.color))
        _hotkey = State(initialValue: moment.hotkey ?? "")
        _category = State(initialValue: moment.category)
        _durationType = State(initialValue: moment.durationType ?? .auto)
        _autoDurationSeconds = State(initialValue: moment.autoDurationSeconds ?? 5)
        _activationTrigger = State(initialValue: moment.activationTrigger ?? .manual)
        _deactivationTrigger = State(initialValue: moment.deactivationTrigger ?? .manual)
        _activationLinks = State(initialValue: Set(moment.activationLinks ?? []))
        _deactivationLinks = State(initialValue: Set(moment.deactivationLinks ?? []))
        _mutualExclusiveWith = State(initialValue: Set(moment.mutualExclusiveWith ?? []))
        _leadTimeSeconds = State(initialValue: moment.leadTimeSeconds ?? 0)
        _lagTimeSeconds = State(initialValue: moment.lagTimeSeconds ?? 0)
    }

    var theme: ThemeColors {
        themeManager.colors
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNewMoment ? "New Moment" : "Edit Moment")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.primaryText)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)
            .background(theme.surfaceBackground)

            Divider()
                .background(theme.primaryBorder)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        TextField("Moment name", text: $name)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText)
                            .padding(12)
                            .background(theme.surfaceBackground)
                            .cornerRadius(6)
                            .textFieldStyle(.plain)
                            .onChange(of: name) { _ in
                                // Clear error when user starts typing
                                errorMessage = nil
                            }

                        // Error message for duplicate names
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 11))
                                .foregroundColor(Color.red)
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                        }
                    }

                    // Category
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        if !availableCategories.isEmpty {
                            Picker("", selection: $category) {
                                Text("Select category...").tag("")
                                ForEach(availableCategories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText)
                            .padding(8)
                            .background(theme.surfaceBackground)
                            .cornerRadius(6)
                        } else {
                            TextField("Category (e.g., Offense, Defense)", text: $category)
                                .font(.system(size: 13))
                                .foregroundColor(theme.primaryText)
                                .padding(12)
                                .background(theme.surfaceBackground)
                                .cornerRadius(6)
                                .textFieldStyle(.plain)
                        }
                    }

                    // Color
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        ColorPicker("", selection: $color, supportsOpacity: false)
                            .labelsHidden()
                    }

                    // Hotkey
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hotkey (optional)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        TextField("Press a key", text: $hotkey)
                            .font(.system(size: 13))
                            .foregroundColor(theme.primaryText)
                            .padding(12)
                            .background(theme.surfaceBackground)
                            .cornerRadius(6)
                            .textFieldStyle(.plain)
                    }

                    // Duration Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duration Type")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.tertiaryText)

                        Picker("", selection: $durationType) {
                            Text("Auto Duration").tag(MomentDurationType.auto)
                            Text("Event-Based").tag(MomentDurationType.eventBased)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Auto Duration
                    if durationType == .auto {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration (seconds)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.tertiaryText)

                            Stepper("\(autoDurationSeconds)s", value: $autoDurationSeconds, in: 1...60)
                                .font(.system(size: 13))
                                .foregroundColor(theme.primaryText)
                        }
                    }

                    // Event-Based Configuration
                    if durationType == .eventBased {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Event-Based Triggers")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.primaryText)

                            // Activation Trigger
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Activate when:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)

                                eventTriggerPicker(trigger: $activationTrigger, label: "Activation")
                            }

                            // Deactivation Trigger
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Deactivate when:")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)

                                eventTriggerPicker(trigger: $deactivationTrigger, label: "Deactivation")
                            }
                        }
                    }

                    Divider()
                        .background(theme.primaryBorder)

                    // Lead/Lag Time Configuration
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Clip Timing Offsets")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lead Time (seconds)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "9a9a9a"))

                            HStack {
                                Text("Start clip")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "666666"))
                                Text("\(leadTimeSeconds)s")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("before moment activation")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "666666"))
                            }

                            Stepper("", value: $leadTimeSeconds, in: 0...30)
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lag Time (seconds)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "9a9a9a"))

                            HStack {
                                Text("End clip")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "666666"))
                                Text("\(lagTimeSeconds)s")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("after moment deactivation")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "666666"))
                            }

                            Stepper("", value: $lagTimeSeconds, in: 0...30)
                                .labelsHidden()
                        }
                    }

                    Divider()
                        .background(Color(hex: "333333"))

                    // Advanced Links
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Advanced Behavior")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.primaryText)

                        // Activation Links
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Auto-activate moments")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)

                                Spacer()

                                Text("When this moment starts")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.tertiaryText)
                            }

                            momentMultiSelector(
                                selectedIds: $activationLinks,
                                placeholder: "Select moments to auto-activate..."
                            )
                        }

                        // Deactivation Links
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Auto-deactivate moments")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)

                                Spacer()

                                Text("When this moment starts")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.tertiaryText)
                            }

                            momentMultiSelector(
                                selectedIds: $deactivationLinks,
                                placeholder: "Select moments to auto-deactivate..."
                            )
                        }

                        // Mutual Exclusive
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Mutually exclusive with")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.tertiaryText)

                                Spacer()

                                Text("Can't be active together")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.tertiaryText)
                            }

                            momentMultiSelector(
                                selectedIds: $mutualExclusiveWith,
                                placeholder: "Select moments..."
                            )
                        }
                    }
                }
                .padding(20)
            }

            Divider()
                .background(theme.primaryBorder)

            // Footer
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .font(.system(size: 13))
                        .foregroundColor(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.primaryBorder)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    // Check for duplicate names
                    let isDuplicate = existingMoments.contains { existingMoment in
                        existingMoment.id != moment.id && existingMoment.name == name
                    }

                    if isDuplicate {
                        errorMessage = "A moment with the name '\(name)' already exists"
                        print("❌ Cannot save moment: \(errorMessage!)")
                        return
                    }

                    errorMessage = nil

                    let savedMoment = MomentButton(
                        id: isNewMoment ? UUID().uuidString : moment.id,
                        name: name,      // Use the name field
                        category: category,  // Use the category field
                        color: color.toHex(),
                        hotkey: hotkey.isEmpty ? nil : hotkey,
                        durationType: durationType,
                        autoDurationSeconds: durationType == .auto ? autoDurationSeconds : nil,
                        activationTrigger: activationTrigger,
                        deactivationTrigger: deactivationTrigger,
                        activationLinks: activationLinks.isEmpty ? nil : Array(activationLinks),
                        deactivationLinks: deactivationLinks.isEmpty ? nil : Array(deactivationLinks),
                        mutualExclusiveWith: mutualExclusiveWith.isEmpty ? nil : Array(mutualExclusiveWith),
                        leadTimeSeconds: leadTimeSeconds > 0 ? leadTimeSeconds : nil,
                        lagTimeSeconds: lagTimeSeconds > 0 ? lagTimeSeconds : nil,
                        x: moment.x,  // Preserve canvas position
                        y: moment.y
                    )
                    onSave(savedMoment)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.accent)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(name.isEmpty || category.isEmpty)
            }
            .padding(20)
            .background(theme.surfaceBackground)
        }
        .frame(width: 600, height: 750)
        .background(theme.primaryBackground)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func eventTriggerPicker(trigger: Binding<MomentEventTrigger>, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Trigger type selector
            Menu {
                Button("Manual (default)") {
                    trigger.wrappedValue = .manual
                }

                Menu("When another moment starts") {
                    ForEach(existingMoments.filter { $0.id != moment.id }, id: \.id) { otherMoment in
                        Button(otherMoment.category) {
                            trigger.wrappedValue = .onMomentStart(otherMoment.id)
                        }
                    }
                }

                Menu("When another moment ends") {
                    ForEach(existingMoments.filter { $0.id != moment.id }, id: \.id) { otherMoment in
                        Button(otherMoment.category) {
                            trigger.wrappedValue = .onMomentEnd(otherMoment.id)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(triggerDescription(trigger.wrappedValue))
                        .font(.system(size: 12))
                        .foregroundColor(theme.primaryText)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(theme.tertiaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.surfaceBackground)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func triggerDescription(_ trigger: MomentEventTrigger) -> String {
        switch trigger {
        case .manual:
            return "Manual (default)"
        case .onMomentStart(let momentId):
            if let moment = existingMoments.first(where: { $0.id == momentId }) {
                return "When '\(moment.category)' starts"
            }
            return "On moment start"
        case .onMomentEnd(let momentId):
            if let moment = existingMoments.first(where: { $0.id == momentId }) {
                return "When '\(moment.category)' ends"
            }
            return "On moment end"
        }
    }

    @ViewBuilder
    private func momentMultiSelector(selectedIds: Binding<Set<String>>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected moments chips
            if !selectedIds.wrappedValue.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(selectedIds.wrappedValue), id: \.self) { momentId in
                        if let selectedMoment = existingMoments.first(where: { $0.id == momentId }) {
                            HStack(spacing: 4) {
                                Text(selectedMoment.category)
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.primaryText)

                                Button(action: {
                                    selectedIds.wrappedValue.remove(momentId)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.tertiaryText)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: selectedMoment.color).opacity(0.3))
                            .cornerRadius(4)
                        }
                    }
                }
            }

            // Add button
            Menu {
                ForEach(existingMoments.filter { $0.id != moment.id }, id: \.id) { otherMoment in
                    Button(action: {
                        if selectedIds.wrappedValue.contains(otherMoment.id) {
                            selectedIds.wrappedValue.remove(otherMoment.id)
                        } else {
                            selectedIds.wrappedValue.insert(otherMoment.id)
                        }
                    }) {
                        HStack {
                            Text(otherMoment.category)
                            Spacer()
                            if selectedIds.wrappedValue.contains(otherMoment.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(theme.accent)

                    Text(selectedIds.wrappedValue.isEmpty ? placeholder : "Add more...")
                        .font(.system(size: 12))
                        .foregroundColor(theme.tertiaryText)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.surfaceBackground)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    BlueprintEditorView()
        .environmentObject(NavigationState())
        .frame(width: 1440, height: 900)
}
