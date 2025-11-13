# Business Logic Refactoring Plan

**Date:** 2025-11-12
**Status:** IN PROGRESS (2/17 complete)
**Principle:** "Business logic lives in the Model layer. Services orchestrate. Repositories persist."

## Executive Summary

Audit found **17 instances** of business logic hiding in services across 3 files:
- InventoryTrackingService: 4 instances (29% contamination)
- ShoppingListService: 7 instances (41% contamination)
- CatalogService: 6 instances (29% contamination)
- PurchaseRecordService: 0 instances ✅ (Gold Standard)

**Impact:** ~500-800 lines of business logic needs to move from services → models with proper test coverage.

---

## Progress Tracker

### ✅ Completed (2/17)

1. **CompleteInventoryItemModel.hasInventory** (commit 2dd33c35)
   - Added computed property: `inventory.contains { $0.quantity > 0 }`
   - 5 unit tests added
   - Business rule: Item has inventory if ANY record has positive quantity

2. **DetailedShoppingListItemModel** Comparable (commit 2dd33c35)
   - Added Comparable conformance for priority-based sorting
   - 5 unit tests added
   - 2 service locations updated (ShoppingListService:89, 194)
   - Business rule: Sort by neededQuantity descending (most urgent first)

---

## Remaining Work (15/17)

### Category 1: Sorting Logic (7 instances)

#### 3. LowStockDetailModel - Comparable
**Location:** InventoryTrackingService:300
**Business Rule:** Sort by currentQuantity ascending (lowest stock = highest priority)
**Implementation:**
```swift
extension LowStockDetailModel: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.currentQuantity < rhs.currentQuantity
    }
}
```
**Tests:** 4-5 tests for sorting, edge cases
**Service Update:** `items.sort { $0.currentQuantity < $1.currentQuantity }` → `items.sort()`

---

#### 4. DetailedMinimumModel - Comparable
**Location:** ShoppingListService:323
**Business Rule:** Sort by type alphabetically
**Implementation:**
```swift
extension DetailedMinimumModel: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.minimum.type < rhs.minimum.type
    }
}
```
**Tests:** 3 tests
**Service Update:** `detailedMinimums.sort { $0.minimum.type < $1.minimum.type }` → `detailedMinimums.sort()`

---

#### 5. StoreStatisticsModel - Comparable
**Location:** ShoppingListService:366
**Business Rule:** Sort by currentNeedsCount descending (stores with most needs first)
**Implementation:**
```swift
extension StoreStatisticsModel: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.currentNeedsCount > rhs.currentNeedsCount // Descending
    }
}
```
**Tests:** 4 tests
**Service Update:** `stats.sort { $0.currentNeedsCount > $1.currentNeedsCount }` → `stats.sort()`

---

#### 6. ManufacturerStatisticsModel - Comparable
**Location:** CatalogService:415
**Business Rule:** Sort by itemCount descending (most used manufacturers first)
**Implementation:**
```swift
extension ManufacturerStatisticsModel: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.itemCount > rhs.itemCount // Descending
    }
}
```
**Tests:** 4 tests
**Service Update:** `stats.sort { $0.itemCount > $1.itemCount }` → `stats.sort()`

---

#### 7-8. GlassItemSortOption - Sorting Helper
**Location:** CatalogService:63-83, 525-556
**Business Rule:** Sort catalog items by name/manufacturer/COE/totalQuantity with fallback sorting
**Implementation:** Create `Models/Helpers/CatalogSortingHelpers.swift`
```swift
extension GlassItemSortOption {
    /// Sort items using this option
    func sort(_ items: [GlassItemModel]) -> [GlassItemModel] {
        items.sorted { lhs, rhs in
            switch self {
            case .name:
                return lhs.name < rhs.name
            case .manufacturer:
                if lhs.manufacturer != rhs.manufacturer {
                    return lhs.manufacturer < rhs.manufacturer
                }
                return lhs.name < rhs.name // Fallback
            case .coe:
                if lhs.coe != rhs.coe {
                    return lhs.coe < rhs.coe
                }
                return lhs.name < rhs.name // Fallback
            case .totalQuantity:
                // Note: requires inventory context, handled by CompleteInventoryItemModel version
                return lhs.name < rhs.name
            }
        }
    }

    /// Sort complete items (with inventory) using this option
    func sort(_ items: [CompleteInventoryItemModel]) -> [CompleteInventoryItemModel] {
        items.sorted { lhs, rhs in
            switch self {
            case .totalQuantity:
                if lhs.totalQuantity != rhs.totalQuantity {
                    return lhs.totalQuantity > rhs.totalQuantity // Descending
                }
                return lhs.glassItem.name < rhs.glassItem.name // Fallback
            case .name:
                return lhs.glassItem.name < rhs.glassItem.name
            case .manufacturer:
                if lhs.glassItem.manufacturer != rhs.glassItem.manufacturer {
                    return lhs.glassItem.manufacturer < rhs.glassItem.manufacturer
                }
                return lhs.glassItem.name < rhs.glassItem.name
            case .coe:
                if lhs.glassItem.coe != rhs.glassItem.coe {
                    return lhs.glassItem.coe < rhs.glassItem.coe
                }
                return lhs.glassItem.name < rhs.glassItem.name
            }
        }
    }
}
```
**Tests:** 12-15 tests (all sort options × 2-3 test cases each)
**Service Updates:**
- CatalogService.getGlassItemsLightweight: Use `sortOption.sort(items)`
- CatalogService.sortItems: Use `sortOption.sort(items)`

