# Core Data Catalog Entities Deletion Plan

## Executive Summary

Delete Core Data entities (`GlassItem`, `ItemTags`, `Item`, `CoatingItem`, `ToolItem`) that are **only used in tests** but not in production. Production uses SQLite directly. Tests currently use Core Data, which is a **testing anti-pattern** because tests validate behavior that never runs in production.

**Problem**: Tests use Core Data repositories, production uses SQLite repositories → tests don't validate production code paths.

**Solution**: Delete Core Data entities and replace test infrastructure with either:
- **Option A**: SQLite-based tests (test real production code)
- **Option B**: Pure mock repositories (fast, isolated, no database)

---

## Current State Analysis

### Production Architecture
```
SQLite Database (catalog.sqlite - 3.8MB)
    ↓
SQLiteGlassItemRepository
    ↓
CatalogService → Views
```

**Used in production:**
- ✅ SQLite database (`catalog.sqlite`)
- ✅ `SQLiteGlassItemRepository`
- ✅ `SQLiteItemTagsRepository`

**NOT used in production:**
- ❌ Core Data `GlassItem` entity
- ❌ Core Data `ItemTags` entity
- ❌ Core Data `Item` entity (parent)
- ❌ `CoreDataGlassItemRepository`
- ❌ `CoreDataItemTagsRepository`

### Test Architecture (Current - ANTI-PATTERN)
```
Core Data (in-memory)
    ↓
CoreDataGlassItemRepository  ← Tests a fantasy implementation!
    ↓
CatalogService Tests
```

**Problem**: Tests validate Core Data queries that **never run in production**.

### AppDependencies.swift Logic
```swift
if self.mode == .mock {
    // TESTS ONLY - uses Core Data
    self.glassItemRepository = CoreDataGlassItemRepository(context: self.localContext)
    self.itemTagsRepository = CoreDataItemTagsRepository(context: self.localContext)
} else {
    // PRODUCTION - uses SQLite
    self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: .shared)
    self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: .shared)
}
```

---

## Entities to Delete

### From Core Data Model (`Molten 21.xcdatamodel`)

**In "Local" Configuration:**
1. **GlassItem** - Only used in tests
2. **ItemTags** - Only used in tests
3. **Item** (parent entity) - Only used in tests
4. **CoatingItem** - Check if used in production (AppDependencies.swift:174 uses Core Data!)
5. **ToolItem** - Check if used in production (AppDependencies.swift:175 uses Core Data!)

⚠️ **IMPORTANT**: Before deleting `CoatingItem` and `ToolItem`, verify they're not used in production!

---

## Files to Delete

### Repositories (Core Data implementations)
- `Molten/Sources/Repositories/Protocols/CoreDataGlassItemRepository.swift` (540 lines)
- `Molten/Sources/Repositories/CoreData/CoreDataItemTagsRepository.swift` (643 lines)

### Test Files Using Core Data
- `Molten/Tests/RepositoryTests/CoreData/CoreDataItemTagsRepositoryTests.swift`
- Any tests that use `CoreDataGlassItemRepository` directly

---

## Migration Strategy

### Phase 1: Create Test Infrastructure (Choose One Option)

#### Option A: SQLite-Based Tests (RECOMMENDED)
**Pros:**
- Tests validate **actual production code**
- No mocks to maintain
- Higher confidence in production behavior

**Cons:**
- Tests depend on SQLite database file
- Slightly slower than pure mocks (but still <50ms)

**Implementation:**
1. Create test fixture database in `~/molten-project/molten-data/`
2. Bundle `test_catalog.sqlite` with test target
3. Tests use `SQLiteGlassItemRepository` with test database

**How to create test data in SQLite:**

Edit `~/molten-project/molten-data/Scripts/build_catalog_database.py` to add test-specific data:

```python
def insert_test_data(conn):
    """Insert test-specific data (only for test database builds)."""
    cursor = conn.cursor()

    # Add known test items
    cursor.execute("""
        INSERT OR REPLACE INTO glass_items (
            stable_id, status, manufacturer, code, name, coe, type
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        'test01',  # Known stable_id for tests
        'active',
        'TestManufacturer',
        'TEST-001',
        'Test Glass Red',
        '96',
        'rod'
    ))

    # Add test tags
    cursor.execute("""
        INSERT OR IGNORE INTO item_tags (item_stable_id, tag)
        VALUES (?, ?)
    """, ('test01', 'test-tag'))

    conn.commit()
```

