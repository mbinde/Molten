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
