# Flameworker Test Plan

## Executive Summary

This document outlines comprehensive testing strategy for the Flameworker iOS app. The app currently has **97 test files** covering many areas, but several critical components and edge cases remain under-tested.

**Current Test Coverage:**
- ✅ **Strong**: Repositories (Core Data & Mock), Basic service operations, Search utilities
- ⚠️ **Moderate**: View components, Data loading, Error handling
- ❌ **Weak**: Type system, New features, Integration scenarios, Migration paths

## Test Architecture Overview

### Test Targets
1. **FlameworkerTests** (Unit Tests) - Mock-only, no Core Data
2. **RepositoryTests** - Core Data repository integration tests
3. **PerformanceTests** - Load and performance benchmarks
4. **FlameworkerUITests** - End-to-end UI automation

### Testing Philosophy (TDD)
- RED → GREEN → REFACTOR
- Business logic in models (tested in unit tests)
- Services orchestrate (tested with mocks)
- Repositories persist (tested with isolated Core Data)

---

## Phase 1: Critical Gaps (High Priority)

### 1.1 Type System (NEW - Recently Added)
**Status**: ❌ No tests exist
**Location**: `Models/Domain/GlassItemTypeSystem.swift`

**Required Tests:**
```
✓ Type definition validation
  - All 9 types are registered (rod, stringer, sheet, frit, tube, powder, scrap, murrini, enamel)
  - Each type has correct subtypes
  - Dimension fields are correctly defined

✓ Type lookup operations
  - getType(named:) returns correct type
  - getSubtypes(for:) returns correct subtypes
  - getDimensionFields(for:) returns correct fields

✓ Validation logic
  - isValidType() correctly validates type names
  - isValidSubtype() validates subtype for given type
  - validateDimensions() catches missing required dimensions
  - validateDimensions() catches negative values

✓ Display formatting
  - formatDimension() formats values correctly
  - formatDimensions() creates proper display strings
  - shortDescription() creates compact descriptions

✓ Edge cases
  - Case-insensitive type lookup
  - Empty dimension dictionaries
  - Types with no subtypes
  - Types with no dimensions
```

**Priority**: P0 (Critical - new feature, no tests)
**Estimated Effort**: 4-6 hours

---

### 1.2 Shopping List Item Creation (NEW - Recently Added)
**Status**: ⚠️ Test template created but not added to project
**Location**: `Views/Shopping/AddShoppingListItemView.swift`, `TEST_SHOPPING_LIST_TEMPLATE.md`

**Required Tests:**
```
✓ Minimal field creation (item + quantity)
✓ Full field creation (all optional fields)
✓ Type/subtype integration with GlassItemTypeSystem
✓ Multiple items for same glass item
✓ Store filtering and retrieval
✓ Validation edge cases (negative quantities, empty fields)
```

**Action Required**: Add test file to FlameworkerTests target via Xcode
**Priority**: P0 (Critical - new feature)
**Estimated Effort**: 1-2 hours (template exists, just needs to be added)

---

### 1.3 Shared Component: GlassItemSearchSelector
**Status**: ❌ No tests exist
**Location**: `Views/Shared/Components/GlassItemSearchSelector.swift`

**Required Tests:**
```
✓ Search filtering
  - Filters by name
  - Filters by natural key
  - Filters by manufacturer
  - Case-insensitive matching

✓ Selection behavior
  - onSelect callback fires correctly
  - onClear callback fires correctly
  - Selected item displays properly

✓ State management
  - Search text updates filter results
  - Clear resets selection
  - Prefilled natural key behavior

✓ UI states
  - Empty state (no search)
  - Search results state
  - Selected state
  - Not found state
```

**Priority**: P0 (Critical - shared component used in multiple views)
**Estimated Effort**: 3-4 hours

---

### 1.4 Inventory Type/Subtype/Dimension Persistence
**Status**: ⚠️ Basic tests exist, edge cases missing
**Location**: `Repositories/CoreData/CoreDataInventoryRepository.swift`

**Required Tests:**
```
✓ Round-trip persistence (DONE ✓)
✓ Backward compatibility (DONE ✓)
✓ Type changes (rod → stringer)
✓ Subtype changes (fine → medium)
✓ Dimension updates (add/remove/modify)
✓ JSON serialization edge cases
  - Very large dimension values
  - Unicode dimension keys
  - Empty dimension dictionaries
  - Null vs empty handling
```

**Priority**: P1 (High - data integrity critical)
**Estimated Effort**: 2-3 hours

---

## Phase 2: Service Layer (Medium Priority)

### 2.1 ProjectService
**Status**: ⚠️ Partial coverage
**Location**: `Services/Core/ProjectService.swift`