Then create a separate build script for test database:
```bash
#!/bin/bash
# ~/molten-project/molten-data/build_test_catalog.sh
python3 Scripts/build_catalog_database.py
# Move to test resources
mv Molten/Sources/Resources/catalog.sqlite Molten/Tests/Resources/test_catalog.sqlite
```

#### Option B: Pure Mock Repositories (ALTERNATIVE)
**Pros:**
- Fastest tests (<1ms)
- No database dependencies
- Complete control over test data

**Cons:**
- Doesn't test production code paths
- Mocks need maintenance
- Lower confidence (still better than Core Data tests though!)

**Implementation:**

```swift
// Molten/Tests/MoltenTests/Mocks/MockGlassItemRepository.swift

final class MockGlassItemRepository: GlassItemRepository {
    private var items: [String: GlassItemModel] = [:]

    // Pre-populate with test data
    init(testData: [GlassItemModel] = []) {
        for item in testData {
            items[item.stable_id] = item
        }
    }

    func fetchItems(matching predicate: NSPredicate?) async throws -> [GlassItemModel] {
        Array(items.values)
    }

    func fetchItem(byStableId stableId: String) async throws -> GlassItemModel? {
        items[stableId]
    }

    func createItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        items[item.stable_id] = item
        return item
    }

    func searchItems(text: String) async throws -> [GlassItemModel] {
        items.values.filter { item in
            item.name.localizedCaseInsensitiveContains(text) ||
            item.manufacturer.localizedCaseInsensitiveContains(text)
        }
    }

    func fetchItems(byManufacturer manufacturer: String) async throws -> [GlassItemModel] {
        items.values.filter { $0.manufacturer == manufacturer }
    }

    func fetchItems(byCOE coe: Int32) async throws -> [GlassItemModel] {
        items.values.filter { $0.coe == coe }
    }

    func fetchItems(byStatus status: String) async throws -> [GlassItemModel] {
        items.values.filter { $0.mfr_status == status }
    }

    func getDistinctManufacturers() async throws -> [String] {
        Array(Set(items.values.map { $0.manufacturer })).sorted()
    }

    func getDistinctCOEValues() async throws -> [Int32] {
        Array(Set(items.values.map { $0.coe })).sorted()
    }

    func getDistinctStatuses() async throws -> [String] {
        Array(Set(items.values.map { $0.mfr_status })).sorted()
    }

    // Write operations (throw errors since SQLite is read-only in production)
    func updateItem(_ item: GlassItemModel) async throws -> GlassItemModel {
        throw SQLiteError.writeOperationNotSupported("Mock repository is read-only")
    }

    func deleteItem(byStableId stableId: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Mock repository is read-only")
    }
}
```

