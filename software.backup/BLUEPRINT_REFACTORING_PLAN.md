# Blueprint Editor Refactoring Plan

## Current State
- **File**: `Sources/UI/Views/BlueprintEditorView.swift`
- **Lines**: 2,813 lines (way too large!)
- **Status**: Working, but needs refactoring for maintainability

## Completed Fixes (This Session)
✅ Fixed drag-drop from canvas to sidebar (position-based detection)
✅ Fixed canvas filtering - only shows items with positions
✅ Fixed sidebar filtering - only shows items without positions
✅ Added global drag preview overlay (floats above sidebar)
✅ Enhanced category folder hover feedback
✅ Added comprehensive logging for debugging
✅ Fixed moment `isActive` state when dropping to sidebar
✅ Blocked dragging placeholder items
✅ Created directory structure for refactoring

## Proposed Component Structure

```
Sources/UI/Views/BlueprintEditor/
├── BlueprintEditorView.swift          (~200 lines - main coordinator)
│   - Manages overall state
│   - Coordinates between components
│   - Handles drag-drop state
│
├── Components/
│   ├── BlueprintCanvasView.swift      (~400 lines)
│   │   - Canvas area with grid
│   │   - Positioned moment/layer buttons
│   │   - Canvas drop detection
│   │
│   ├── BlueprintSidebarView.swift     (~300 lines)
│   │   - Left sidebar structure
│   │   - Category folders
│   │   - "Add Moment" button
│   │
│   ├── CategoryFolderView.swift       (~100 lines)
│   │   - Collapsible category folder
│   │   - Moment rows inside
│   │   - Drop zone for category
│   │
│   ├── MomentRowView.swift            (~50 lines)
│   │   - Individual moment row in sidebar
│   │   - Drag handling
│   │
│   ├── LayerRowView.swift             (~50 lines)
│   │   - Individual layer row in sidebar
│   │   - Drag handling
│   │
│   ├── BlueprintSettingsView.swift    (~200 lines)
│   │   - Right sidebar
│   │   - Keyboard mapping
│   │   - Moment/layer settings
│   │
│   └── BlueprintHeaderView.swift      (~150 lines)
│       - Blueprint selector
│       - Save/delete buttons
│       - Canvas controls
│
└── Handlers/
    └── README.md - Note: Keep drag handlers in main view
                   (SwiftUI state management works better this way)
```

## Refactoring Steps

### Phase 1: Extract Small Components
1. Create `MomentRowView.swift` - Extract `momentRow()` function
2. Create `LayerRowView.swift` - Extract `layerRow()` function
3. Create `CategoryFolderView.swift` - Extract `categoryGroup()` function

### Phase 2: Extract Major Views
4. Create `BlueprintHeaderView.swift` - Extract header controls
5. Create `BlueprintSidebarView.swift` - Extract left sidebar
6. Create `BlueprintCanvasView.swift` - Extract canvas area
7. Create `BlueprintSettingsView.swift` - Extract right sidebar

### Phase 3: Clean Up Main View
8. Reorganize `BlueprintEditorView.swift` to just coordinate components
9. Keep drag-drop handlers in main view (they need to mutate state)
10. Add clear comments and documentation

### Phase 4: Simplify Logic
11. Document the simple drag-drop flow:
    - Sidebar (no x,y) ↔ Canvas (has x,y)
    - Position detection: x < 350 = sidebar, x >= 350 = canvas
12. Remove any unnecessary complexity

## Category System Review

### Current Issues
- Categories are not database entities
- They're just values in `MomentButton.category` field
- No way to manage categories independently
- Defaults hardcoded in `DefaultMomentCategories`

### Proposed Solution
1. Create `Category` model in database with:
   - `id`, `name`, `color`, `sortOrder`
2. Seed with defaults: "Offense", "Defense"
3. Allow users to create/edit/delete categories
4. Foreign key relationship: `Moment.categoryId` → `Category.id`
5. Blueprint can specify which categories are active

## Next Session TODO
- [ ] Execute refactoring plan
- [ ] Test thoroughly after each extraction
- [ ] Update category system in database
- [ ] Add unit tests for drag-drop logic
- [ ] Document the simplified architecture

## Notes
- Keep commits small and focused
- Build after each component extraction
- Test drag-drop thoroughly
- Keep logging until system is stable
