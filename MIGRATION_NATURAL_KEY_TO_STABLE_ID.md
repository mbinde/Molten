# Migration Plan: natural_key → stable_id

**Status**: Planning Phase
**Target**: Pre-release (app not shipped yet)
**Impact**: 577 occurrences across Swift codebase
**Risk Level**: Medium (comprehensive but mechanical changes)

## Overview

Migrate from `natural_key` (constructed identifier like `bullseye-001-001`) to `stable_id` (6-character hash like `3DyUbA`) as the primary identifier throughout the system.

### Why Migrate?

1. **natural_key was never "natural"** - It's constructed from manufacturer-sku-sequence
2. **Users don't want to see it** - Exposing `bullseye-001-001` feels wrong
3. **stable_id solves the same problems** - Deduplication, uniqueness, immutability
4. **stable_id is shorter** - 6 chars vs 20+ chars
5. **stable_id is already user-facing** - QR codes use it, so it MUST be stable
6. **Pre-release window** - Perfect time to make breaking changes

### What Users See

- ❌ **Before**: `natural_key` exposed in UI → `bullseye-001-001` (ugly, confusing)
- ✅ **After**: Display actual fields → "Bullseye Glass Co" + "SKU: 0001" (meaningful)
- 🔗 **IDs**: Internal `stable_id` → `3DyUbA` (never shown to users except in QR codes)

## Scope Analysis

**Total Occurrences**: 577 instances of `natural_key` in Swift code

**Files with Heavy Usage**:
- CoreDataInventoryRepository.swift: 48 occurrences
- MockInventoryRepository.swift: 47 occurrences
- CoreDataShoppingListRepository.swift: 30 occurrences
- MockShoppingListRepository.swift: 28 occurrences
- CoreDataUserNotesRepository.swift: 24 occurrences
- CatalogService.swift: 23 occurrences
- SharedModels.swift: 21 occurrences
- InventoryRepository.swift (protocol): 21 occurrences

**Affected Systems**:
- Core Data entities (Item, Inventory, ShoppingListItem, UserNotes)
- Repository layer (all glass item repositories)
- Service layer (CatalogService, InventoryTrackingService, ShoppingListService)
- Model layer (GlassItemModel, InventoryModel, CompleteInventoryItemModel)
- View layer (all views that display/reference glass items)
- Tests (577 occurrences include significant test coverage)

## Migration Strategy

### Phase 1: Core Data Schema
1. Add `stable_id` as non-optional String attribute to Item entity
2. Create new Core Data model version (Molten 9)
3. Make `stable_id` the primary key (indexed, required)
4. Keep `natural_key` temporarily for migration reference
5. Add lightweight migration mapping

### Phase 2: Domain Models
1. Update `GlassItemModel`:
   - Change `id` property from `natural_key` to `stable_id`
   - Make `stable_id` non-optional (required)
   - Keep `natural_key` as metadata field (optional)
2. Update related models:
   - `InventoryModel`: `item_natural_key` → `item_stable_id`
   - `CompleteInventoryItemModel`: Update grouping logic
   - `InventoryModel`: Change foreign key field

### Phase 3: Repository Layer
Update all repository protocols and implementations:

**Protocols to update**:
- `GlassItemRepository`: `fetchItem(byNaturalKey:)` → `fetchItem(byStableId:)`
- `InventoryRepository`: All methods referencing `item_natural_key`
- `ShoppingListRepository`: Foreign key references
- `UserNotesRepository`: Foreign key references

**Implementations to update**:
- CoreDataGlassItemRepository
- MockGlassItemRepository
- CoreDataInventoryRepository
- MockInventoryRepository
- CoreDataShoppingListRepository
- MockShoppingListRepository
- CoreDataUserNotesRepository
- MockUserNotesRepository
- CoreDataItemTagsRepository

### Phase 4: Service Layer
Update services to use stable_id:
- `CatalogService`: All operations
- `InventoryTrackingService`: Item lookups and creation
- `ShoppingListService`: Item references
- `UserNotesService`: Item references
- `GlassItemDataLoadingService`: Import logic

### Phase 5: View Layer
Update views to use stable_id:
- Navigation links (replace natural_key with stable_id)
- Deep linking handlers
- QR code generation (already uses stable_id)
- Search and filter views
- Detail views

### Phase 6: Tests
Update all test files:
- GlassItemModelTests
- CoreDataGlassItemRepositoryStableIdTests
- All repository tests
- All service tests
- Integration tests

### Phase 7: Data Migration (PUNT FOR NOW)

**Future Task**: When we have production users with existing data.

The app will need to:
1. Run one-time migration on first launch after update
2. Look up stable_id from glass_database.json for each natural_key
3. Update all Item entities with their stable_ids
4. Update all foreign key references in Inventory, ShoppingList, UserNotes

**For now**: Since there are no production users, we can:
- Delete and regenerate test data
- Regenerate glassitems.json with stable_ids
- Fresh import on next data load

## Implementation Steps

### Step 1: Prepare Database
```bash
# Regenerate glass_database.json with stable_ids
cd "Molten/Tools/Scraping Tools"
python3 update_database.py

# Export to glassitems.json
python3 update_database.py --export ../../glassitems.json
```

