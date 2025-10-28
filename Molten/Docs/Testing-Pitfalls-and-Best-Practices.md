# Testing Pitfalls and Best Practices

This document captures hard-learned lessons from debugging test failures in the Molten project. These patterns took hours to discover and debug, so we're documenting them here to save future time.

---

## 🚨 CRITICAL: Mock Naming Collisions

### The Problem

**Symptom**: You edit a mock implementation in `Sources/Repositories/Mock/`, but tests don't reflect your changes. Debug prints don't appear. Tests fail in ways that suggest your code isn't running.

**Root Cause**: Swift's type resolution picks `class` over `actor` when both types have the same name in scope.

**Example of the bug**:
```swift
// Sources/Repositories/Mock/MockLogbookRepository.swift
actor MockLogbookRepository: LogbookRepository {
    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        print("🔍 Using REAL implementation")  // ← This never prints!
        // ... your implementation
    }
}

// Tests/MoltenTests/Views/LogbookViewModelTests.swift
final class MockLogbookRepository: LogbookRepository {  // ← Swift picks THIS one!
    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        // ... old/broken implementation
    }
}
```

**Result**: All edits to the `actor` version are silently ignored. Tests use the `class` version.

### The Fix

**✅ RULE: Never reuse mock class names across files**

Use suffixed names to indicate the mock's purpose:

```swift
// Production mock (in Sources/Repositories/Mock/)
actor MockLogbookRepository: LogbookRepository { }

// Test-specific mock (in Tests/)
final class MockLogbookRepositoryForViewModel: LogbookRepository { }
final class MockLogbookRepositoryForIntegration: LogbookRepository { }
```

### Debugging Name Collisions

If you suspect a name collision:

1. **Add debug prints** to verify which implementation is running:
```swift
func someMethod() async throws -> Result {
    print("🔍 Using REAL MockFoo implementation")
    // ... rest of implementation
}
```

2. **Search for duplicate names**:
```bash
grep -r "class MockLogbookRepository\|actor MockLogbookRepository" Tests/ Sources/
```

3. **Check import scope** - Make sure test files aren't importing both versions:
```swift
@testable import Molten  // ← Imports Sources/Repositories/Mock/
// + inline mock in same file → COLLISION!
```

4. **Verify behavior change** - Make an intentional breaking change (like `fatalError()`) to confirm which version is running.

---

## 🗄️ Singleton Cache Pollution

### The Problem

**Symptom**: Tests crash with force unwrap failures like `completeItems.first!`. Tests pass individually but fail when run together. Tests show stale data from previous tests.

**Root Cause**: `CatalogDataCache.shared` is a singleton that persists between tests. If Test A loads data into the cache, Test B sees that data instead of its own test data.

**Example of the bug**:
```swift
@Test("Should load inventory items")
func testLoadItems() async throws {
    let builder = try await TestDataBuilder()
        .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear")
        .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0)
        .build()

    let viewModel = InventoryViewModel(
        inventoryTrackingService: builder.inventoryTrackingService,
        catalogService: builder.catalogService
    )

    await viewModel.loadInventoryItems()

    // ❌ CRASH: completeItems is empty because cache has stale data from previous test!
    let item = viewModel.completeItems.first!
}
```

### The Fix

**✅ PATTERN: Reload cache after TestDataBuilder.build()**

```swift
@Suite("InventoryViewModel Tests", .serialized)  // ← Add .serialized
struct InventoryViewModelTests {

    @Test("Should load inventory items")
    func testLoadItems() async throws {
        let builder = try await TestDataBuilder()
            .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear")
            .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0)
            .build()

        // ✅ Force reload cache with test data
        await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

        let viewModel = InventoryViewModel(
            inventoryTrackingService: builder.inventoryTrackingService,
            catalogService: builder.catalogService
        )

        await viewModel.loadInventoryItems()

        // ✅ Now completeItems has the correct test data
        let item = viewModel.completeItems.first!
    }
}
```

**✅ PATTERN: Reload cache after mutations**