---

#### 9. DetailedLowStockItemModel - Comparable (Secondary)
**Location:** Not explicitly in audit, but mentioned as related to LowStockDetailModel
**Business Rule:** Sort by shortfall (highest shortfall first)
**Implementation:**
```swift
extension DetailedLowStockItemModel: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.lowStockItem.shortfall > rhs.lowStockItem.shortfall // Descending
    }
}
```
**Tests:** 4 tests

---

### Category 2: Validation (1 instance)

#### 10. InventoryModel - Non-Negative Quantity Validation
**Location:** InventoryTrackingService:320-324 (validateInventoryConsistency)
**Business Rule:** Quantity cannot be negative (domain invariant)
**Implementation:** Follow ItemMinimumModel pattern (line 148)
```swift
// In InventoryModel.init():
self.quantity = max(0.0, quantity) // Enforce non-negative quantity
```
**Tests:** 5 tests
- Test negative input → becomes 0
- Test zero input → stays 0
- Test positive input → unchanged
- Test large negative → becomes 0
- Test fractional negative → becomes 0

**Service Impact:** `validateInventoryConsistency` method can be simplified or removed (validation now happens at construction)

---

### Category 3: Filtering Logic (4 instances)

#### 11. CompleteInventoryItemModel.hasInventory - Service Usage
**Location:** InventoryTrackingService:243-248, CatalogService:107-113
**Status:** Property exists (added in commit 2dd33c35), but services still use repository-level filtering
**Analysis:** Current service code does repository-level filtering for performance (filters before fetching tags).
**Decision:** Leave as-is. The `hasInventory` property is available for other use cases, but repository-level filtering is the right orchestration for these methods.
**Action:** None required.

---

#### 12. GlassItemSearchRequest.filter() Extension
**Location:** CatalogService.applyFilters (lines 468-523)
**Business Rule:** Filter items by tags, manufacturers, COE, status, inventory
**Implementation:** Create `Models/Helpers/CatalogFilteringHelpers.swift`
```swift
extension GlassItemSearchRequest {
    /// Apply all filters to a list of items
    /// - Parameters:
    ///   - items: Items to filter
    ///   - inventoryCheck: Closure to check if item has inventory (repository coordination)
    /// - Returns: Filtered items
    func filter(
        _ items: [CompleteInventoryItemModel],
        inventoryCheck: (String) -> Bool
    ) -> [CompleteInventoryItemModel] {
        var filtered = items

        // Filter by tags
        if let tags = self.tags, !tags.isEmpty {
            filtered = filtered.filter { item in
                let itemTags = Set(item.allTags)
                return tags.allSatisfy { itemTags.contains($0.lowercased()) }
            }
        }

        // Filter by manufacturers
        if let manufacturers = self.manufacturers, !manufacturers.isEmpty {
            let manufacturerSet = Set(manufacturers.map { $0.lowercased() })
            filtered = filtered.filter { item in
                manufacturerSet.contains(item.glassItem.manufacturer.lowercased())
            }
        }

        // Filter by COE
        if let coeFilter = self.coe {
            filtered = filtered.filter { item in
                item.glassItem.coe == coeFilter
            }
        }

        // Filter by status
        if let statusFilter = self.status {
            filtered = filtered.filter { item in
                item.glassItem.mfr_status == statusFilter
            }
        }

        // Filter by inventory (uses repository check for coordination)
        if let hasInventory = self.hasInventory, hasInventory {
            filtered = filtered.filter { item in
                inventoryCheck(item.glassItem.stable_id)
            }
        }

        return filtered
    }
}
```
**Tests:** 10-12 tests (one per filter type + combinations)
**Service Update:** Replace inline filtering logic with `searchRequest.filter(items, inventoryCheck: { ... })`

