# Entity ID Field Analysis - Confusion & Issues

## Summary
Analyzing all domain models to identify ID field inconsistencies, incomplete migrations, and violations of the architecture rule:
- **Machine IDs**: `id: UUID` (internal, unique per entity instance)
- **Cross-references**: `stable_id: String` (human-readable, cross-platform, e.g. "bullseye-001-0")

---

## ❌ CRITICAL ISSUES

### 1. CatalogItemModel - INCOMPLETE MIGRATION
**File**: `Molten/Sources/Models/Domain/CatalogItemModel.swift`

**Current State** (lines 14-16):
```swift
let id: String        // Legacy primary key - keep for backward compatibility
let id2: UUID         // New primary key - will replace id after migration
let parent_id: UUID   // Foreign key to CatalogItemParentModel.id
```

**Issues**:
- Has TWO id fields (`id: String` and `id2: UUID`)
- Comments mention "backward compatibility" and "migration" that never finished
- Default initializer (line 34) generates `id: String` as `UUID().uuidString` - wasteful conversion
- Convenience initializer (line 107) also does this: `self.id = UUID().uuidString`
- NO `stable_id` field visible in the model struct

**Core Data Schema**:
- `id` String (optional)
- `id2` UUID (optional)
- Has `stable_id` String in Core Data (found via grep, but not in model struct?)

**Questions**:
1. Should CatalogItems have BOTH `id: UUID` AND `stable_id: String`?
2. Or should they ONLY have `stable_id` (like LocationModel does)?
3. Where is `stable_id` in the CatalogItemModel struct definition?

**Repository Usage** (`CoreDataCatalogRepository.swift`):
- Line 49: Uses `id` String for queries: `NSPredicate(format: "id == %@", item.id)`
- Line 98-106: Has method `deleteItem(id2: UUID)` using UUID
- Line 125: Has method `fetchItem(id2: UUID)` using UUID
- Inconsistent - some queries use `id`, others use `id2`

---

### 2. UserNotesModel - WRONG TYPE
**File**: `Molten/Sources/Models/Domain/UserNotesModel.swift`

**Current State** (lines 12-14):
```swift
let id: String
let item_stable_id: String
let notes: String
```

**Issues**:
- `id` is `String` but should be `UUID`
- Initializer (line 17) generates: `id: String = UUID().uuidString`
- Converting UUID → String → back to UUID is wasteful
- `item_stable_id` is CORRECT (cross-reference to catalog item)

**Fix**:
```swift
let id: UUID                    // ✅ Machine ID
let item_stable_id: String      // ✅ Cross-reference
let notes: String
```

**Initializer should be**:
```swift
init(id: UUID = UUID(), item_stable_id: String, notes: String)
```

---

## ✅ CORRECT PATTERNS

### 3. LocationModel - CORRECT (stable_id as primary key)
**File**: `Molten/Sources/Models/Domain/LocationModel.swift`

**Current State** (lines 15, 45):
```swift
protocol LocationModel: Identifiable, Equatable, Hashable, Sendable {
    nonisolated var stable_id: String { get }
    // ...
}

extension LocationModel {
    nonisolated var id: String { stable_id }  // ✅ Uses stable_id as primary key
}
```

**Assessment**: ✅ **CORRECT**
- Locations don't have UUID
- They ONLY have `stable_id`
- `stable_id` acts as both primary key and cross-reference
- Makes sense: locations are shared across users/devices, stable_id is canonical

---

### 4. ProjectModel - CORRECT (UUID id, stable_id for references)
**File**: `Molten/Sources/Models/Domain/ProjectModels.swift`

**Current State** (line 166):
```swift
nonisolated struct ProjectModel: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    // ... (no stable_id - projects are user-specific)
}
```

**ProjectGlassItem** (lines 15-17):
```swift
struct ProjectGlassItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let stableId: String?  // Reference to glass item (e.g., "bullseye-clear-0")
    let freeformDescription: String?  // For non-catalog items
}
```

**Assessment**: ✅ **CORRECT**
- ProjectModel has `id: UUID` (user-owned entity)
- ProjectGlassItem has BOTH:
  - `id: UUID` (its own identity)
  - `stableId: String?` (reference to catalog item)
- Clear separation of concerns

---

### 5. PurchaseRecordModel - CORRECT
**File**: `Molten/Sources/Models/Domain/PurchaseRecordModel.swift`

**Current State** (line 13):
```swift
struct PurchaseRecordModel: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    // ...
}
```

**PurchaseRecordItemModel** (line 139):
```swift
struct PurchaseRecordItemModel: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let stableId: String  // Reference to catalog item
    // ...
}
```

**Assessment**: ✅ **CORRECT**
- Purchase records have `id: UUID` (user-owned)
- Purchase items have BOTH `id: UUID` and `stableId: String` (catalog reference)

