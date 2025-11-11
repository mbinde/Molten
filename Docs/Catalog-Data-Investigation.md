# Investigation: Removing Catalog Data from Core Data

**Date:** 2025-11-10
**Question:** Should we move catalog data (GlassItem, CoatingItem, ToolItem) from Core Data to an in-memory store?

---

## Executive Summary

**Recommendation: YES** - Moving catalog data out of Core Data is **feasible and beneficial**.

**Key Finding:** The codebase already uses patterns that make this migration straightforward:
- ✅ Zero Core Data relationships from catalog entities
- ✅ String-based lookups instead of managed object references
- ✅ Most queries fetch all items then filter in memory
- ✅ Simple predicates easily replaced by Swift native filtering

**Estimated effort:** 40-60 hours
**Risk level:** Medium (requires careful migration, but patterns already support it)
**Expected benefits:** Simpler architecture, faster startup, eliminates two-store complexity

---

## Investigation Results

### 1. Core Data Query Patterns

**Total NSFetchRequest usage on GlassItem:** 16 occurrences
- **Location:** ALL in `CoreDataGlassItemRepository.swift` (repository layer)
- **Views:** 0 direct Core Data usage in views ✅
- **Pattern:** Views → Services → Repositories → Core Data (clean separation)

**Most common query pattern:**
```swift
let allItems = try await glassItemRepository.fetchItems(matching: nil)  // Get ALL
// Then filter in memory in service layer
```

**Predicate patterns found:**
1. **ID lookups** (most common): `stable_id == %@`
2. **Simple equality**: `manufacturer == %@`, `coe == %d`, `mfr_status == %@`
3. **Text search**: `name CONTAINS[cd] %@` with compound OR predicates

**Complexity assessment:** LOW
- No joins or aggregations
- No complex relationships
- No Core Data-specific features like faulting or batch updates
- All predicates easily replaceable with Swift native filtering

### 2. Core Data Relationships

**GlassItem entity analysis:**
```xml
<entity name="GlassItem" parentEntity="Item">
    <attribute name="coe" attributeType="Integer 16"/>
    <attribute name="recommended_schedule_ids" attributeType="String"/>
    <!-- NO relationships! -->
</entity>
```

**Finding:** **ZERO Core Data relationships** ✅

**How Inventory references GlassItem:**
- Current: String-based `item_stable_id` and `item_natural_key` attributes
- NOT using Core Data relationships
- Already using the pattern needed for in-memory store!

**Other entities that reference catalog items:**
- `ItemTags` - references by `item_stable_id` (string)
- `ItemMinimum` - references by `item_stable_id` (string)
- `PurchaseRecordItem` - references by `catalog_code` (string)

**Assessment:** Migration-ready - all cross-references are already string-based!

### 3. Filtering and Searching Usage

**Service-level query patterns** (from `CatalogService.swift`):

```swift
// Pattern 1: Fetch all, filter in memory (MOST COMMON)
let allItems = try await glassItemRepository.fetchItems(matching: nil)
let filtered = allItems.filter { /* business logic */ }

// Pattern 2: Simple filter by manufacturer
let items = try await glassItemRepository.fetchItems(byManufacturer: "bullseye")

// Pattern 3: Search with text
let results = try await searchGlassItems(query: "clear", mode: .fullText)
```

**In-memory equivalent:**
```swift
// Pattern 1: Already in memory!
let filtered = catalogStore.allItems.filter { /* business logic */ }

// Pattern 2: Simple filter
let items = catalogStore.allItems.filter { $0.manufacturer == "bullseye" }

// Pattern 3: Text search
let results = catalogStore.allItems.filter {
    $0.name.localizedStandardContains(query)
}
```

**Performance comparison:**
- Core Data: Parse predicate → SQL query → Fetch from disk → Unmarshal objects
- In-memory: Direct array filter (Swift native, highly optimized)
- **Expected speedup:** 10-100x for typical queries

**Memory usage:**
- ~2,659 catalog items
- ~500 bytes per item average
- **Total:** ~1.3 MB in memory (negligible on modern iOS devices)

### 4. RepositoryFactory Usage in Views

**Total uses of `RepositoryFactory.create...()` in Views:** 141 occurrences

**Breakdown by service:**
```
CatalogService:                26 uses
KilnScheduleService:           15 uses
InventoryTrackingService:      14 uses
UserImageRepository:           13 uses
UnifiedLocationService:        12 uses
GlassItemRepository:            7 uses
ShoppingListService:            6 uses
SubscriptionService:            5 uses
... (15 more services)        43 uses
```

