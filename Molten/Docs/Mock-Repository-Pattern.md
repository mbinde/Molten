# Mock Repository Pattern for Swift 6

**Purpose**: Create in-memory mock implementations of repository protocols for unit testing, fully compliant with Swift 6 strict concurrency.

**Problem Solved**: Avoid spending hours fixing actor isolation errors in mock repositories by following this pattern from the start.

---

## The Pattern

### 1. Class Declaration

```swift
@MainActor
final class MockXRepository: XRepository {
```

**Rules**:
- `@MainActor` annotation (repositories are main-actor isolated)
- `final class` (not struct, mocks are reference types)
- Conform to the repository protocol

### 2. Storage Declaration

```swift
nonisolated(unsafe) private var items: [Key: Value] = [:]
```

**Rules**:
- Use `nonisolated(unsafe)` to allow synchronous access to storage
- `private var` for encapsulation
- Dictionary storage: `[Key: Model]` where Key is typically UUID or String (stable_id)
- Initialize as empty `[:]`

**Common storage patterns**:
```swift
// UUID key for entities with id property
nonisolated(unsafe) private var schedules: [UUID: KilnSchedule] = [:]

// String key for stable_id lookups
nonisolated(unsafe) private var items: [String: GlassItemModel] = [:]
```

### 3. CRUD Method Implementation

**Key Rule**: Use `await` when accessing actor-isolated properties from stored models.

#### Fetch Operations

```swift
func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemModel] {
    // Ignore predicate filtering in mocks (simplicity)
    return Array(items.values)
}

func fetchItem(byId id: UUID) async throws -> ItemModel? {
    return items[id]
}
```

**Pattern**: Simple dictionary lookups, return arrays or optionals.

#### Create Operations

```swift
func createItem(_ item: ItemModel) async throws -> ItemModel {
    let id = await item.id  // ← Use await for actor-isolated properties
    items[id] = item
    return item
}

func createItems(_ items: [ItemModel]) async throws -> [ItemModel] {
    for item in items {
        let id = await item.id  // ← Use await in loops
        self.items[id] = item
    }
    return items
}
```

**Pattern**: Extract key using `await`, store in dictionary, return model.

#### Update Operations

```swift
func updateItem(_ item: ItemModel) async throws -> ItemModel {
    let id = await item.id
    guard items[id] != nil else {
        throw NSError(domain: "MockItemRepository", code: 404)
    }
    items[id] = item
    return item
}
```

**Pattern**: Extract key, guard existence, update, return.

#### Delete Operations

```swift
func deleteItem(id: UUID) async throws {
    items.removeValue(forKey: id)
}

func deleteItems(ids: [UUID]) async throws {
    for id in ids {
        items.removeValue(forKey: id)
    }
}
```

**Pattern**: Simple `removeValue(forKey:)` calls.

### 4. Business Query Operations

**Key Rule**: When filtering by model properties, extract properties using `await` in loops.

```swift
func fetchItems(byCategory category: String) async throws -> [ItemModel] {
    var filtered: [ItemModel] = []

    for item in items.values {
        let itemCategory = await item.category  // ← Extract property
        if itemCategory == category {
            filtered.append(item)
        }
    }

    return filtered
}
```

**Pattern**: Loop through values, extract actor-isolated properties, filter, return array.

#### Sorting with Actor-Isolated Properties

```swift
func getItemsSortedByName() async throws -> [ItemModel] {
    let itemsArray = Array(items.values)

    // Extract names and pair with items for sorting
    var itemsWithNames: [(item: ItemModel, name: String)] = []
    for item in itemsArray {
        let name = await item.name  // ← Extract property
        itemsWithNames.append((item, name))
    }

    // Sort by name
    itemsWithNames.sort { $0.name < $1.name }

    return itemsWithNames.map { $0.item }
}
```

**Pattern**: Extract properties, create tuples, sort tuples, map back to models.

#### Distinct Values

```swift
func getDistinctCategories() async throws -> [String] {
    let itemsArray = Array(items.values)
    var categories: Set<String> = []
    for item in itemsArray {
        let category = await item.category  // ← Extract property
        categories.insert(category)
    }
    return categories.sorted()
}
```

**Pattern**: Loop, extract property, insert into Set, return sorted array.

### 5. Complex Operations

For operations that combine multiple queries:

```swift
func moveQuantity(
    _ quantity: Double,
    fromLocation: String,
    toLocation: String,
    forInventory inventory_id: UUID
) async throws {
    // Call other repository methods
    _ = try await subtractQuantity(quantity, fromLocation: fromLocation, forInventory: inventory_id)
    _ = try await addQuantity(quantity, toLocation: toLocation, forInventory: inventory_id)
}
```

**Pattern**: Compose existing repository methods, don't duplicate logic.

### 6. Test Helpers

Always include test helpers at the bottom:

```swift
// MARK: - Test Helpers

/// Populate repository with sample test data
func populateWithTestData() async throws {
    let testItems = [
        ItemModel(id: UUID(), name: "Item 1", category: "A"),
        ItemModel(id: UUID(), name: "Item 2", category: "B"),
        ItemModel(id: UUID(), name: "Item 3", category: "A")
    ]
    _ = try await createItems(testItems)
}

/// Get count of stored items (test helper)
func getItemCount() async -> Int {
    return items.count
}

/// Clear all items (test helper)
func clearAll() async {
    items.removeAll()
}

/// Clear all data (test helper, alias for clearAll for consistency)
nonisolated func clearAllData() {
    items.removeAll()
}
```