---

## 🤔 UNCLEAR / NEEDS INVESTIGATION

### 6. CompleteInventoryItemModel - Uses stable_id as id
**File**: `Molten/Sources/Models/Domain/CompleteInventoryItemModel.swift`

**Current State** (lines 20, 27):
```swift
struct CompleteInventoryItemModel: Identifiable, Equatable, Hashable, Sendable {
    let catalogItem: UnifiedCatalogItem
    let inventory: [InventoryModel]
    // ...
    
    nonisolated var id: String { catalogItem.stable_id }
}
```

**Assessment**: ✅ **CORRECT**
- This is an aggregate/view model, not a stored entity
- Uses catalog item's `stable_id` as the id
- Makes sense: the complete inventory is identified by the catalog item it represents

---

### 7. ItemShoppingModel - stable_id reference
**File**: `Molten/Sources/Models/Domain/ItemShoppingModel.swift`

**Current State** (line 12):
```swift
struct ItemShoppingModel: ItemQuantityModel, Equatable, Hashable, Codable, @unchecked Sendable {
    // Inherits from ItemQuantityModel
}
```

**Need to check**: `ItemQuantityModel` protocol definition

---

## 📋 ACTION ITEMS

### Immediate Fixes Needed:

1. **CatalogItemModel** - CLARIFY ARCHITECTURE
   - Questions for user:
     - Should catalog items have `id: UUID` + `stable_id: String`?
     - Or ONLY `stable_id: String` (like locations)?
   - If UUID + stable_id:
     - Remove `id: String`
     - Rename `id2: UUID` → `id: UUID`
     - Add `stable_id: String` to model (seems to exist in Core Data?)
   - Update all repository queries to use correct field

2. **UserNotesModel** - SIMPLE FIX
   - Change `id: String` → `id: UUID`
   - Update initializer default: `id: UUID = UUID()`
   - Update Core Data mapping if needed
   - Keep `item_stable_id: String` (correct as-is)

3. **Core Data Schema Cleanup**
   - Remove `id` String field from CatalogItem entity (if we keep UUID)
   - Remove `id2` UUID field from CatalogItem entity (rename to `id`)
   - Ensure `stable_id` exists

### Investigation Needed:

1. Where is `stable_id` defined in CatalogItemModel? (Not visible in struct, but Core Data has it)
2. Check `UnifiedCatalogItem` - what fields does it have?
3. Check `ItemQuantityModel` protocol definition
4. Search for any other entities with `id: String` that should be `id: UUID`

---

## 🎯 DESIRED END STATE

### Entity Types:

**Type 1: Shared/Catalog Entities (no UUID needed)**
- CatalogItems (?)
- Locations
- ONLY have: `stable_id: String`
- `Identifiable.id` returns `stable_id`

**Type 2: User-Owned Entities**
- Projects
- PurchaseRecords
- UserNotes
- Inventory (?)
- Have: `id: UUID`
- May reference catalog items via `stable_id: String` or `item_stable_id: String`

**Type 3: Aggregate/View Models**
- CompleteInventoryItemModel
- Use underlying entity's id (usually `stable_id` from catalog items)

---

## 🔍 GREP RESULTS FOR REFERENCE

**Entities with `stable_id`** (from Grep search):
- ShoppingListModels.swift
- InventoryDetailModels.swift
- CompleteInventoryItemModel.swift
- UserNotesModel.swift (has `item_stable_id`)
- UnifiedLocationModel.swift
- ItemQuantityModel.swift
- ItemShoppingModel.swift
- LocationModel.swift
- PurchaseRecordModel.swift (has `stableId` in items)
- StoreDataModels.swift
- CatalogDataModels.swift
- CatalogUpdateModels.swift
- AnyLocationModel.swift

**Entities with `id: String`** (from Grep search):
- AnyLocationModel.swift (computed: `var id: String { _model.id }`)
- CatalogDataModels.swift (`let id: String?` - DTO, not domain model)
- LocationModel.swift (computed: `nonisolated var id: String { stable_id }`)
- WeightUnit.swift (enum: `var id: String { rawValue }`)
- LocationType.swift (enum: `var id: String { rawValue }`)
- UnifiedLocationModel.swift (computed: `nonisolated var id: String { stable_id }`)
- CatalogItemModel.swift (`let id: String` ← **PROBLEM**)
- CompleteInventoryItemModel.swift (computed: `nonisolated var id: String { catalogItem.stable_id }`)
- UserNotesModel.swift (`let id: String` ← **PROBLEM**)

**Core Data CatalogItem attributes**:
- `id` String
- `id2` UUID
- `stable_id` String (confirmed exists)
- `parent` UUID
- (many others...)