If your test adds/deletes/updates data, reload the cache before making assertions:

```swift
@Test("Should delete inventory item")
func testDeleteItem() async throws {
    // Arrange
    let builder = try await TestDataBuilder()
        .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear")
        .withInventory(manufacturer: "bullseye", sku: "001", quantity: 10.0)
        .build()

    await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

    let viewModel = InventoryViewModel(
        inventoryTrackingService: builder.inventoryTrackingService,
        catalogService: builder.catalogService
    )

    await viewModel.loadInventoryItems()
    let inventoryId = viewModel.completeItems.first!.inventory.first!.id

    // Act
    await viewModel.deleteInventory(id: inventoryId)

    // ✅ Reload cache BEFORE assertions to get fresh data
    await CatalogDataCache.shared.reload(catalogService: builder.catalogService)
    await viewModel.loadInventoryItems()

    // Assert
    let updatedItem = viewModel.completeItems.first {
        $0.glassItem.stable_id == "bullseye-001-0"
    }
    #expect(updatedItem?.inventory.isEmpty == true)
}
```

### Why .serialized?

The `.serialized` attribute prevents tests from running in parallel:

```swift
@Suite("InventoryViewModel Tests", .serialized)
struct InventoryViewModelTests {
    // Tests run one at a time, preventing cache race conditions
}
```

**Without .serialized**: Tests run in parallel → both try to reload cache simultaneously → race condition → flaky tests.

---

## 📅 Default Parameter Traps

### The Problem

**Symptom**: Tests create "old" data but queries return it as "recent". Date range filters don't work as expected.

**Root Cause**: Model initializers have `Date = Date()` default parameters. When tests don't explicitly set these dates, they default to NOW instead of the test scenario's historical date.

**Example of the bug**:
```swift
@Test("Date range should exclude old logs")
func testOldLogsExcluded() async throws {
    let oldDate = Date().addingTimeInterval(-3600 * 24 * 30) // 30 days ago

    let log = LogbookModel(
        title: "Old Log",
        startDate: oldDate,          // ← Set to 30 days ago
        completionDate: oldDate,     // ← Set to 30 days ago
        // dateCreated defaults to NOW! ← BUG
        status: .completed
    )

    _ = try await repository.createLog(log)

    // Query for recent dates (last 7 days)
    let results = try await repository.getLogsByDateRange(
        start: Date().addingTimeInterval(-3600 * 24 * 7),
        end: Date()
    )

    // ❌ FAILS: results contains the log because dateCreated = NOW!
    #expect(results.isEmpty)
}
```

### The Fix

**✅ RULE: Explicitly set all date fields in test data**

```swift
@Test("Date range should exclude old logs")
func testOldLogsExcluded() async throws {
    let oldDate = Date().addingTimeInterval(-3600 * 24 * 30) // 30 days ago

    let log = LogbookModel(
        title: "Old Log",
        dateCreated: oldDate,        // ✅ Explicitly set
        dateModified: oldDate,       // ✅ Explicitly set
        startDate: oldDate,
        completionDate: oldDate,
        status: .completed
    )

    _ = try await repository.createLog(log)

    // Query for recent dates
    let results = try await repository.getLogsByDateRange(
        start: Date().addingTimeInterval(-3600 * 24 * 7),
        end: Date()
    )

    // ✅ PASSES: log is correctly excluded
    #expect(results.isEmpty)
}
```

**When to apply this**:
- Any test involving date comparisons
- Any test creating historical data
- Any test with date range queries
- Any test with sorting by date

---

## 🔄 TestDataBuilder Missing Data

### The Problem

**Symptom**: Tests expect data but get empty results. ShoppingListViewModel tests fail because no items appear in the shopping list.

**Root Cause**: `TestDataBuilder` has incomplete implementation - it collects data but doesn't actually persist it.