**Pattern**: Provide `populateWithTestData()`, `getItemCount()`, `clearAll()`, and `clearAllData()`.

---

## Common Pitfalls and Solutions

### ❌ Pitfall 1: Forgetting `await` for actor-isolated properties

```swift
// WRONG - Compiler error
func createItem(_ item: ItemModel) async throws -> ItemModel {
    let id = item.id  // ❌ Error: main actor-isolated property
    items[id] = item
    return item
}
```

```swift
// CORRECT
func createItem(_ item: ItemModel) async throws -> ItemModel {
    let id = await item.id  // ✅ Use await
    items[id] = item
    return item
}
```

### ❌ Pitfall 2: Sorting without extracting properties first

```swift
// WRONG - Compiler error
func getSortedItems() async throws -> [ItemModel] {
    return items.values.sorted { await $0.name < await $1.name }
    // ❌ Error: async closure in synchronous context
}
```

```swift
// CORRECT - Extract properties, then sort
func getSortedItems() async throws -> [ItemModel] {
    let itemsArray = Array(items.values)
    var itemsWithNames: [(item: ItemModel, name: String)] = []
    for item in itemsArray {
        let name = await item.name
        itemsWithNames.append((item, name))
    }
    itemsWithNames.sort { $0.name < $1.name }
    return itemsWithNames.map { $0.item }
}
```

### ❌ Pitfall 3: Missing `@MainActor` annotation

```swift
// WRONG - Causes actor isolation errors
final class MockItemRepository: ItemRepository {
    // ❌ Missing @MainActor
```

```swift
// CORRECT
@MainActor
final class MockItemRepository: ItemRepository {
    // ✅ Properly isolated
```

### ❌ Pitfall 4: Using regular `private var` instead of `nonisolated(unsafe)`

```swift
// WRONG - Causes isolation errors
@MainActor
final class MockItemRepository: ItemRepository {
    private var items: [UUID: ItemModel] = [:]
    // ❌ Will cause actor isolation errors
```

```swift
// CORRECT
@MainActor
final class MockItemRepository: ItemRepository {
    nonisolated(unsafe) private var items: [UUID: ItemModel] = [:]
    // ✅ Allows synchronous access
```

---

## Complete Example Template

```swift
//
//  MockXRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of XRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of XRepository for testing
/// Stores items in memory using a dictionary
@MainActor
final class MockXRepository: XRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var items: [UUID: ItemModel] = [:] // Key: id

    // MARK: - CRUD Operations

    func fetchItems(matching predicate: NSPredicate?) async throws -> [ItemModel] {
        // For simplicity, ignore predicate filtering in mock
        return Array(items.values)
    }

    func fetchItem(byId id: UUID) async throws -> ItemModel? {
        return items[id]
    }

    func createItem(_ item: ItemModel) async throws -> ItemModel {
        let id = await item.id
        items[id] = item
        return item
    }

    func createItems(_ items: [ItemModel]) async throws -> [ItemModel] {
        for item in items {
            let id = await item.id
            self.items[id] = item
        }
        return items
    }

    func updateItem(_ item: ItemModel) async throws -> ItemModel {
        let id = await item.id
        guard items[id] != nil else {
            throw NSError(domain: "MockXRepository", code: 404)
        }
        items[id] = item
        return item
    }

    func deleteItem(id: UUID) async throws {
        items.removeValue(forKey: id)
    }

    // MARK: - Business Query Operations

    func fetchItems(byCategory category: String) async throws -> [ItemModel] {
        var filtered: [ItemModel] = []

        for item in items.values {
            let itemCategory = await item.category
            if itemCategory == category {
                filtered.append(item)
            }
        }

        return filtered
    }

    func getDistinctCategories() async throws -> [String] {
        let itemsArray = Array(items.values)
        var categories: Set<String> = []
        for item in itemsArray {
            let category = await item.category
            categories.insert(category)
        }
        return categories.sorted()
    }

    // MARK: - Test Helpers

    /// Populate repository with sample test data
    func populateWithTestData() async throws {
        let testItems = [
            ItemModel(id: UUID(), category: "A"),
            ItemModel(id: UUID(), category: "B"),
            ItemModel(id: UUID(), category: "C")
        ]
        _ = try await createItems(testItems)
    }

    /// Get count of stored items (test helper)
    func getItemCount() async -> Int {
        return items.count
    }

    /// Clear all items (test helper)
    func clearAll() async {
        items.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency)
    nonisolated func clearAllData() {
        items.removeAll()
    }
}
```

---

## Checklist for New Mock Repository

- [ ] Class marked `@MainActor final class`
- [ ] Storage uses `nonisolated(unsafe) private var`
- [ ] All protocol methods use `async throws` or `async`
- [ ] Use `await` when accessing actor-isolated properties
- [ ] Filtering operations extract properties before comparison
- [ ] Sorting operations extract properties, create tuples, sort, map
- [ ] Test helpers included: `populateWithTestData()`, `getItemCount()`, `clearAll()`, `clearAllData()`
- [ ] File header with description
- [ ] MARK comments for organization

---

## Time Savings

Following this pattern from the start:
- **Before**: 1+ hour per mock repository fixing actor isolation errors
- **After**: 10-15 minutes to write correctly the first time

**Pattern discovered from**: Fixing 9+ mock repository files with Swift 6 concurrency errors (6+ hours of work)
