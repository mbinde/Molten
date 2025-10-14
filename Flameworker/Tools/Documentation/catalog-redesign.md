# Catalog Redesign: Parent-Child Architecture Migration

## 🎯 Project Overview

**Objective:** Migrate from single-entity catalog structure to a parent-child architecture where `CatalogItemParent` holds shared properties and `CatalogItem` represents specific variants.

**Architecture Change:**
- **Before:** Single `CatalogItem` entity containing all properties
- **After:** `CatalogItemParent` ↔ `CatalogItem` (one-to-many relationship)

## 📊 Data Model Changes

### CatalogItemParent Entity
```swift
// Core shared properties across all variants
id: UUID (Primary Key)
base_name: String         // e.g., "Adamantium"
base_code: String         // e.g., "874"  
manufacturer: String      // e.g., "cim"
coe: String              // e.g., "104"
tags: String             // e.g., "brown, grey" (comma-separated)
```

### CatalogItem Entity (Child)
```swift
// Specific variant properties
id: String (Legacy Primary Key - keep for backward compatibility)
id2: UUID (New Primary Key - will replace id after migration)
parent: UUID (Foreign Key → CatalogItemParent.id)
item_type: String        // e.g., "rod", "frit", "sheet"
item_subtype: String?    // e.g., "coarse", "10x10", or empty
stock_type: String?      // e.g., "discontinued", or empty
manufacturer_url: String? // URL to manufacturer's product page
image_path: String?      // Local image file path
image_url: String?       // Remote image URL
```

## 🗂️ Impact Analysis

### Files Requiring Major Changes

#### **Data Layer (Models & Repositories)**
- [ ] `CatalogItemModel.swift` - Split into parent/child models
- [ ] `CoreDataCatalogRepository.swift` - Handle parent-child relationships
- [ ] New: `CatalogItemParentModel.swift` - Parent domain model
- [ ] New: Repository protocols for parent entities

#### **Service Layer**
- [ ] `CatalogService.swift` - Update for parent-child operations
- [ ] `DataLoadingService.swift` - **CRITICAL:** JSON parsing logic
- [ ] Search/filtering logic across parent-child hierarchy

#### **Data Import/Export**
- [ ] `CatalogDataModels.swift` - Update JSON decode models
- [ ] `JSONDataLoader.swift` - Parse into parent-child structure
- [ ] CSV/JSON converters - Handle new structure

#### **View Layer**
- [ ] Catalog views - Display parent-child relationships
- [ ] Search/filtering UI - Search across both entities
- [ ] Detail views - Show variant information

## 🚧 Implementation Plan - Two-Stage Migration

### **🔧 Two-Stage Strategy (Risk Mitigation)**

**Stage 1: Dual-Loading (Phases 1-3)**
- Keep existing CatalogItem loading completely unchanged
- ADD parallel CatalogItemParent creation from same JSON (1:1 relationship initially)
- ADD id2/parent fields to link both structures  
- All items default to "rod" type for simplification
- Result: Both old and new structures work simultaneously
- **Risk:** Low - existing functionality untouched

**Stage 2: Cleanup (Phases 4-6)**  
- Remove duplicate data loading from CatalogItem
- CatalogItem becomes pure child entity
- All code reads from parent-child structure
- Remove legacy fields
- **Risk:** Medium - requires thorough testing

### Phase 1: Foundation & Data Models ✅ COMPLETED
**Status:** 🟢 Complete

**Tasks:**
- [x] Create `CatalogItemParentModel.swift` with business logic
- [x] Update `CatalogItemModel.swift` for child entity (keep `id: String`, add `id2: UUID`)
- [x] Add backward compatibility initializers and helper methods
- [x] Address UUID/String conversion errors in CoreDataCatalogRepository
- [x] Add parent-child relationship validation
- [x] Define repository interfaces for both entities

### Phase 2A: Dual-Loading JSON Migration 🎯 START HERE
**Status:** 🔴 Not Started  

**Strategy:** Keep existing CatalogItem loading working while ALSO creating parent-child structure

**Tasks:**
- [ ] Analyze current JSON structure in `CatalogDataModels.swift`
- [ ] Design parent detection algorithm (group by base_name + manufacturer)
- [ ] Update `DataLoadingService.swift` to load BOTH structures:
  - [ ] Continue existing CatalogItem creation (unchanged)
  - [ ] ADD parallel CatalogItemParent creation
  - [ ] ADD CatalogItem.id2/parent field population
- [ ] Create JSON structure mapping documentation
- [ ] Test that existing functionality remains unbroken

**Dual-Loading Algorithm (Simplified for 1:1 Phase):**
```
For each JSON item:
1. CONTINUE: Create CatalogItem as before (existing code unchanged)
2. NEW: Create corresponding CatalogItemParent with:
   - base_name = item.name (or parsed base name)
   - base_code = item.code (or parsed base code) 
   - manufacturer = item.manufacturer
   - coe = item.coe (from JSON)
   - tags = item.tags
3. NEW: Set CatalogItem.id2 = new UUID
4. NEW: Set CatalogItem.parent = parent.id
5. NEW: Set CatalogItem.item_type = "rod" (default for Phase 2A)
6. RESULT: 1:1 parent-child relationship established from existing JSON
```

### Phase 2B: JSON Migration Cleanup (Later)
**Status:** 🔴 Not Started  

**Strategy:** Remove duplicate data loading once parent-child structure proven