---

### Category 4: Aggregation & Calculation (5 instances)

#### 13. InventorySummaryModel - Factory Method
**Location:** InventoryTrackingService.getInventorySummary (lines 183-207)
**Business Rule:** Aggregate inventory by location/type
**Implementation:** Add static factory to InventorySummaryModel (or new DetailedInventorySummaryModel)
```swift
extension DetailedInventorySummaryModel {
    static func from(inventory: [InventoryModel]) -> DetailedInventorySummaryModel {
        let byLocation = Dictionary(grouping: inventory.filter { $0.location != nil }) {
            $0.location!
        }

        let locationSummaries = byLocation.map { location, records in
            let byType = Dictionary(grouping: records) { $0.type }
            let typeSummaries = byType.map { type, typeRecords in
                let totalQty = typeRecords.reduce(0.0) { $0 + $1.quantity }
                return (type: type, quantity: totalQty)
            }
            return (location: location, summaries: typeSummaries)
        }

        return DetailedInventorySummaryModel(
            summary: InventorySummaryModel(totalQuantity: inventory.reduce(0.0) { $0 + $1.quantity }),
            locationSummaries: locationSummaries
        )
    }
}
```
**Tests:** 6-8 tests
**Service Update:** Replace aggregation loop with `DetailedInventorySummaryModel.from(inventory)`

---

#### 14. ShoppingListItemModel.merged(with:)
**Location:** ShoppingListService.generateAllShoppingLists (lines 136-169)
**Business Rule:** Merge manual shopping items with auto-generated minimum-based items using `max(existing, manual)` for quantities
**Implementation:**
```swift
extension ShoppingListItemModel {
    /// Merge this shopping item with another (for same item+type+store)
    /// Business rule: Use max of needed quantities
    func merged(with other: ShoppingListItemModel) -> ShoppingListItemModel {
        precondition(self.item_stable_id == other.item_stable_id && self.type == other.type && self.store == other.store,
                     "Can only merge shopping items for same item/type/store")

        let combinedNeeded = max(self.neededQuantity, other.neededQuantity)

        return ShoppingListItemModel(
            item_stable_id: self.item_stable_id,
            type: self.type,
            currentQuantity: self.currentQuantity, // Use self's current quantity
            minimumQuantity: self.currentQuantity + combinedNeeded,
            store: self.store
        )
    }
}
```
**Tests:** 5-6 tests
**Service Update:** Replace merging logic with `existingItem.merged(with: manualItem)`

---

#### 15. LowStockReportModel - Factory Method
**Location:** ShoppingListService.getLowStockReport (lines 233-238)
**Business Rule:** Group low stock items by store and calculate statistics
**Implementation:**
```swift
extension LowStockReportModel {
    static func from(items: [DetailedLowStockItemModel]) -> LowStockReportModel {
        let groupedByStore = Dictionary(grouping: items) { $0.lowStockItem.store }

        let totalShortfall = items.reduce(0.0) { $0 + $1.lowStockItem.shortfall }
        let storesAffected = Set(items.map { $0.lowStockItem.store }).count

        return LowStockReportModel(
            items: items,
            groupedByStore: groupedByStore,
            totalItemsLow: items.count,
            totalShortfall: totalShortfall,
            storesAffected: storesAffected,
            generatedAt: Date()
        )
    }
}
```
**Tests:** 6 tests
**Service Update:** Replace grouping/statistics logic with `LowStockReportModel.from(detailedItems)`

---

#### 16. DetailedShoppingListModel.estimatedValue
**Location:** ShoppingListService.estimateTotalValue (lines 418-424)
**Business Rule:** Calculate total value ($10 per unit placeholder)
**Implementation:**
```swift
extension DetailedShoppingListModel {
    /// Estimated total value of shopping list
    /// Business rule: $10 per needed unit (placeholder until real pricing added)
    var estimatedValue: Double {
        items.reduce(0.0) { total, item in
            total + (item.shoppingListItem.neededQuantity * 10.0)
        }
    }
}
```
**Tests:** 3-4 tests
**Service Update:** Replace calculation method with computed property access

---

