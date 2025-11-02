# Swift 6 Strict Concurrency Guide

This guide covers Swift 6 concurrency patterns used in the Molten codebase.

## Overview

- **Async/await** throughout repository operations
- **Swift Testing** with `#expect()` assertions
- **Clean concurrency boundaries** via repository pattern
- **Thread-safe** service and utility implementations

## 🔥 CRITICAL: Key Rules

1. **NEVER write `nonisolated struct`** - Invalid syntax, causes EXC_BREAKPOINT crashes
2. **Sendable structs are already safe** - No annotations needed on struct declaration
3. **Mark individual members** - Use `nonisolated` on init/static methods only when needed
4. **Service classes need `@preconcurrency`** - Prevents MainActor inference
5. **Test suites need `@MainActor`** - When accessing MainActor-isolated properties
6. **Let Swift synthesize Equatable/Hashable** - Don't write explicit implementations for protocol-conforming Sendable structs

## Common Patterns

### Domain Models (Structs)

```swift
struct GlassItemModel: Sendable {  // ✅ No nonisolated on struct
    let natural_key: String        // ✅ Already safe

    nonisolated init(...) { }      // ✅ Mark members only
    nonisolated static func parse(...) { }
}
```

### Service Classes

```swift
@preconcurrency  // ✅ Prevents MainActor inference
class CatalogService {
    nonisolated(unsafe) private let repository: Repository
    nonisolated init(...) { }
}
```

### Test Files

```swift
@Suite("Tests")
@MainActor  // ✅ When accessing MainActor-isolated code
struct MyTests { }
```

## Special Cases

### Structs accessing ObservableObject

Mark specific methods as `@MainActor`:

```swift
struct TypeSystem {
    nonisolated static func getType(...) { }  // Regular method

    @MainActor static func displayName(...) {  // Needs ObservableObject access
        return Settings.shared.displayName(...)
    }
}
```

### ObservableObjects

Keep MainActor-isolated, never mark `nonisolated`

## Quick Diagnostic

### Error: "property 'X' can not be mutated from nonisolated context" (in service class init)
- **Fix**: Add `@preconcurrency` before `class` declaration

### Error: "property 'X' cannot be accessed from outside of actor" (in tests)
- **Fix**: Add `@MainActor` to test suite

### EXC_BREAKPOINT crash at runtime
- **Cause**: Invalid `nonisolated struct` syntax
- **Fix**: Remove `nonisolated` from struct declarations

### Error: "call to main actor-isolated initializer"
- **Fix**: Mark initializer `nonisolated` or mark caller `@MainActor`

## 🚨 CRITICAL: SwiftUI View Lifecycle Causing Threading Issues

### The Problem: Service Creation in View Init

**NEVER create services/repositories in SwiftUI view `init` with fallback logic:**

```swift
// ❌ WRONG - CAUSES DISPATCH QUEUE CRASHES
struct MyView: View {
    private let service: Service

    init(service: Service? = nil) {
        self.service = service ?? RepositoryFactory.createService()  // ❌ DISASTER!
    }
}
```

### Why This Causes `_dispatch_assert_queue_fail` Crashes

1. SwiftUI views are **value types (structs)** - recreated on EVERY state change
2. Parent view state changes → View struct recreated → `init` runs again
3. New service instance created on every recreation
4. Multiple service instances access Core Data/CloudKit concurrently
5. Threading conflict → `_dispatch_assert_queue_fail` crash

### Real-World Impact

This pattern caused crashes in:
- **ImageHelpers** - Creating UserImageRepository on every image load (100+ concurrent instances during initial load!)
- **AddInventoryItemView** - Creating services on every parent state change
- **DeepLinkedItemView** - Creating services during deep link navigation
- **20+ other views** found with this pattern

### The Fix: Two Valid Patterns

**Pattern 1: Always Require Services (Preferred)**

```swift
// ✅ CORRECT - Services MUST be passed from parent
struct MyView: View {
    let service: Service  // No fallback, no optional

    init(service: Service) {  // Required parameter
        self.service = service
    }
}
```

**Pattern 2: Cache in @State if Needed**

```swift
// ✅ CORRECT - Cache service instance in @State
struct MyView: View {
    @State private var service: Service?

    var body: some View {
        // ...
        .task {
            if service == nil {
                service = RepositoryFactory.createService()  // Created ONCE
            }
        }
    }
}
```

### How to Identify This Bug