**Tasks:**
- [ ] Remove CatalogItem property population (name, code, manufacturer, tags)
- [ ] CatalogItem becomes pure child entity (id2, parent, item_type, item_subtype, etc.)
- [ ] Update all code to read from parent-child instead of flat CatalogItem
- [ ] Remove duplicate fields from CatalogItem entity

### Phase 3: Repository Layer Updates
**Status:** 🔴 Not Started

**Tasks:**
- [ ] Create `CatalogItemParentRepository` protocol
- [ ] Implement `CoreDataCatalogItemParentRepository`
- [ ] Update `CoreDataCatalogRepository` for parent relationship
- [ ] Add parent-child query operations
- [ ] Update mock repositories for testing

### Phase 4: Service Layer Migration  
**Status:** 🔴 Not Started

**Tasks:**
- [ ] Update `CatalogService.swift` for parent-child operations
- [ ] Implement parent-aware search functionality
- [ ] Add parent-child creation/update workflows
- [ ] Update change detection logic

### Phase 5: View Layer Updates
**Status:** 🔴 Not Started

**Tasks:**
- [ ] Update catalog list views for parent-child display
- [ ] Implement variant grouping/ungrouping UI
- [ ] Update search to work across parent-child hierarchy
- [ ] Add parent-child navigation flows

### Phase 6: Testing & Validation
**Status:** 🔴 Not Started

**Tasks:**
- [ ] Update existing tests for new models
- [ ] Add parent-child relationship tests
- [ ] Test JSON import with new structure
- [ ] Integration testing across layers

## 🔥 Breaking Changes & Migration Strategy

### Immediate Compilation Failures Expected:
1. **Model Properties:** Existing code references `CatalogItemModel` properties that will move to parent
2. **Repository Calls:** Single-entity operations become parent-child operations  
3. **JSON Parsing:** Current flat structure parsing will fail
4. **View Bindings:** UI bound to old model structure

### Migration Strategy:
1. **Disable Broken Features:** Comment out failing views/features temporarily
2. **Bottom-Up Migration:** Start with models, then repositories, then services, then views
3. **Maintain API Compatibility:** Create adapter methods where possible
4. **Incremental Testing:** Test each layer before proceeding to next

## 📝 Key Design Decisions Needed

### JSON Parsing Strategy:
**Question:** How do we determine parent vs child properties from current JSON?
**Answer:** Right now assume all entries are of type "rod" - this simplifies initial implementation

### Parent Detection Algorithm:
**Question:** How do we group items into parents?
**Answer:** For Phase 2A, there's just one CatalogItem per parent (1:1 relationship initially)
**Future:** Later we will restructure the JSON to have explicit parent-child relationships
**COE Concern:** Resolved - for a given parent, all items will have the same COE values

### Backward Compatibility:
**Strategy:** Use `id2: UUID` for new primary keys while keeping `id: String` for legacy compatibility
**Migration Path:** 
1. Phase 1-5: Both `id` (String) and `id2` (UUID) coexist
2. Phase 6: Migrate all references from `id` to `id2`
3. Phase 7: Remove `id` field completely

## 🧪 Testing Strategy

### Critical Test Cases:
- [ ] JSON parsing creates correct parent-child relationships
- [ ] Search works across parent and child properties
- [ ] Repository operations maintain data integrity
- [ ] UI displays parent-child hierarchy correctly

### Test Data Requirements:
- [ ] JSON with multiple variants of same parent
- [ ] JSON with single-variant parents  
- [ ] Edge cases (missing fields, malformed data)

## 📊 Progress Tracking

### Overall Progress: 25% Complete

**Phase 1 - Foundation:** 🟢 100% ✅ **COMPLETED**
**Phase 2A - Dual-Loading JSON:** 🔴 0% ← **NEXT**
**Phase 2B - JSON Cleanup:** 🔴 0%
**Phase 3 - Repositories:** 🔴 0%
**Phase 4 - Services:** 🔴 0%  
**Phase 5 - Views:** 🔴 0%
**Phase 6 - Migration Cleanup:** 🔴 0%
**Phase 7 - Testing:** 🔴 0%

## 🚨 Risk Assessment

### High Risk Areas:
1. **JSON Parsing Logic** - Complex parent detection algorithm
2. **Data Migration** - Existing Core Data to new structure  
3. **Search Performance** - Queries across parent-child relationships
4. **UI Complexity** - Displaying hierarchical data in lists

### Mitigation Strategies:
- Start with JSON parsing to validate approach
- Create comprehensive test data sets
- Implement feature flags for gradual rollout
- Maintain detailed migration documentation

---

## 📋 Next Steps - Two-Stage Migration

### **🎯 Stage 1: Dual-Loading (Safe Transition)**

1. **Immediate:** Start with Phase 2A - Dual-Loading JSON Migration
2. **Keep Safe:** All existing CatalogItem loading continues unchanged
3. **Add New:** Parallel CatalogItemParent creation + linking via id2/parent
4. **Test:** Verify existing functionality remains completely unbroken

### **🎯 Stage 2: Cleanup (After Validation)**

5. **Remove Duplicates:** Stop loading duplicate data into CatalogItem
6. **Pure Child:** CatalogItem becomes pure child entity  
7. **Update Code:** All reads switch to parent-child structure
8. **Final Cleanup:** Remove legacy fields

**Current Focus:** Phase 2A - Design dual-loading algorithm that creates both structures from single JSON pass.

**Ready to begin Phase 2A dual-loading JSON migration.**