```swift
// Molten/Tests/MoltenTests/Mocks/MockItemTagsRepository.swift

final class MockItemTagsRepository: ItemTagsRepository {
    private var tagsByItem: [String: Set<String>] = [:]
    private var allTags: Set<String> = []

    init(testData: [String: [String]] = [:]) {
        for (itemId, tags) in testData {
            tagsByItem[itemId] = Set(tags)
            allTags.formUnion(tags)
        }
    }

    func fetchTags(forItem item_stable_id: String) async throws -> [String] {
        Array(tagsByItem[item_stable_id] ?? []).sorted()
    }

    func fetchTagsForItems(_ item_stable_ids: [String]) async throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for itemId in item_stable_ids {
            if let tags = tagsByItem[itemId] {
                result[itemId] = Array(tags).sorted()
            }
        }
        return result
    }

    func getAllTags() async throws -> [String] {
        Array(allTags).sorted()
    }

    func getTagsWithPrefix(_ prefix: String) async throws -> [String] {
        allTags.filter { $0.hasPrefix(prefix.lowercased()) }.sorted()
    }

    func getMostUsedTags(limit: Int) async throws -> [String] {
        // Simple implementation - just return first N tags
        Array(allTags.sorted().prefix(limit))
    }

    func fetchItems(withTag tag: String) async throws -> [String] {
        tagsByItem.filter { $0.value.contains(tag) }.map { $0.key }.sorted()
    }

    func fetchItems(withAllTags tags: [String]) async throws -> [String] {
        let tagsSet = Set(tags)
        return tagsByItem.filter { tagsSet.isSubset(of: $0.value) }.map { $0.key }.sorted()
    }

    func fetchItems(withAnyTags tags: [String]) async throws -> [String] {
        let tagsSet = Set(tags)
        return tagsByItem.filter { !$0.value.isDisjoint(with: tagsSet) }.map { $0.key }.sorted()
    }

    func getTagUsageCounts() async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        for tags in tagsByItem.values {
            for tag in tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    func getTagsWithCounts(minCount: Int) async throws -> [(tag: String, count: Int)] {
        let counts = try await getTagUsageCounts()
        return counts
            .filter { $0.value >= minCount }
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    func tagExists(_ tag: String) async throws -> Bool {
        allTags.contains(tag)
    }

    func getTags(withPrefix prefix: String) async throws -> [String] {
        try await getTagsWithPrefix(prefix)
    }

    // Write operations (read-only in production)
    func addTag(_ tag: String, toItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Mock repository is read-only")
    }

    func addTags(_ tags: [String], toItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Mock repository is read-only")
    }

    func removeTag(_ tag: String, fromItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Mock repository is read-only")
    }

    func setTags(_ tags: [String], forItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Mock repository is read-only")
    }

    func removeAllTags(fromItem item_stable_id: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Mock repository is read-only")
    }

    func deleteTag(_ tag: String) async throws {
        throw SQLiteError.writeOperationNotSupported("Mock repository is read-only")
    }
}
```

**Test Data Builder:**
```swift
// Molten/Tests/MoltenTests/Utilities/TestCatalogData.swift

enum TestCatalogData {
    static let bullseyeRed = GlassItemModel(
        stable_id: "be001",
        name: "Red",
        sku: "001",
        manufacturer: "BE",
        coe: 90,
        mfr_status: "active"
    )

    static let bullseyeBlue = GlassItemModel(
        stable_id: "be100",
        name: "Blue",
        sku: "100",
        manufacturer: "BE",
        coe: 90,
        mfr_status: "active"
    )

    static let standardGlassItems = [bullseyeRed, bullseyeBlue]

    static let standardTags: [String: [String]] = [
        "be001": ["red", "transparent", "popular"],
        "be100": ["blue", "transparent"]
    ]

    static func createMockGlassRepo() -> MockGlassItemRepository {
        MockGlassItemRepository(testData: standardGlassItems)
    }

    static func createMockTagsRepo() -> MockItemTagsRepository {
        MockItemTagsRepository(testData: standardTags)
    }
}
```

---

### Phase 2: Update AppDependencies

**Current code** (AppDependencies.swift:167-173):
```swift
if self.mode == .mock {
    self.glassItemRepository = CoreDataGlassItemRepository(context: self.localContext)
    self.itemTagsRepository = CoreDataItemTagsRepository(context: self.localContext)
} else {
    self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: .shared)
    self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: .shared)
}
```

**Option A - SQLite Tests** (use test database):
```swift
if self.mode == .mock {
    // Tests use SQLite with test database
    let testDbManager = CatalogDatabaseManager(databasePath: Bundle.test.path(forResource: "test_catalog", ofType: "sqlite")!)
    self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: testDbManager)
    self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: testDbManager)
} else {
    // Production uses bundled SQLite
    self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: .shared)
    self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: .shared)
}
```

**Option B - Mock Tests**:
```swift
if self.mode == .mock {
    // Tests use in-memory mocks
    self.glassItemRepository = TestCatalogData.createMockGlassRepo()
    self.itemTagsRepository = TestCatalogData.createMockTagsRepo()
} else {
    // Production uses bundled SQLite
    self.glassItemRepository = SQLiteGlassItemRepository(databaseManager: .shared)
    self.itemTagsRepository = SQLiteItemTagsRepository(databaseManager: .shared)
}
```

---

### Phase 3: Update Tests

**Find all tests using Core Data repositories:**
```bash
grep -r "CoreDataGlassItemRepository\|CoreDataItemTagsRepository" Molten/Tests --include="*.swift"
```

**For each test:**
1. Remove Core Data repository instantiation
2. Use `AppDependencies(forTesting: true)` which will automatically use new test infrastructure
3. Verify test data expectations match new mock/test database