**User reports:**
> "Crashes happen 10 seconds after launch with no clear reason"
> "It works sometimes, crashes other times"
> "Crashed when I clicked Add Item"

**Error message:**
```
BUG IN CLIENT OF LIBDISPATCH: _dispatch_assert_queue_fail
Block was expected to execute on queue
```

**Warning in console:**
```
NavigationRequestObserver tried to update multiple times per frame
```

### Systematic Search

Find all instances of this pattern:
```bash
grep -rn "?? RepositoryFactory.create" Molten/Sources/Views/ --include="*.swift"
```

Each match needs to be fixed using Pattern 1 or Pattern 2 above.

### Prevention Checklist

When creating a new SwiftUI view:
- ✅ Services/repositories passed as required `let` parameters
- ✅ OR cached in `@State` and initialized in `.task` or `.onAppear`
- ❌ NEVER use `service ?? RepositoryFactory.create...()` in init
- ❌ NEVER use `private let service = RepositoryFactory.create...()` as stored property

## 🚨 CRITICAL: Core Data + compactMap Escaping Closures

### The Problem: Using compactMap/map on NSManagedObject Arrays

**NEVER use `compactMap`/`map` with closures on Core Data fetch results:**

```swift
// ❌ WRONG - CAUSES DISPATCH QUEUE CRASHES
private func fetchTagsSync(forItem itemNaturalKey: String) throws -> [String] {
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
    let coreDataItems = try backgroundContext.fetch(fetchRequest)

    // ❌ DISASTER - compactMap closure may escape the context's queue!
    return coreDataItems.compactMap { $0.value(forKey: "tag") as? String }
}
```

### Why This Causes `_dispatch_assert_queue_fail` Crashes

1. Swift 6 strict concurrency detects that the closure in `compactMap` **might escape** the Core Data context's queue
2. NSManagedObjects MUST only be accessed on their owning context's queue
3. The closure captures managed objects, creating potential for cross-queue access
4. Runtime check fails → `_dispatch_assert_queue_fail` crash

### The Fix: Extract Values Immediately with Explicit Loops

```swift
// ✅ CORRECT - Extract values immediately while on context's queue
private func fetchTagsSync(forItem itemNaturalKey: String) throws -> [String] {
    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ItemTags")
    let coreDataItems = try backgroundContext.fetch(fetchRequest)

    // ✅ Extract values immediately in explicit loop
    var tags: [String] = []
    for item in coreDataItems {
        if let tag = item.value(forKey: "tag") as? String {
            tags.append(tag)
        }
    }
    return tags
}
```

### Real-World Crash

This pattern caused crashes in **CoreDataItemTagsRepository**:

**Stack trace:**
```
#0  _dispatch_assert_queue_fail
#3  _swift_task_checkIsolatedSwift
#5  closure #1 in CoreDataItemTagsRepository.fetchTagsSync(forItem:)
#6  _compactMap
```

**The crash happened at:**
```swift
// Line 533 in CoreDataItemTagsRepository.swift
return coreDataItems.compactMap { $0.value(forKey: "tag") as? String }
```

### Affected Code Locations

Fixed in **CoreDataItemTagsRepository.swift**:
- `fetchTags(forItem:)` - line 45
- `getAllTags()` - line 317
- `getTags(withPrefix:)` - line 340
- `fetchItems(withTag:)` - line 383
- `fetchItems(withAnyTags:)` - line 452
- `fetchTagsSync(forItem:)` - line 533 (original crash location)
- `calculateTagCountsSync()` - line 557

### Prevention Checklist

When working with Core Data:
- ✅ Extract values from NSManagedObjects immediately in explicit `for` loops
- ✅ Always access managed objects only within `context.perform { }` blocks
- ❌ NEVER use `compactMap`/`map` with closures on NSManagedObject arrays
- ❌ NEVER let managed objects escape their context's queue

### Quick Detection

Search for this anti-pattern:
```bash
grep -rn "compactMap.*value(forKey" Molten/Sources/Repositories/CoreData/ --include="*.swift"
```

Each match needs to be replaced with an explicit `for` loop.

## 🔥 CRITICAL: Protocol-Based DRY with Sendable and nonisolated

### The Challenge