### Step 2: Update Core Data Model
1. Open Molten.xcdatamodeld in Xcode
2. Editor → Add Model Version → "Molten 9"
3. Update Item entity:
   - Add `stable_id` String attribute (non-optional, indexed)
   - Remove old indexes on `natural_key`
   - Add index on `stable_id`
4. Set Molten 9 as current version

### Step 3: Update GlassItemModel
```swift
struct GlassItemModel: Identifiable, Equatable, Hashable, Sendable {
    let stable_id: String  // Changed from natural_key, now non-optional
    let natural_key: String?  // Keep as metadata (optional)
    let name: String
    let sku: String
    let manufacturer: String
    // ... rest of fields

    var id: String { stable_id }  // Changed from natural_key

    // Update URI generation
    var uri: String { "moltenglass:item?\(stable_id)" }

    // Update equality to use stable_id
    static func == (lhs: GlassItemModel, rhs: GlassItemModel) -> Bool {
        return lhs.stable_id == rhs.stable_id
    }

    // Update hash to use stable_id
    func hash(into hasher: inout Hasher) {
        hasher.combine(stable_id)
    }
}
```

### Step 4: Update InventoryModel and Related Models
```swift
struct InventoryModel: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let item_stable_id: String  // Changed from item_natural_key
    let type: String
    // ... rest of fields
}

struct CompleteInventoryItemModel: Identifiable, Equatable, Hashable, Sendable {
    let glassItem: GlassItemModel
    let inventory: [InventoryModel]
    // ... rest of fields

    var id: String { glassItem.stable_id }  // Changed from natural_key
}

struct InventorySummaryModel: Identifiable, Equatable, Sendable {
    let item_stable_id: String  // Changed from item_natural_key
    let inventories: [InventoryModel]

    var id: String { item_stable_id }
}
```

### Step 5: Update Repository Protocols
```swift
// GlassItemRepository.swift
protocol GlassItemRepository {
    func fetchItem(byStableId stableId: String) async throws -> GlassItemModel?  // Changed
    func deleteItem(stableId: String) async throws  // Changed
    func stableIdExists(_ stableId: String) async throws -> Bool  // Changed
    // ... other methods
}

// InventoryRepository.swift
protocol InventoryRepository {
    func fetchInventories(forItemStableId stableId: String) async throws -> [InventoryModel]  // Changed
    func createInventory(forItemStableId stableId: String, inventory: InventoryModel) async throws  // Changed
    // ... other methods
}
```

### Step 6: Automated Search & Replace

**Safe replacements** (can be done with sed/regex):

```bash
# In Swift files
find Molten/Sources -name "*.swift" -type f -exec sed -i '' \
  's/item_natural_key/item_stable_id/g' {} \;

find Molten/Sources -name "*.swift" -type f -exec sed -i '' \
  's/byNaturalKey:/byStableId:/g' {} \;

find Molten/Sources -name "*.swift" -type f -exec sed -i '' \
  's/natural_key:/stable_id:/g' {} \;

find Molten/Sources -name "*.swift" -type f -exec sed -i '' \
  's/\.natural_key/.stable_id/g' {} \;

find Molten/Sources -name "*.swift" -type f -exec sed -i '' \
  's/(naturalKey:/(stableId:/g' {} \;

find Molten/Sources -name "*.swift" -type f -exec sed -i '' \
  's/naturalKey:/stableId:/g' {} \;
```

**Manual replacements needed**:
- Core Data fetch predicates: `natural_key == %@` → `stable_id == %@`
- KVC property access: `forKey: "natural_key"` → `forKey: "stable_id"`
- JSON decoding logic in GlassItemDataLoadingService
- Test data generation (update test fixtures)

### Step 7: Update Core Data Repositories

**Example: CoreDataGlassItemRepository**
```swift
func fetchItem(byStableId stableId: String) async throws -> GlassItemModel? {
    let request = NSFetchRequest<NSManagedObject>(entityName: "Item")
    request.predicate = NSPredicate(format: "stable_id == %@", stableId)  // Changed
    // ... rest of implementation
}

private func convertToGlassItemModel(_ entity: NSManagedObject) throws -> GlassItemModel {
    guard let stableId = entity.value(forKey: "stable_id") as? String else {  // Changed
        throw RepositoryError.invalidData("Missing stable_id")
    }
    let naturalKey = entity.value(forKey: "natural_key") as? String  // Now optional
    // ... rest of conversion

    return GlassItemModel(
        stable_id: stableId,  // Changed (now required)
        natural_key: naturalKey,  // Changed (now optional)
        name: name,
        sku: sku,
        // ...
    )
}

private func updateEntity(_ entity: NSManagedObject, with model: GlassItemModel) {
    entity.setValue(model.stable_id, forKey: "stable_id")  // Changed
    entity.setValue(model.natural_key, forKey: "natural_key")  // Now optional
    // ... rest of properties
}
```

### Step 8: Update Services

