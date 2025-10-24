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
