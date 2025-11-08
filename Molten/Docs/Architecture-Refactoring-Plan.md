# Architecture Refactoring Plan

**Branch**: `refactoring`
**Date**: 2025-11-08
**Goal**: Move service-layer models to domain layer for proper MVVM + Repository + Service Layer architecture

## Architecture Assessment

**Current Grade**: A- (Excellent with minor improvements needed)

### Strengths ✅
- ViewModels never call Repositories directly (always through Services)
- Models contain all business logic (validation, normalization, computed properties)
- Services only orchestrate (no business rules)
- Repositories are pure persistence layer
- Views have no logic (pure SwiftUI presentation)
- Test coverage: 0.69:1 ratio, 1,505 tests across 114 suites

### Violations Found ⚠️

**Violation 1: Business Logic in Service-Layer Models**
- **Files**: `ShoppingListService.swift`, `InventoryTrackingService.swift`
- **Issue**: Models contain business rules but live in Service files
- **Examples**:
  - `DetailedShoppingListItemModel.priorityScore` (line 454-458)
  - `DetailedShoppingListItemModel.urgencyLevel` (line 488-500)
  - `DetailedLowStockItemModel.shortfall` (line 510-518)
  - `StoreStatisticsModel.restockingPercentage` (line 529-532)
  - `LowStockDetailModel.shortfall` (line 348-350)

**Violation 2: Domain Model in Service Layer**
- **File**: `Services/Core/SharedModels.swift`
- **Issue**: `CompleteInventoryItemModel` used throughout app as domain model
- **Problem**: Lives in Services layer instead of Domain layer

## Refactoring Steps

### Step 1: Create New Domain Model Files ✅
- [ ] Create `Models/Domain/ShoppingListModels.swift`
- [ ] Create `Models/Domain/InventoryDetailModels.swift`
- [ ] Create `Models/Domain/CompleteInventoryItemModel.swift`

### Step 2: Move Models from ShoppingListService.swift
- [ ] Move `DetailedShoppingListItemModel` (lines 448-518)
  - Includes: `priorityScore`, `urgencyLevel`, computed properties
- [ ] Move `DetailedLowStockItemModel` (lines 520-551)
  - Includes: `meetsMinimum`, `shortfall`, computed properties
- [ ] Move `DetailedMinimumModel` (lines 553-571)
  - Includes: `meetsMinimum`, `shortfall`, computed properties
- [ ] Move `StoreStatisticsModel` (lines 573-608)
  - Includes: `restockingPercentage`, computed properties
- [ ] Update imports in `ShoppingListService.swift`

### Step 3: Move Models from InventoryTrackingService.swift
- [ ] Move `LowStockDetailModel` (lines 344-353)
  - Includes: `shortfall` computed property
- [ ] Update imports in `InventoryTrackingService.swift`

### Step 4: Move CompleteInventoryItemModel
- [ ] Move from `Services/Core/SharedModels.swift` to new file
- [ ] Update all imports across codebase:
  - ViewModels: `CatalogViewModel`, `InventoryViewModel`, etc.
  - Services: `CatalogService`, `InventoryTrackingService`, etc.
  - Views: Any views using this model

### Step 5: Update Test Files
- [ ] Update test imports to reference new model locations
- [ ] Run full test suite: `xcodebuild test -project Molten.xcodeproj -scheme Molten -parallel-testing-enabled NO`
- [ ] Fix any broken tests

### Step 6: Verify Build & Tests
- [ ] Clean build: `xcodebuild clean`
- [ ] Full build: `xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' build`
- [ ] Run all tests (parallel disabled): `xcodebuild test -parallel-testing-enabled NO`
- [ ] Verify 1,505 tests still pass

### Step 7: Update Documentation
- [ ] Update `CLAUDE.md` if needed with new model locations
- [ ] Add this refactoring to project history

### Step 8: Commit & Push
- [ ] Commit changes with descriptive message
- [ ] Push branch to remote
- [ ] Create pull request to main

## File Structure Changes

### Before
```
Molten/Sources/
├── Services/Core/
│   ├── ShoppingListService.swift
│   │   └── (contains DetailedShoppingListItemModel, DetailedLowStockItemModel, etc.)
│   ├── InventoryTrackingService.swift
│   │   └── (contains LowStockDetailModel)
│   └── SharedModels.swift
│       └── (contains CompleteInventoryItemModel)
└── Models/Domain/
    ├── GlassItemModel.swift
    ├── InventoryModel.swift
    └── ...
```

### After
```
Molten/Sources/
├── Services/Core/
│   ├── ShoppingListService.swift
│   │   └── (no models, only service logic)
│   ├── InventoryTrackingService.swift
│   │   └── (no models, only service logic)
│   └── SharedModels.swift
│       └── (deprecated or removed)
└── Models/Domain/
    ├── GlassItemModel.swift
    ├── InventoryModel.swift
    ├── ShoppingListModels.swift ← NEW
    │   └── (DetailedShoppingListItemModel, DetailedLowStockItemModel, etc.)
    ├── InventoryDetailModels.swift ← NEW
    │   └── (LowStockDetailModel)
    └── CompleteInventoryItemModel.swift ← NEW
        └── (CompleteInventoryItemModel)
```

## Risk Assessment

**Risk Level**: Low

**Reasoning**:
- Simple file moves, no behavioral changes
- High test coverage (0.69:1 ratio) will catch issues
- Models are self-contained with no complex dependencies
- Swift's compiler will catch any missed import updates

**Rollback Plan**:
- `git checkout main` to revert if issues arise
- No database migrations or data structure changes

## Expected Outcome

- **Architecture Grade**: A → A+ (Perfect separation of concerns)
- **No behavior changes**: All functionality remains identical
- **All tests pass**: 1,505 tests across 114 suites
- **Better maintainability**: Domain models clearly separated from infrastructure
- **Improved clarity**: Business logic location is obvious to developers

## Notes

- This refactoring aligns with the project's architecture philosophy:
  > **"Business logic lives in the Model layer. Services orchestrate. Repositories persist."**
- Models with business rules (computed properties for `priorityScore`, `urgencyLevel`, etc.) belong in Domain layer
- Services should only contain orchestration logic, not model definitions