#### 17. CatalogOverviewModel - Factory Method
**Location:** CatalogService.getSystemOverview (lines 558-576)
**Business Rule:** Aggregate catalog statistics
**Implementation:**
```swift
extension CatalogOverviewModel {
    static func from(
        totalItems: Int,
        totalManufacturers: Int,
        totalTags: Int,
        itemsWithInventory: Int,
        lowStockItems: Int
    ) -> CatalogOverviewModel {
        return CatalogOverviewModel(
            totalItems: totalItems,
            totalManufacturers: totalManufacturers,
            totalTags: totalTags,
            itemsWithInventory: itemsWithInventory,
            lowStockItems: lowStockItems,
            generatedAt: Date()
        )
    }
}
```
**Tests:** 3 tests
**Service Update:** Replace direct struct creation with factory method (mainly for documentation/consistency)

---

## Test Files to Create

1. ✅ `CompleteInventoryItemModelTests.swift` - DONE
2. ✅ `ShoppingListModelsSortingTests.swift` - DONE
3. `LowStockDetailModelTests.swift`
4. `DetailedMinimumModelTests.swift`
5. `StoreStatisticsModelTests.swift`
6. `ManufacturerStatisticsModelTests.swift`
7. `CatalogSortingHelpersTests.swift`
8. `InventoryModelValidationTests.swift`
9. `CatalogFilteringHelpersTests.swift`
10. `InventorySummaryModelTests.swift`
11. `ShoppingListItemModelMergeTests.swift`
12. `LowStockReportModelTests.swift`
13. `DetailedShoppingListModelTests.swift`
14. `CatalogOverviewModelTests.swift`

**Total:** ~70-90 new tests across 14 files

---

## Implementation Order

### Phase 1: Sorting (High Impact, Low Risk)
- Items 3-9: All Comparable conformances and sorting helpers
- Estimate: 2-3 hours
- Tests: ~35 tests

### Phase 2: Validation (High Priority, Simple)
- Item 10: InventoryModel validation
- Estimate: 30 minutes
- Tests: 5 tests

### Phase 3: Aggregation (Medium Complexity)
- Items 13-17: All factory methods and computed properties
- Estimate: 2-3 hours
- Tests: ~25 tests

### Phase 4: Filtering (Most Complex)
- Item 12: GlassItemSearchRequest.filter()
- Estimate: 1-2 hours
- Tests: 10-12 tests

**Total Estimate:** 6-9 hours
**Total Tests:** 75-87 new tests
**Impact:** Services become 50-70% thinner, models become primary test focus

---

## Migration Pattern (TDD)

For each item:

1. **🔴 RED:** Write failing test
2. **🟢 GREEN:** Add business logic to model
3. **🔵 REFACTOR:** Update service to use model logic
4. **✅ VERIFY:** Run all tests (new model tests + existing service tests)
5. **📝 COMMIT:** Single atomic commit per refactoring

Example commit message:
```
refactor: move [BusinessLogic] from service to model

- Add [ModelType].[method/property]
  - Business rule: [description]
  - Tested with X unit tests

- Updated [ServiceType] to use model logic (Y locations)

Impact:
- Service simplified: removed Z lines of business logic
- Model enriched: business rules now testable in isolation
- Test distribution: +X model tests

Part of audit finding: 17 instances of business logic in services
Progress: N/17 complete
```

---

## Success Metrics

**Before:**
- Model tests: 8,321 lines (11%)
- Service tests: 11,526 lines (16%)
- Repository tests: 15,659 lines (22%)
- Ratio: Services have MORE test code than models ❌

**After:**
- Model tests: ~11,000 lines (15%)
- Service tests: ~10,000 lines (14%)
- Repository tests: 15,659 lines (22%)
- Ratio: Models have MORE test code than services ✅

**Business Logic Distribution:**
- PurchaseRecordService: 0% (Gold Standard) ✅
- InventoryTrackingService: 29% → 5% ✅
- ShoppingListService: 41% → 10% ✅
- CatalogService: 29% → 8% ✅

---

## Notes

- All model logic is independently testable (no async, no repositories)
- Services become thin orchestration layers
- Pattern established in WeightUnit.swift (173 lines model, 390 lines tests = 2.25x ratio) should be the norm
- This refactoring aligns with stated architecture: "Business logic lives in the Model layer"

---

## References

- Audit Report: Generated 2025-11-12 via subagent analysis
- Example Pattern: ItemMinimumModel line 148 (non-negative validation)
- Example Pattern: DetailedShoppingListItemModel.priorityScore (business logic in model)
- Gold Standard: PurchaseRecordService (0% business logic)