**Example of the bug**:
```swift
// TestDataBuilder.swift (BROKEN)
func build() async throws -> TestDataBuilder {
    // ... create items, inventory

    // Set minimums
    // TODO: Fix API mismatch - MockItemMinimumRepository doesn't have setMinimum
    // for (stableId, minimum) in itemMinimums {
    //     try await itemMinimumRepo.setMinimum(minimum, forItem: stableId)
    // }

    // ❌ Minimums never get set!

    return self
}
```

**Result**: ShoppingListViewModel queries for items below minimum but finds nothing because minimums were never set.

### The Fix

**✅ RULE: Verify TestDataBuilder.build() persists all configured data**

Before using a scenario, verify it's fully implemented:

```swift
// TestDataBuilder.swift (FIXED)
func build() async throws -> TestDataBuilder {
    // Create glass items
    if !glassItems.isEmpty {
        _ = try await glassItemRepo.createItems(glassItems)
    }

    // Create inventory
    for item in inventoryItems {
        _ = try await inventoryRepo.createInventory(item)
    }

    // ✅ Set minimums (was commented out)
    for (stableId, minimumQty) in itemMinimums {
        _ = try await itemMinimumRepo.setMinimumQuantity(
            minimumQty,
            forItem: stableId,
            type: "rod",
            store: "Test Store"
        )
    }

    // Assign tags
    for (itemKey, tags) in tagAssignments {
        for tag in tags {
            try await itemTagsRepo.addTag(tag, toItem: itemKey)
        }
    }

    return self
}
```

**Debugging checklist**:
1. Check if `TestDataBuilder` has a TODO comment for your scenario
2. Add debug prints to verify data is actually persisted:
```swift
print("📊 Created \(glassItems.count) glass items")
print("📦 Created \(inventoryItems.count) inventory records")
print("⚡️ Set \(itemMinimums.count) minimums")
```
3. Query the repository directly to confirm data exists:
```swift
let allItems = try await builder.repositories.glassItem.getAllItems()
print("🔍 Total items in repo: \(allItems.count)")
```

---

## 🎯 Using Production Mocks vs Inline Mocks

### The Problem

**Symptom**: Tests fail because mock methods are stubs that do nothing. Delete operations silently fail.

**Root Cause**: Tests define inline mocks that only implement the minimum to compile, not full functionality.

**Example of the bug**:
```swift
// Tests/MoltenTests/Views/PurchasesViewModelTests.swift (BROKEN)
final class MockPurchaseRecordRepository: PurchaseRecordRepository {
    private var records: [PurchaseRecordModel] = [/* static data */]

    func getAllRecords() async throws -> [PurchaseRecordModel] {
        return records
    }

    func deleteRecord(id: UUID) async throws {
        // ❌ STUB: Does nothing!
    }
}

@Test("Should delete purchases")
func testDeletePurchases() async throws {
    let mockRepo = MockPurchaseRecordRepository()
    let viewModel = PurchasesViewModel(purchaseService: PurchaseRecordService(repository: mockRepo))

    await viewModel.deletePurchases(ids: [id1, id2])

    // ❌ FAILS: viewModel.purchases.count is still 3 (delete did nothing)
    #expect(viewModel.purchases.count == 1)
}
```

### The Fix