**Required Tests:**
```
✓ Project creation with glass items
✓ Project image management
  - Add hero image
  - Add multiple images
  - Remove images
  - Reorder images

✓ Project plan operations
  - Create plan
  - Update plan
  - Convert plan to log
  - Track plan usage

✓ Project log operations
  - Create log
  - Update log status
  - Inventory deduction
  - Sale tracking

✓ Glass item associations
  - Add items to project
  - Remove items
  - Update quantities
  - Data serialization
```

**Priority**: P1 (High - complex domain logic)
**Estimated Effort**: 6-8 hours

---

### 2.2 PurchaseRecordService
**Status**: ⚠️ Basic tests exist, edge cases missing
**Location**: `Services/Core/PurchaseRecordService.swift`

**Required Tests:**
```
✓ Purchase record creation
✓ Inventory linking (purchase → inventory)
✓ Supplier tracking
✓ Price calculations
✓ Date filtering
✓ Bulk operations
✓ Error scenarios (invalid catalog codes, negative prices)
```

**Priority**: P1 (High - financial tracking)
**Estimated Effort**: 3-4 hours

---

### 2.3 InventoryTrackingService - Complete Item Workflow
**Status**: ⚠️ Basic operations tested, complex workflows missing
**Location**: `Services/Core/InventoryTrackingService.swift`

**Required Tests:**
```
✓ createCompleteItem() with all fields
✓ createCompleteItem() with minimal fields
✓ addInventory() with locations
✓ subtractInventory() edge cases (zero quantity)
✓ Cross-type operations (same item, multiple types)
✓ Batch operations
✓ Location distribution logic
✓ Concurrent modifications
```

**Priority**: P1 (High - core functionality)
**Estimated Effort**: 4-5 hours

---

## Phase 3: View Layer (Medium Priority)

### 3.1 InventoryDetailView
**Status**: ⚠️ Partial coverage
**Location**: `Views/Inventory/InventoryDetailView.swift`

**Required Tests:**
```
✓ Display all inventory types
✓ Type/subtype/dimension display
✓ Edit operations
✓ Add inventory flow
✓ Shopping list integration
✓ User notes/tags integration
✓ Image upload integration
```

**Priority**: P2 (Medium - complex view)
**Estimated Effort**: 5-6 hours

---

### 3.2 AddInventoryItemView
**Status**: ⚠️ Basic flow tested, edge cases missing
**Location**: `Views/Inventory/AddInventoryItemView.swift`

**Required Tests:**
```
✓ Glass item search
✓ Prefilled natural key
✓ Type/subtype selection
✓ Dimension input validation
✓ Location input
✓ Save operation
✓ Cancel operation
✓ Error handling
```

**Priority**: P2 (Medium - critical user flow)
**Estimated Effort**: 4-5 hours

---

### 3.3 ShoppingListView
**Status**: ⚠️ Service tested, view untested
**Location**: `Views/Shopping/ShoppingListView.swift`

**Required Tests:**
```
✓ Empty state display
✓ Grouped by store
✓ Sorting options (quantity, name, store)
✓ Filtering (tags, COE, store)
✓ Search integration
✓ Add item flow
✓ Refresh operation
```

**Priority**: P2 (Medium - important feature)
**Estimated Effort**: 4-5 hours

---

### 3.4 PurchasesView
**Status**: ❌ No tests exist
**Location**: `Views/Purchases/PurchasesView.swift`, `Views/Purchases/AddPurchaseRecordView.swift`

**Required Tests:**
```
✓ Purchase list display
✓ Filtering and sorting
✓ Add purchase flow
✓ Edit purchase flow
✓ Delete purchase
✓ Purchase detail view
✓ Link to inventory
```

**Priority**: P2 (Medium)
**Estimated Effort**: 5-6 hours

---

### 3.5 ProjectLogView
**Status**: ❌ No tests exist
**Location**: `Views/ProjectLog/ProjectLogView.swift`

**Required Tests:**
```
✓ Project log list
✓ Create from plan
✓ Create new log
✓ Edit log
✓ Image management
✓ Glass item tracking
✓ Sale recording
✓ Status transitions
```

**Priority**: P2 (Medium - complex feature)
**Estimated Effort**: 6-8 hours

---

## Phase 4: Domain Models (Medium-Low Priority)

### 4.1 ItemShoppingModel
**Status**: ❌ Limited tests
**Location**: `Models/Domain/ItemShoppingModel.swift`

**Required Tests:**
```
✓ Model creation with all fields
✓ Model creation with minimal fields
✓ Business logic validation
✓ Type/subtype consistency
✓ Equatable conformance
✓ Codable conformance
```

**Priority**: P2 (Medium)
**Estimated Effort**: 2-3 hours

---