**Example: CatalogService**
```swift
actor CatalogService {
    func getItem(byStableId stableId: String) async throws -> CompleteInventoryItemModel? {
        // Changed method signature
        guard let item = try await glassItemRepository.fetchItem(byStableId: stableId) else {
            return nil
        }
        // ... rest of method
    }
}
```

### Step 9: Update GlassItemDataLoadingService

```swift
// Update natural key generation
private func extractStableId(from catalogItem: CatalogItemData) -> String? {
    return catalogItem.stable_id
}

private func generateStableId(manufacturer: String, sku: String) -> String {
    // If stable_id is missing from JSON, generate one
    // (Should rarely happen with new database system)
    let combined = "\(manufacturer):\(sku)"
    // ... hash generation logic
    return stableId
}

// Update item creation
let glassItem = GlassItemModel(
    stable_id: extractStableId(from: catalogItem) ?? generateStableId(...),  // Required
    natural_key: createNaturalKey(manufacturer: mfr, sku: sku, sequence: 0),  // Optional
    name: catalogItem.name,
    // ...
)
```

### Step 10: Update Tests

**Example test updates**:
```swift
// Before
let item = GlassItemModel(
    natural_key: "bullseye-001-001",
    stable_id: "abc123",
    // ...
)

// After
let item = GlassItemModel(
    stable_id: "abc123",
    natural_key: "bullseye-001-001",  // Now optional
    // ...
)
```

### Step 11: Run Tests & Verify

```bash
# Run all tests
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UnitTestsOnly \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'

# Run repository tests specifically
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan RepositoryTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## Rollout Plan

### Pre-Migration Checklist
- [ ] Backup current codebase (git commit)
- [ ] Regenerate glass_database.json with stable_ids
- [ ] Export fresh glassitems.json
- [ ] Document current test pass rate (baseline)

### Migration Execution
- [ ] Step 1: Update Core Data model (Molten 9)
- [ ] Step 2: Update GlassItemModel
- [ ] Step 3: Update InventoryModel and related models
- [ ] Step 4: Update repository protocols
- [ ] Step 5: Run automated search & replace
- [ ] Step 6: Manual updates (predicates, KVC, etc.)
- [ ] Step 7: Update Core Data repositories
- [ ] Step 8: Update services
- [ ] Step 9: Update views
- [ ] Step 10: Update tests
- [ ] Step 11: Run full test suite
- [ ] Step 12: Manual testing in simulator

### Post-Migration Validation
- [ ] All tests pass
- [ ] App launches successfully
- [ ] Can load glass items from JSON
- [ ] Can create/update/delete inventory
- [ ] Can search and filter
- [ ] QR codes still work
- [ ] Deep linking works
- [ ] No Core Data crashes

### Rollback Plan
If migration fails:
1. `git reset --hard HEAD` (revert all changes)
2. Or: `git revert <commit>` (if already committed)
3. Restore to pre-migration state
4. Review errors and plan fixes

## Risk Mitigation

### High-Risk Areas
1. **Core Data migrations** - Test thoroughly
2. **Repository implementations** - 95+ occurrences
3. **Foreign key relationships** - Inventory/ShoppingList/UserNotes all reference items
4. **Deep linking** - Must update URL parsing

### Testing Strategy
1. **Unit tests first** - Verify models work in isolation
2. **Repository tests** - Verify persistence works
3. **Integration tests** - Verify end-to-end flows
4. **Manual testing** - Test all major user flows in simulator

### Incremental Approach
Option to do migration in smaller chunks:
1. Phase 1: Models + repositories (get persistence working)
2. Phase 2: Services (get business logic working)
3. Phase 3: Views (get UI working)
4. Phase 4: Tests (update test data)

## Future Enhancements (Post-Migration)

### Stable ID Inheritance (Deferred)
When manufacturers change SKUs, implement logic to:
- Detect product succession (e.g., "001" → "001-R")
- Inherit stable_id from discontinued predecessor
- Keep QR codes working across SKU changes

**Location**: `update_database.py` - add `detect_product_succession()` method

**Timeline**: Implement when first real SKU change occurs in production

### Natural Key Deprecation
Once migration is complete and stable:
- Consider removing `natural_key` field entirely
- Or: Keep as debug/metadata field only
- Saves memory and simplifies model

## Notes

- **App not released yet**: Perfect time for breaking changes
- **No user data migration needed**: Can regenerate all test data
- **Mechanical changes**: Most replacements are straightforward find/replace
- **Well-tested system**: 1198 existing tests will catch regressions
- **Reversible**: Can revert via git if issues arise

## Estimated Effort

- **Planning**: 1 hour ✅ (this document)
- **Core Data model update**: 30 minutes
- **Model layer updates**: 1 hour
- **Repository layer updates**: 2-3 hours (most code here)
- **Service layer updates**: 1 hour
- **View layer updates**: 1 hour
- **Test updates**: 2-3 hours
- **Testing & validation**: 2-3 hours
- **Total**: ~12-15 hours of focused work

## Sign-off

**Created**: 2025-10-23
**Author**: Claude (AI Assistant)
**Status**: Ready for implementation
**Approved by**: [Pending human review]