**✅ RULE: Use production mocks from Sources/Repositories/Mock/**

These mocks have full CRUD implementations and are well-tested:

```swift
// Tests/MoltenTests/Views/PurchasesViewModelTests.swift (FIXED)
@Test("Should delete purchases")
func testDeletePurchases() async throws {
    // ✅ Use the real mock from Sources/
    let mockRepo = MockPurchaseRecordRepository()

    // Pre-populate with test data
    _ = try await mockRepo.createRecord(PurchaseRecordModel(
        id: id1,
        supplier: "Frantz Art Glass",
        dateAdded: Date(),
        subtotal: 150.00
    ))
    _ = try await mockRepo.createRecord(PurchaseRecordModel(
        id: id2,
        supplier: "Sundance Art Glass",
        dateAdded: Date(),
        subtotal: 250.00
    ))

    let service = PurchaseRecordService(repository: mockRepo)
    let viewModel = PurchasesViewModel(purchaseService: service)

    await viewModel.loadPurchases()
    await viewModel.deletePurchases(ids: [id1, id2])

    // ✅ PASSES: delete actually works
    #expect(viewModel.purchases.isEmpty)
}
```

**When to use inline mocks**:
- ❌ Never for full CRUD operations
- ❌ Never when you need actual persistence
- ✅ Only for testing error conditions (throw specific errors)
- ✅ Only for testing specific edge cases

**Example of acceptable inline mock**:
```swift
// Testing error handling - inline mock is fine
actor ThrowingMockRepository: LogbookRepository {
    func getAllLogs() async throws -> [LogbookModel] {
        throw TestError.networkFailure  // ✅ Specific error for test
    }

    // ... other methods
}
```

---

## 🔍 Debugging Checklist

When tests fail unexpectedly, work through this checklist:

### 1. Is the right mock being used?
```swift
// Add debug print to verify
func someMethod() async throws -> Result {
    print("🔍 Using [ClassName] implementation")
    // ... rest of implementation
}
```

### 2. Is test data actually persisted?
```swift
let builder = try await TestDataBuilder()
    .withGlassItem(...)
    .withInventory(...)
    .build()

// Verify data exists
let allItems = try await builder.repositories.glassItem.getAllItems()
print("📊 Items in repo: \(allItems.count)")
```

### 3. Is the cache stale?
```swift
// After builder.build()
await CatalogDataCache.shared.reload(catalogService: builder.catalogService)

// After mutations
await viewModel.deleteItem(id: id)
await CatalogDataCache.shared.reload(catalogService: builder.catalogService)
```

### 4. Are default date parameters causing issues?
```swift
// Explicitly set ALL date fields
let log = LogbookModel(
    title: "Test",
    dateCreated: testDate,    // ← Don't rely on defaults
    dateModified: testDate,   // ← Don't rely on defaults
    startDate: testDate,
    completionDate: testDate
)
```

### 5. Does the mock have the feature you're testing?
```swift
// Check the mock implementation
grep -A 20 "func deleteRecord" Sources/Repositories/Mock/MockPurchaseRecordRepository.swift

// If it's a stub, use the production mock instead
```

### 6. Are there duplicate type names?
```bash
# Search for duplicate class/actor names
grep -r "class MockLogbookRepository\|actor MockLogbookRepository" Tests/ Sources/

# If found, rename test version with suffix
final class MockLogbookRepositoryForViewModel: LogbookRepository { }
```

---

## 📋 Testing Best Practices Summary

### DO ✅

- **Use `.serialized`** for test suites that use `CatalogDataCache`
- **Reload cache** after `TestDataBuilder.build()` and after mutations
- **Use production mocks** from `Sources/Repositories/Mock/`
- **Explicitly set all date fields** in test data
- **Use suffixed names** for test-specific mocks (`MockXXXForViewModel`)
- **Add debug prints** when mocks aren't behaving as expected
- **Verify TestDataBuilder** actually persists configured data

### DON'T ❌

- **Reuse mock class names** across test files and production code
- **Create inline mocks** for full CRUD operations
- **Rely on default date parameters** in models
- **Forget to reload cache** after mutations
- **Assume tests are isolated** without `.serialized` when using singletons

### When Debugging Tests

1. Add debug prints to verify which implementation is running
2. Check for name collisions with `grep`
3. Verify test data is actually persisted
4. Check if cache needs reloading
5. Verify all date fields are explicitly set
6. Confirm mock implements the method you're testing

---

## 📚 Related Documentation

- `CLAUDE.md` - Full testing guidelines and TDD workflow
- `ViewModel-Protocol-Pattern.md` - ViewModel testability patterns
- `Swift6-Concurrency-Guide.md` - Concurrency and actor patterns
- `SwiftUI-View-Lifecycle-Guide.md` - View lifecycle and service creation

---

**Last Updated**: October 2025
**Lessons Learned From**: 4+ hour debugging session fixing 35+ failing test suites
**Key Discovery**: Name collision between `actor MockLogbookRepository` and `class MockLogbookRepository`
