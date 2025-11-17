# View Decomposition Plan

## Goal
Reduce giant view files (2000+ LOC) into maintainable, testable components following the pattern:
```
View (~100 LOC) + ViewModel (state/logic) + Components (UI pieces)
```

## Current Status (from main branch, 2025-11-17)

### Giant Views Identified
1. **ProjectsView.swift** (2075 LOC) - List and management of projects
2. **InventoryDetailView.swift** (1995 LOC) - Detailed inventory item view
3. **SettingsView.swift** (1511 LOC) - App settings and preferences
4. **LabelDesignerView.swift** (1458 LOC) - Label design and printing
5. **ShoppingListView.swift** (1278 LOC) - Shopping list management
6. **CatalogView.swift** (1154 LOC) - Glass catalog browser

## Decomposition Pattern

### Step 1: Create ViewModel
Extract state and business logic to `ViewModels/XViewModel.swift`:
- Move @State properties
- Move data loading functions
- Move computed properties (filtering, sorting)
- Keep UI-only state in view (sheet presentation, etc.)

### Step 2: Extract Components
Move inline view builders and helper structs to `Components/`:
- Empty states
- List rows
- Toolbars
- Section views
- Helper components

### Step 3: Update Main View
- Use ViewModel for state
- Reference extracted components
- Keep coordination logic only

## Detailed Plans

### InventoryDetailView.swift (1995 LOC → ~300 LOC target)

**Status**: ✅ ViewModel created (commit 35ec9d23)

**Components to Extract** (7 helper structs, lines 1088-1995):
1. `ExpandableSection` (34 LOC) → `Shared/Components/ExpandableSection.swift`
   - Generic, reusable expandable section with animation
   - Could be used in other views

2. `InventoryDetailTypeRow` (105 LOC) → `Components/InventoryDetailTypeRow.swift`
   - Displays inventory grouped by type
   - Shows subtypes, dimensions, quantity

3. `ShoppingListOptionsView` (154 LOC) → `Components/ShoppingListOptionsView.swift`
   - Shopping list item management
   - Quantity, store, notes editing

4. `InventoryStorageDetailView` (248 LOC) → `Components/InventoryStorageDetailView.swift`
   - Shows inventory records by type/location
   - Grouping, filtering, editing

5. `InventoryRecordRow` (78 LOC) → `Components/InventoryRecordRow.swift`
   - Individual inventory record display
   - Quantity, location, subtype, dimensions

6. `InventoryEditView` (106 LOC) → `Components/InventoryEditView.swift`
   - Edit existing inventory record
   - Type, quantity, location, dimensions

7. `QuickAddInventoryView` (177 LOC) → `Components/QuickAddInventoryView.swift`
   - Quick add new inventory
   - Type selection, quantity, location

**Remaining in Main View** (~300 LOC):
- Init and dependencies
- Body with section layout
- Section builders (headerSection, glassItemDetailsSection, etc.)
- Sheet presentation logic
- Navigation

### ProjectsView.swift (2075 LOC → ~150 LOC target)

**Components Needed**:
1. `ProjectsViewModel` - Projects list state, search, filtering
2. `ProjectListView` - List display
3. `ProjectEmptyStateView` - Empty state UI
4. `ProjectNoResultsView` - No search results UI
5. `ProjectToolbar` - Toolbar actions

**Note**: ProjectDetailView (1365 LOC) is embedded in this file and should be extracted to its own file.

### SettingsView.swift (1511 LOC → ~200 LOC target)

**Sections to Extract** (identify by reading structure):
- General settings section
- COE glass preferences
- Sharing settings
- Subscription/entitlements
- Debug settings
- About/credits

**Pattern**: Each major section → Component file

### ShoppingListView.swift (1278 LOC → ~150 LOC target)

**Components Needed**:
1. `ShoppingListViewModel` - List state, filtering
2. `ShoppingListRow` - Individual item row
3. `ShoppingListEmptyState` - Empty state
4. `ShoppingListToolbar` - Actions

### CatalogView.swift (1154 LOC → ~150 LOC target)

**Status**: Already has ViewModel! (`CatalogViewModel.swift` - 574 LOC)

**Needs**: Component extraction for views
- List rows
- Filter chips
- Search header
- Empty states

## Implementation Priority

1. **InventoryDetailView** (in progress) - Most complex, biggest impact
2. **ShoppingListView** - Straightforward decomposition
3. **CatalogView** - Already has ViewModel, just needs components
4. **SettingsView** - Many independent sections, easy to extract
5. **ProjectsView** - Extract ProjectDetailView first, then decompose main view
6. **LabelDesignerView** - Complex printing logic, needs careful analysis

## Success Metrics

- No view file > 500 LOC
- ViewModels handle state/logic
- Components < 150 LOC each
- Tests can be written for ViewModels
- Code reuse increases

## Notes

- **Preserve Creative Work**: Main branch has active development. ALWAYS prioritize main's features over mechanical refactoring.
- **No Arbitrary Changes**: Only extract, don't rewrite logic.
- **Test After Each Step**: Build and verify after each component extraction.
- **Commit Frequently**: Small, focused commits for easy review/revert.