**Pattern in views:**
```swift
struct CatalogView: View {
    private let catalogService: CatalogService

    init(catalogService: CatalogService = RepositoryFactory.createCatalogService()) {
        self.catalogService = catalogService
    }
}
```

**Files affected by DI refactor:**
- Source files: ~60 view files
- Test files: ~100 test files
- **Total:** ~160 files need constructor changes

---

## Migration Path

### Phase 1: Create In-Memory Catalog Store (8-12 hours)

**New component:**
```swift
/// In-memory catalog store with fast lookups
actor CatalogStore {
    private var items: [String: GlassItemModel] = [:]  // Key: stable_id

    func loadFromJSON(data: Data) async throws
    func allItems() -> [GlassItemModel]
    func item(byStableId: String) -> GlassItemModel?
    func items(matching: (GlassItemModel) -> Bool) -> [GlassItemModel]
    func items(byManufacturer: String) -> [GlassItemModel]
    func search(query: String, fields: [KeyPath<GlassItemModel, String>]) -> [GlassItemModel]
}
```

**Benefits:**
- Simple dictionary lookup: O(1) for ID-based access
- Native Swift filtering: Fast, type-safe, compiler-optimized
- Concurrent access: Actor provides thread safety
- No Core Data overhead: No context management, no faulting

**Implementation steps:**
1. Create `CatalogStore` actor with dictionary storage
2. Add JSON loading (reuse existing `JSONDataLoader`)
3. Implement query methods matching current repository interface
4. Add unit tests for all query patterns

### Phase 2: Implement In-Memory Repository (4-6 hours)

**New component:**
```swift
/// In-memory implementation of GlassItemRepository
actor InMemoryGlassItemRepository: GlassItemRepository {
    private let store: CatalogStore

    // Implement all GlassItemRepository methods using store
    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        guard let predicate = predicate else {
            return store.allItems()
        }
        // Convert predicate to Swift filter (or just use nil = all items)
        return store.allItems()
    }

    func getItem(byStableId stableId: String) async throws -> GlassItemModel? {
        return store.item(byStableId: stableId)
    }

    // ... other methods
}
```

**Predicate conversion strategy:**
- **Option A (simple):** Only support `nil` predicate (fetch all), do filtering in service layer
- **Option B (complete):** Convert NSPredicate to Swift closures (more complex, may not be needed)
- **Recommendation:** Start with Option A - current code mostly uses `nil` anyway

### Phase 3: Update RepositoryFactory (2 hours)

**Change:**
```swift
// Before (Core Data)
static func createGlassItemRepository() -> GlassItemRepository {
    let context = getSharedController().localContext
    return CoreDataGlassItemRepository(context: context)
}

// After (In-memory)
static func createGlassItemRepository() -> GlassItemRepository {
    return InMemoryGlassItemRepository(store: CatalogStore.shared)
}
```

**Impact:**
- Single point of change in factory
- All services automatically use new repository
- No changes needed to service layer (abstraction works!)

### Phase 4: Remove Two-Store Architecture (8-12 hours)

**Cleanup tasks:**
1. Remove `localContext` from `PersistenceController`
2. Remove GlassItem, CoatingItem, ToolItem from Core Data model
3. Remove local store configuration
4. Update migration logic
5. Remove entity resolution validation for catalog entities
6. Update documentation

**Simplified `PersistenceController`:**
```swift
class PersistenceController {
    let container: NSPersistentCloudKitContainer  // Only ONE store!
    let context: NSManagedObjectContext            // Only ONE context!

    // No more localContext, no more store coordination
}
```

**Benefits:**
- 40% less Core Data complexity
- Faster initialization (no need to load catalog from disk)
- No more two-store workarounds
- Simpler mental model

### Phase 5: Testing & Validation (8-12 hours)

**Test coverage needed:**
1. Unit tests for `CatalogStore` (all query patterns)
2. Unit tests for `InMemoryGlassItemRepository`
3. Integration tests for catalog loading
4. Performance tests comparing old vs new
5. Migration tests (ensure existing apps upgrade smoothly)

**Validation checklist:**
- [ ] All catalog queries return correct results
- [ ] Search functionality works correctly
- [ ] JSON loading handles errors gracefully
- [ ] Memory usage is acceptable
- [ ] Performance meets or exceeds Core Data
- [ ] Existing user data unaffected

### Phase 6: Rollout Strategy (2-4 hours)

**Safe migration approach:**