**Example test update:**

**Before (Core Data - WRONG):**
```swift
@Test func testFetchGlassItem() async throws {
    let context = persistentContainer.viewContext
    let repo = CoreDataGlassItemRepository(context: context)

    // Create test item in Core Data
    let item = GlassItemModel(stable_id: "test", name: "Test", ...)
    _ = try await repo.createItem(item)

    // Fetch and verify
    let fetched = try await repo.fetchItem(byStableId: "test")
    #expect(fetched != nil)
}
```

**After (Mock - CORRECT):**
```swift
@Test func testFetchGlassItem() async throws {
    let deps = AppDependencies(forTesting: true)
    let repo = deps.glassItemRepository

    // Test data already in mock/test database
    let fetched = try await repo.fetchItem(byStableId: TestCatalogData.bullseyeRed.stable_id)
    #expect(fetched?.name == "Red")
}
```

---

### Phase 4: Delete Core Data Entities

⚠️ **CRITICAL**: Do this LAST, after all tests are passing with new infrastructure.

1. Open `Molten.xcdatamodeld/Molten 21.xcdatamodel` in Xcode
2. Create new model version: Editor → Add Model Version → "Molten 22"
3. In Molten 22, delete entities:
   - `GlassItem`
   - `ItemTags`
   - `Item` (only if not needed by CoatingItem/ToolItem)
4. Update `.xccurrentversion` to point to Molten 22
5. Clean build folder
6. Build and test

---

### Phase 5: Cleanup References

**Remove from Persistence.swift:**
- Any GlassItem/ItemTags validation logic
- Preview data creation for these entities

**Remove from CoreDataEntities.swift:**
- Entity class declarations

**Update CLAUDE.md:**
- Remove references to Core Data catalog entities
- Update two-store architecture explanation

---

## Testing Strategy

### Before Deletion
1. Run full test suite: `xcodebuild test -scheme Molten -testPlan UnitTestsOnly`
2. Document any failures (baseline)

### After Mock/Test DB Implementation
1. Run full test suite again
2. All previous passes should still pass
3. Fix any new failures (likely test data mismatches)

### After Core Data Entity Deletion
1. Clean build folder
2. Build project (should succeed)
3. Run full test suite (should pass)
4. Manually test catalog view in app

---

## Rollback Plan

If deletion causes issues:

1. **Keep deleted files in git history**:
   ```bash
   git checkout HEAD~1 -- path/to/deleted/file.swift
   ```

2. **Revert Core Data model**:
   - Delete Molten 22.xcdatamodel
   - Reset .xccurrentversion to Molten 21

3. **Revert AppDependencies.swift**

---

## Estimated Effort

**Option A (SQLite Tests):**
- Create test database build script: 2 hours
- Update AppDependencies: 30 min
- Update tests: 2-3 hours (depending on test count)
- Delete entities and cleanup: 1 hour
- **Total: ~6 hours**

**Option B (Mock Repos):**
- Implement mock repositories: 3-4 hours
- Update AppDependencies: 30 min
- Update tests: 2-3 hours
- Delete entities and cleanup: 1 hour
- **Total: ~7-8 hours**

---

## Recommendation

**Use Option A (SQLite-based tests)** because:
1. Tests validate **actual production code**
2. Higher confidence in production behavior
3. Less code to maintain (no mock implementations)
4. Test data lives in molten-data repo (single source of truth)

**When to use Option B:**
- Need faster test execution (<1ms vs ~10ms)
- Want complete isolation from database files
- Tests need complex scenarios not in production data

---

## Questions Before Starting

1. **Do we need CoatingItem/ToolItem entities?**
   - Check: Are coatings/tools actually used in production?
   - AppDependencies.swift:174-175 uses Core Data for these!
   - May need to migrate these to SQLite first

2. **Which test option?**
   - SQLite tests (test production code) or Mocks (faster, isolated)?

3. **Test data requirements?**
   - What scenarios must tests cover?
   - Do we need test-specific items not in production catalog?

---

## Success Criteria

✅ All tests pass with new infrastructure
✅ Zero Core Data entities for catalog in production model
✅ Tests validate production code paths (if using SQLite option)
✅ AppDependencies.swift simplified
✅ CLAUDE.md updated
✅ Catalog view works in app
✅ Build succeeds without errors
