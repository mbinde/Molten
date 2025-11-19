# View Decomposition Progress

**Goal**: Decompose giant view files (1000+ LOC) into small, testable, reusable components following the pattern:
- Main view: ~100-200 LOC (orchestration only)
- ViewModels: Extract @State variables and business logic
- Components: 50-100 LOC each (focused, single responsibility)

## Progress Summary

| View File | Original LOC | Current LOC | Target LOC | Status | Components Created |
|-----------|--------------|-------------|------------|--------|-------------------|
| ProjectsView.swift | 2,075 | 1,677 | 300 | 🟡 In Progress | Removed dead code (400 LOC) |
| SettingsView.swift | 1,513 | 1,513 | 200 | ⚪ Not Started | - |
| ShoppingListView.swift | 1,278 | 1,278 | 200 | ⚪ Not Started | - |
| LabelDesignerView.swift | 1,252 | 1,252 | 250 | ⏸️ Skip (WIP elsewhere) | - |
| InventoryDetailView.swift | 1,169 | 1,169 | 200 | ⚪ Not Started | - |
| CatalogView.swift | 1,154 | 1,154 | 200 | ⏸️ Skip (per request) | - |

**Total**: 8,441 LOC → Target: ~1,550 LOC (**~82% reduction**)

---

## Decomposition Plans

### 1. SettingsView.swift (1,513 LOC → ~200 LOC) - NEXT

**Current Status:** MUCH BETTER THAN EXPECTED!
- File is 1,513 LOC, but main view is only **341 LOC** (lines 119-459)
- Already has 8 extracted sub-views:
  - ✅ DataManagementView (lines 461-615)
  - ✅ COEFilterView (lines 617-653)
  - ✅ ManufacturerFilterView (lines 655-797)
  - ✅ SubscriptionManagementView (lines 984-1125)
  - ✅ KilnRatesSettingsView (lines 1189-1293)
  - ✅ TerminologySettingsView (lines 1323-1410)
  - ✅ ImageQualitySettingsView (lines 1413-1514)
  - Plus various UI components

**Remaining Work:**
- Main `SettingsView` struct (341 LOC) can be further decomposed
- Extract ViewModel for state management
- Break body into section components

**Decomposition Strategy:**
```
SettingsView.swift (~100 LOC) - orchestrator only
  ├── ViewModels/
  │   └── SettingsViewModel.swift (~80 LOC)
  └── Components/
      ├── GeneralSettingsSection.swift (~60 LOC) - Appearance, Tabs, Temperature
      ├── CatalogDisplaySection.swift (~80 LOC) - Catalog updates, sorts, toggles
      ├── FilteringSection.swift (~50 LOC) - COE, Manufacturer, Tag filters
      ├── ContentCustomizationSection.swift (~70 LOC) - Author, Terminology, Ratings, Owner
      └── AdvancedSettingsSection.swift (~80 LOC) - Debug, Sentry, Subscription override
```

**Steps:**
1. ✅ Analyze current structure
2. ⚪ Create SettingsViewModel
3. ⚪ Extract GeneralSettingsSection
4. ⚪ Extract CatalogDisplaySection
5. ⚪ Extract FilteringSection
6. ⚪ Extract ContentCustomizationSection
7. ⚪ Extract AdvancedSettingsSection
8. ⚪ Simplify main SettingsView to orchestrator
9. ⚪ Test & commit

---

### 2. ShoppingListView.swift (1,278 LOC → ~200 LOC)

**Decomposition Strategy:**
```
ShoppingListView.swift (~150 LOC)
  ├── ViewModels/
  │   └── ShoppingListViewModel.swift (~100 LOC)
  └── Components/
      ├── ShoppingListRow.swift (~60 LOC)
      ├── AddShoppingItemSheet.swift (~80 LOC)
      ├── ShoppingFilterBar.swift (~70 LOC)
      └── ShoppingListEmptyState.swift (~40 LOC)
```

---

### 3. InventoryDetailView.swift (1,169 LOC → ~200 LOC)

**Decomposition Strategy:**
```
InventoryDetailView.swift (~150 LOC)
  ├── ViewModels/
  │   └── InventoryDetailViewModel.swift (~100 LOC)
  └── Components/
      ├── InventoryItemInfoSection.swift (~80 LOC)
      ├── InventoryLocationSection.swift (~70 LOC)
      ├── InventoryHistorySection.swift (~80 LOC)
      ├── InventoryActionsSection.swift (~60 LOC)
      └── InventoryImageGallery.swift (~70 LOC)
```

---

### 4. ProjectsView.swift (1,677 LOC → ~300 LOC) - PARTIALLY DONE

**Status:** Removed 400 LOC of dead code
**Remaining Work:** Split ProjectDetailView (~1,362 LOC) into separate file

**Decomposition Strategy:**
```
ProjectsView.swift (~150 LOC) - list view only
ProjectDetailView.swift (~200 LOC) - moved to separate file
  ├── ViewModels/
  │   └── ProjectDetailViewModel.swift (~120 LOC)
  └── Components/
      ├── ProjectDetailsSection.swift (~80 LOC)
      ├── ProjectTagsSection.swift (~60 LOC)
      ├── ProjectStepsSection.swift (~90 LOC)
      ├── ProjectGlassSection.swift (~80 LOC)
      ├── ProjectImagesSection.swift (~70 LOC)
      └── ProjectReferencesSection.swift (~70 LOC)
```

---

## Skipped (Working on elsewhere or deferred)

- **LabelDesignerView.swift** (1,252 LOC) - Being worked on in another window
- **CatalogView.swift** (1,154 LOC) - Deferred per request

---

## Decomposition Principles

Following the pattern from your friend's advice:

1. **Main View (50-150 LOC)**: Orchestration only
   - Navigation setup
   - Call ViewModel methods
   - Compose child components
   - NO business logic, NO complex @State

2. **ViewModel (80-150 LOC)**: State + coordination
   - All @State/@Published properties
   - Async operations
   - Service calls
   - NO UI code

3. **Components (30-100 LOC each)**: Single responsibility
   - One section/feature per file
   - Receive data via parameters
   - Emit actions via closures
   - Easily testable

4. **Impact**:
   - From: 2,000 LOC monolith
   - To: 8 files of 50-100 LOC each
   - Result: Testable, reusable, maintainable

---

Last Updated: 2025-01-18