### 4.2 ProjectModels
**Status**: ⚠️ Basic tests exist
**Location**: `Models/Domain/ProjectModels.swift`

**Required Tests:**
```
✓ ProjectLogModel validation
✓ ProjectPlanModel validation
✓ ProjectStepModel validation
✓ Glass item data serialization
✓ Status transitions
✓ Price calculations
✓ Time tracking
```

**Priority**: P2 (Medium)
**Estimated Effort**: 4-5 hours

---

### 4.3 PurchaseRecordModel
**Status**: ⚠️ Basic tests exist
**Location**: `Models/Domain/PurchaseRecordModel.swift`

**Required Tests:**
```
✓ Model creation
✓ Price calculations
✓ Unit conversions
✓ Validation rules
✓ Codable conformance
```

**Priority**: P3 (Low)
**Estimated Effort**: 2-3 hours

---

## Phase 5: Utilities (Low Priority)

### 5.1 CatalogFormatters
**Status**: ❌ No tests
**Location**: `Utilities/CatalogFormatters.swift`

**Required Tests:**
```
✓ Manufacturer name formatting
✓ SKU formatting
✓ Natural key generation
✓ Display name formatting
```

**Priority**: P3 (Low - simple utilities)
**Estimated Effort**: 1-2 hours

---

### 5.2 DesignSystem
**Status**: ❌ No tests
**Location**: `Utilities/DesignSystem.swift`

**Required Tests:**
```
✓ Color definitions
✓ Typography scales
✓ Spacing values
✓ Corner radius values
```

**Priority**: P4 (Very Low - mostly constants)
**Estimated Effort**: 1 hour

---

### 5.3 JSON5Parser
**Status**: ❌ No tests
**Location**: `Utilities/JSON5Parser.swift`

**Required Tests:**
```
✓ Standard JSON parsing
✓ JSON5 extensions (comments, trailing commas)
✓ Error handling
✓ Unicode handling
✓ Large file handling
```

**Priority**: P3 (Low - but important for data loading)
**Estimated Effort**: 3-4 hours

---

## Phase 6: Integration & Edge Cases (Medium Priority)

### 6.1 Data Migration Scenarios
**Status**: ⚠️ Basic recovery tested
**Location**: `Repositories/CoreData/Persistence.swift`

**Required Tests:**
```
✓ Model version upgrades
✓ Migration failure recovery
✓ CloudKit sync conflicts
✓ Data corruption recovery
✓ Large dataset migration
```

**Priority**: P1 (High - critical for production)
**Estimated Effort**: 6-8 hours

---

### 6.2 Cross-Entity Workflows
**Status**: ⚠️ Some integration tests exist
**Location**: Multiple

**Required Tests:**
```
✓ Create glass item → Add to inventory → Create purchase
✓ Set minimum → Generate shopping list → Purchase → Add to inventory
✓ Create project plan → Execute project → Deduct inventory → Record sale
✓ Search → Filter → Sort → View details workflow
✓ Import data → Validate → Display workflow
```

**Priority**: P1 (High - user experience)
**Estimated Effort**: 8-10 hours

---

### 6.3 Concurrent Access Scenarios
**Status**: ❌ No tests
**Location**: All repositories

**Required Tests:**
```
✓ Concurrent inventory updates
✓ Race conditions in quantity operations
✓ Shopping list concurrent modifications
✓ Project concurrent edits
✓ Image upload conflicts
```

**Priority**: P2 (Medium - CloudKit sync critical)
**Estimated Effort**: 5-6 hours

---

### 6.4 Error Boundary Testing
**Status**: ⚠️ Basic error handling tested
**Location**: All services

**Required Tests:**
```
✓ Network failures during data load
✓ Disk full during image save
✓ Out of memory scenarios
✓ Invalid data recovery
✓ Partial operation rollback
```

**Priority**: P2 (Medium)
**Estimated Effort**: 4-5 hours

---

## Phase 7: Performance & Load Testing (Low Priority)

### 7.1 Large Dataset Performance
**Status**: ⚠️ Some performance tests exist
**Location**: `Tests/PerformanceTests/`

**Required Tests:**
```
✓ 10,000+ glass items
✓ 50,000+ inventory records
✓ 1,000+ shopping list items
✓ Complex search queries
✓ Batch operations
✓ Memory usage
```

**Priority**: P3 (Low - but important for scale)
**Estimated Effort**: 4-5 hours

---

### 7.2 Image Handling Performance
**Status**: ❌ No performance tests
**Location**: `Repositories/FileSystem/FileSystemUserImageRepository.swift`

**Required Tests:**
```
✓ Large image upload
✓ Multiple concurrent uploads
✓ Image loading performance
✓ Thumbnail generation
✓ Disk space management
```