1. **Version 1.0:** Both implementations coexist
   - Feature flag: `useInMemoryCatalog` (default: false)
   - A/B test with 10% of users
   - Monitor crash rates and performance

2. **Version 1.1:** Increase rollout
   - Enable for 50% of users
   - Monitor for one week

3. **Version 1.2:** Full rollout
   - Enable for 100% of users
   - Remove Core Data catalog code in next version

4. **Version 1.3:** Cleanup
   - Remove old Core Data implementation
   - Remove feature flag
   - Remove legacy migration code

---

## Cost-Benefit Analysis

### Costs

**Development time:** 40-60 hours
- Phase 1 (CatalogStore): 8-12 hours
- Phase 2 (Repository): 4-6 hours
- Phase 3 (Factory): 2 hours
- Phase 4 (Two-store removal): 8-12 hours
- Phase 5 (Testing): 8-12 hours
- Phase 6 (Rollout): 2-4 hours
- Buffer for unknowns: 8-12 hours

**Risk factors:**
- Edge cases in predicate conversion (LOW - mostly fetch all)
- Performance issues with large catalogs (LOW - 2,659 items is small)
- Migration bugs affecting existing users (MEDIUM - requires careful testing)
- JSON loading failures (LOW - already have this logic)

**Breaking changes:**
- Core Data model schema changes (requires migration)
- Testing changes (but tests already use mocks)
- Build configuration changes

### Benefits

**Immediate benefits:**
1. **Simpler architecture**
   - One Core Data store instead of two
   - No store coordination logic
   - Clearer separation: in-memory catalog vs persistent user data

2. **Better performance**
   - Faster app startup (no Core Data catalog load)
   - Faster queries (in-memory filtering vs SQL)
   - Lower memory overhead (no Core Data object graph)

3. **Easier development**
   - Add new catalog fields without Core Data migration
   - Test catalog logic without Core Data setup
   - Debug catalog issues more easily

4. **Reduced complexity**
   - No two-store workarounds
   - No entity resolution validation for catalog
   - Simpler `RepositoryFactory`

**Long-term benefits:**
1. **Over-the-air catalog updates**
   - Download new JSON, reload in-memory store
   - No Core Data migration needed
   - Instant catalog updates without app update

2. **Multiple catalog sources**
   - Easy to support: bundled JSON + downloaded JSON + custom items
   - Simple merge logic in memory
   - No schema conflicts

3. **Better testability**
   - Faster tests (no Core Data setup)
   - Easier mocking (just pass different CatalogStore)
   - Clearer test isolation

4. **Reduced CloudKit issues**
   - No risk of catalog duplication
   - Simpler CloudKit configuration
   - Fewer sync conflicts

---

## Recommendation

**YES - Proceed with migration**

**Rationale:**
1. **Feasibility:** High - code already uses patterns that support this
2. **Effort:** Moderate - 40-60 hours of focused work
3. **Risk:** Medium - requires careful testing, but architecture is ready
4. **ROI:** High - significant simplification and performance gains

**When to do it:**
- **Not during active feature development** (too many conflicts)
- **Between major releases** (allows time for testing)
- **When you have 2-3 weeks for implementation + monitoring**

**Suggested timeline:**
- Week 1: Phases 1-3 (implementation)
- Week 2: Phases 4-5 (cleanup + testing)
- Week 3: Phase 6 (rollout to 10%)
- Week 4: Monitor + increase to 50%
- Week 5: Monitor + increase to 100%
- Week 6: Cleanup old code

---

## Alternative: Keep Core Data

**If you decide NOT to migrate:**

**Pros:**
- No migration effort
- Known quantity (it works today)
- Core Data is mature and well-tested

**Cons:**
- Two-store architecture remains complex
- CloudKit duplication risk remains
- Slower performance vs in-memory
- Core Data migrations required for catalog changes

**When this makes sense:**
- You're about to ship and can't afford risk
- Catalog data will grow to 100,000+ items (needs indexing)
- You plan to add complex relational queries later
- Team doesn't have bandwidth for 2-3 week project

---

## Questions to Resolve Before Starting

1. **Catalog update strategy:** How often do you update the bundled JSON?
2. **Custom items:** Do users ever create their own catalog items?
3. **Catalog size:** Will you ever exceed 10,000 items?
4. **Search requirements:** Do you need full-text search with ranking?
5. **Backwards compatibility:** How far back do you support?

**Next steps:**
1. Review this document and decide: migrate now, migrate later, or never?
2. If migrating, schedule implementation time
3. If not migrating, document why and revisit in 6 months