When creating protocols for DRY (Don't Repeat Yourself) code sharing in Swift 6, you'll encounter MainActor isolation issues even with `Sendable` structs. This happens because Swift 6 infers MainActor isolation for protocol conformances unless explicitly told otherwise.

### The Problem Pattern

```swift
// ❌ THIS WILL CAUSE 350+ COMPILE ERRORS
protocol ItemQuantityModel: Sendable {
    var quantity: Double { get }           // Inferred as MainActor-isolated!
    func withQuantity(_ newQuantity: Double) -> Self
}

struct InventoryModel: ItemQuantityModel, @unchecked Sendable {
    let quantity: Double
    // ERROR: "main actor-isolated property 'quantity' cannot be accessed from outside of the actor"
}
```

**Why this fails:**
- Protocol properties are inferred as MainActor-isolated by default
- Even though the struct is `Sendable`, the protocol conformance creates isolation boundaries
- Repository classes calling these methods from background queues fail with actor isolation errors

### The Solution: Mark Everything nonisolated

The key insight from Swift 6 research: **Mark both protocol requirements AND their implementations as `nonisolated`**

```swift
// ✅ CORRECT - Mark protocol requirements as nonisolated
protocol ItemQuantityModel: Sendable {
    // Core fields must be nonisolated for cross-actor access
    nonisolated var id: UUID { get }
    nonisolated var quantity: Double { get }
    nonisolated var item_stable_id: String { get }

    // Business logic methods must also be nonisolated
    nonisolated var isValid: Bool { get }
    nonisolated func withQuantity(_ newQuantity: Double) -> Self
    nonisolated func matchesSearchText(_ searchText: String) -> Bool
}

// ✅ Protocol extension default implementations also need nonisolated
extension ItemQuantityModel {
    nonisolated var isValid: Bool {
        return !item_stable_id.isEmpty && quantity > 0
    }

    nonisolated func matchesSearchText(_ searchText: String) -> Bool {
        return item_stable_id.lowercased().contains(searchText.lowercased())
    }
}

// ✅ Conforming struct needs nonisolated on methods
struct InventoryModel: ItemQuantityModel, @unchecked Sendable {
    let id: UUID
    let quantity: Double
    let item_stable_id: String

    // Mark init as nonisolated so it can be called from any isolation domain
    nonisolated init(id: UUID = UUID(), quantity: Double, item_stable_id: String) {
        self.id = id
        self.quantity = quantity
        self.item_stable_id = item_stable_id
    }

    // Protocol implementation must be nonisolated
    nonisolated func withQuantity(_ newQuantity: Double) -> InventoryModel {
        return InventoryModel(id: id, quantity: newQuantity, item_stable_id: item_stable_id)
    }

    // Equatable/Hashable implementations also need nonisolated
    nonisolated static func == (lhs: InventoryModel, rhs: InventoryModel) -> Bool {
        return lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

### Why This Works

1. **`nonisolated` on protocol requirements** - Tells Swift these properties/methods can be accessed from any isolation domain
2. **`@unchecked Sendable`** - Asserts to the compiler that the type is safe for concurrent access (use carefully!)
3. **`nonisolated` on implementations** - Matches the protocol requirement, allowing cross-actor calls
4. **Value types with immutable fields** - Safe because there's no mutable shared state

### Common Errors You'll See Without This Pattern

```
error: main actor-isolated property 'quantity' cannot be accessed from outside of the actor
error: main actor-isolated initializer 'init(...)' cannot be called from outside of the actor
error: main actor-isolated instance method 'withQuantity' cannot be called from outside of the actor
error: main actor-isolated conformance of 'MyModel' to 'Hashable' cannot satisfy conformance requirement for a 'Sendable' type parameter
```

### Real-World Example: ItemQuantityModel Protocol

This pattern was successfully used to eliminate ~60% code duplication between `InventoryModel` and `ItemShoppingModel`:

**Before:** Each model had duplicate validation, formatting, and search logic (150+ lines duplicated)

**After:** Shared protocol with default implementations (80 lines shared, 70 lines domain-specific)

**Result:** Reduced 350+ compile errors to 7 by systematically applying `nonisolated` to:
- All protocol property requirements (id, quantity, item_stable_id, etc.)
- All protocol method requirements (withQuantity, matchesSearchText, etc.)
- All protocol extension implementations
- All struct initializers and methods
- Equatable/Hashable conformances

### When NOT to Use This Pattern

- ❌ **Types with mutable state** - Use proper actor isolation instead
- ❌ **Classes** - Use actors or `@MainActor` isolation
- ❌ **ObservableObject** - Keep MainActor-isolated
- ❌ **Reference types** - Not safe for `@unchecked Sendable`

### Checklist for Protocol-Based DRY

When creating a shared protocol for models:

1. ✅ Make protocol inherit from `Sendable`
2. ✅ Mark ALL protocol property requirements as `nonisolated`
3. ✅ Mark ALL protocol method requirements as `nonisolated`
4. ✅ Mark ALL protocol extension implementations as `nonisolated`
5. ✅ Mark conforming struct init as `nonisolated`
6. ✅ Mark conforming struct methods as `nonisolated`
7. ✅ Use `@unchecked Sendable` on conforming structs (if all fields are value types)
8. ✅ Test with repository classes that call from background queues

### 🚨 CRITICAL: Explicit vs Synthesized Equatable/Hashable Conformance

**The Problem:** After adding `nonisolated` everywhere, you may still get alternating conformance errors:

```
error: type 'InventoryModel' does not conform to protocol 'ItemQuantityModel'
error: main actor-isolated conformance of 'InventoryModel' to 'Hashable' cannot satisfy conformance requirement for a 'Sendable' type parameter 'Self'
```

These errors alternate between models depending on compilation order, which is a sign of **explicit conformance conflicting with Swift's synthesized conformance**.

**The Solution: Let Swift Synthesize Equatable/Hashable**

```swift
// ❌ WRONG - Explicit implementations can conflict with protocol synthesis
struct InventoryModel: ItemQuantityModel, @unchecked Sendable {
    let id: UUID
    let quantity: Double

    // ❌ Remove these explicit implementations!
    nonisolated static func == (lhs: InventoryModel, rhs: InventoryModel) -> Bool {
        return lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// ✅ CORRECT - Let Swift synthesize based on stored properties
struct InventoryModel: ItemQuantityModel, @unchecked Sendable {
    let id: UUID
    let quantity: Double
    // No explicit == or hash implementation needed!
    // Swift synthesizes them automatically for Sendable structs
}
```

**Why this fixes the error:**
- Swift 6's synthesized conformance for `Sendable` structs is always correctly isolated
- Explicit `nonisolated` implementations can conflict with the protocol's synthesis requirements
- When you declare conformance to `Equatable` and `Hashable` but don't implement them explicitly, Swift synthesizes correct implementations
- The synthesized conformance "just works" with protocol inheritance (ItemQuantityModel inherits Equatable/Hashable)

**Real-World Impact:**
- Started with 350+ errors after adding `nonisolated` to protocol
- Fixed 348 errors by adding `nonisolated` everywhere
- Last 2 errors alternated between `InventoryModel` and `ItemShoppingModel`
- **Fixed by removing explicit Equatable/Hashable implementations** from both models
- Build now succeeds (only unrelated UIKit errors remain)

**When to use explicit vs synthesized:**
- ✅ **Use synthesized** (no explicit implementation) when:
  - Conforming to protocols that inherit Equatable/Hashable
  - All stored properties are already Equatable/Hashable
  - Using `@unchecked Sendable` structs
  - Working with Swift 6 strict concurrency

- ❌ **Use explicit** (manual implementation) only when:
  - You need custom equality logic (e.g., comparing only certain fields)
  - You need custom hash logic (e.g., hashing only business keys)
  - Type has properties that aren't Equatable/Hashable
  - **NOT when conforming to protocols in Swift 6 strict concurrency mode**

**Investigation Timeline:**
- This took 5 days to debug across 350+ errors
- Tried: renaming properties, adding/removing `@preconcurrency`, explicit conformance declarations
- **Root cause:** Explicit `nonisolated static func ==` and `nonisolated func hash` conflicted with protocol synthesis
- **Solution:** Delete explicit implementations, let Swift synthesize

### Resources

This pattern was learned from investigating Swift 6 strict concurrency in January 2025:
- Donny Wals: "Solving actor-isolated protocol conformance" (donnywals.com)
- Swift Evolution: Sendable and actor isolation inference
- Apple: Swift Concurrency Adoption Guidelines
- Swift Forums: "Protocol conformance errors from 6.1 toolchain" thread

**Key insights:**
1. Protocol conformance creates isolation boundaries - use `nonisolated` liberally on protocol APIs that need cross-actor access
2. Let Swift synthesize Equatable/Hashable for protocol-conforming Sendable structs - explicit implementations can conflict with synthesis