**Priority**: P3 (Low)
**Estimated Effort**: 3-4 hours

---

## Phase 8: UI Testing (Low Priority)

### 8.1 Critical User Flows
**Status**: ⚠️ Minimal UI tests
**Location**: `Tests/FlameworkerUITests/`

**Required Tests:**
```
✓ Onboarding flow
✓ Add first glass item
✓ Create inventory
✓ Generate shopping list
✓ Record purchase
✓ Create project
✓ Search and filter
```

**Priority**: P3 (Low - covered by unit tests mostly)
**Estimated Effort**: 8-10 hours

---

## Test Implementation Guidelines

### Test File Naming Convention
```
[Component][Tests].swift
Examples:
- GlassItemTypeSystemTests.swift
- AddShoppingListItemViewTests.swift
- ProjectServiceTests.swift
```

### Test Organization
```swift
@Suite("Component Name Tests")
struct ComponentTests {

    // Setup
    init() async throws {
        RepositoryFactory.configureForTesting()
    }

    // MARK: - Happy Path Tests
    @Test("Description")
    func testFeature() async throws {
        // Given
        // When
        // Then
        #expect(condition)
    }

    // MARK: - Edge Cases

    // MARK: - Error Handling

    // MARK: - Test Helpers
}
```

### Coverage Goals
- **P0 (Critical)**: 90%+ coverage
- **P1 (High)**: 80%+ coverage
- **P2 (Medium)**: 70%+ coverage
- **P3 (Low)**: 50%+ coverage
- **P4 (Very Low)**: Optional

---

## Effort Summary

| Phase | Priority | Estimated Hours | Status |
|-------|----------|----------------|--------|
| **Phase 1: Critical Gaps** | P0-P1 | 14-19 hours | 🔴 Must Do |
| **Phase 2: Service Layer** | P1 | 13-17 hours | 🟠 Should Do |
| **Phase 3: View Layer** | P2 | 18-22 hours | 🟡 Nice to Have |
| **Phase 4: Domain Models** | P2-P3 | 8-11 hours | 🟡 Nice to Have |
| **Phase 5: Utilities** | P3-P4 | 5-7 hours | 🟢 Optional |
| **Phase 6: Integration** | P1-P2 | 23-29 hours | 🟠 Should Do |
| **Phase 7: Performance** | P3 | 7-9 hours | 🟢 Optional |
| **Phase 8: UI Testing** | P3 | 8-10 hours | 🟢 Optional |
| **Total** | | **96-124 hours** | |

---

## Immediate Action Items

### Week 1: Critical Gaps (Phase 1)
1. ✅ Add `ShoppingListItemCreationTests.swift` to FlameworkerTests target
2. ⏳ Create `GlassItemTypeSystemTests.swift` (4-6 hours)
3. ⏳ Create `GlassItemSearchSelectorTests.swift` (3-4 hours)
4. ⏳ Enhance `CoreDataInventoryRepositoryTests.swift` with edge cases (2-3 hours)

**Target**: Complete Phase 1 in 1-2 weeks

### Week 2-3: Service Layer (Phase 2)
1. ⏳ Create comprehensive `ProjectServiceTests.swift`
2. ⏳ Enhance `PurchaseRecordServiceTests.swift`
3. ⏳ Enhance `InventoryTrackingServiceTests.swift`

**Target**: Complete Phase 2 in 2-3 weeks

### Month 2: Integration & View Layer (Phases 3 & 6)
Focus on integration tests and critical view tests

### Ongoing: Maintain Coverage
- Add tests for every new feature (TDD)
- Review coverage reports monthly
- Update this plan quarterly

---

## Test Infrastructure Improvements

### Recommended Additions
1. **Code Coverage Reporting**
   - Enable coverage in test scheme
   - Set minimum coverage thresholds
   - Generate coverage reports

2. **Test Data Builders**
   - Create test data factories
   - Reusable test fixtures
   - Reduce test setup duplication

3. **Snapshot Testing**
   - Add SwiftSnapshotTesting
   - Test view layouts
   - Detect UI regressions

4. **Performance Baselines**
   - Set performance benchmarks
   - Track performance over time
   - Alert on regressions

---

## Notes

- This plan prioritizes **data integrity** (type system, inventory) and **new features** (shopping list)
- **TDD approach**: Write tests BEFORE implementing new features
- **Regression prevention**: All bugs should get a test that reproduces them
- **Coverage != Quality**: Focus on meaningful tests, not just coverage %

---

## Version History

- **v1.0** (2025-10-18): Initial test plan created based on codebase analysis
  - 149 source files analyzed
  - 97 test files reviewed
  - Identified 8 major phases of testing work
  - Estimated 96-124 hours of testing effort needed
