# @Service Wrapper Architecture Review

**Date**: 2025-11-20
**Architect Feedback Score**: 6/10
**Status**: Partially valid, but misunderstands actual implementation

## Executive Summary

The architect suggests replacing the `@Service` property wrapper with SwiftUI's Environment pattern. However, analysis shows:

1. **`@Service` is documentation-only** - Not used in production code
2. **Already using Environment** - Via `@Environment(\.appDependencies)` and `@Environment(EntitlementService.self)`
3. **Init pattern is primary** - Views use `init()` with default parameters for dependency injection
4. **Architecture is hybrid** - Combines Environment, init injection, and modern `@Observable` pattern

The architect's criticism is based on an incorrect assumption about how the app works.

---

## Current Implementation (Actual Code)

### Pattern 1: Environment for AppDependencies Container

**MoltenApp.swift (lines 123-124):**
```swift
.modifier(DependenciesEnvironmentModifier(dependencies: dependencies))
.environment(dependencies.entitlementService)
```

**AppDependencies.swift (lines 476-481):**
```swift
extension EnvironmentValues {
    var appDependencies: AppDependencies {
        get { self[AppDependenciesKey.self] }
        set { self[AppDependenciesKey.self] = newValue }
    }
}
```

### Pattern 2: Init Injection with Default Parameters

**InventoryView.swift (lines 62-104):**
```swift
// Full init for testing (protocol-based pattern)
init(
    viewModel: InventoryViewModel,
    catalogService: CatalogService,
    inventoryTrackingService: InventoryTrackingService,
    // ... 7 more dependencies
) {
    self._viewModel = State(initialValue: viewModel)
    self.catalogService = catalogService
    // ... store all dependencies
}

// Convenience init for production use
init(deps: AppDependencies = AppDependencies()) {
    let viewModel = InventoryViewModel(
        inventoryTrackingService: deps.inventoryTrackingService,
        catalogService: deps.catalogService
    )
    self.init(
        viewModel: viewModel,
        catalogService: deps.catalogService,
        // ... extract from deps
    )
}
```

### Pattern 3: Modern @Observable + Environment

**InventoryView.swift (line 19):**
```swift
@Environment(EntitlementService.self) private var entitlementService
```

This uses SwiftUI's **modern `@Observable` macro** (iOS 17+) for reactive services.

### Pattern 4: @Service Wrapper (Documentation Only)

**CoreDataSafetyGuards.swift (lines 82-95):**
```swift
@propertyWrapper
struct Service<T> {
    let wrappedValue: T
    init(wrappedValue: @autoclosure () -> T) {
        self.wrappedValue = wrappedValue()
    }
}
```

**Usage in codebase:**
- Defined in `CoreDataSafetyGuards.swift` (runtime guard)
- Documented in `CLAUDE.md` (example pattern)
- **NOT USED in any production view** ✅

---

## Architect's Criticism Analyzed

### Claim 1: "You need @Service because your architecture fights SwiftUI"

**Verdict: FALSE**

The app doesn't use `@Service` in production. It uses:
- `@Environment(\.appDependencies)` (Environment pattern)
- `@Environment(EntitlementService.self)` (Modern @Observable)
- `init()` with default parameters (Explicit injection)

**All three are standard SwiftUI patterns.**

### Claim 2: "Indicates impedance mismatch between architecture and framework"

**Verdict: MISLEADING**

The actual patterns used are:
- ✅ Environment for cross-cutting concerns (AppDependencies, EntitlementService)
- ✅ Init injection for testability (protocol-based ViewModels)
- ✅ Modern @Observable for reactive services

This is **textbook SwiftUI architecture**, not an impedance mismatch.

### Claim 3: "Developers must remember to use @Service or risk crashes"

**Verdict: FALSE**

Nobody uses `@Service` because it's not in production code. The actual pattern is:

```swift
// ✅ What developers actually do:
init(deps: AppDependencies = AppDependencies()) {
    // Extract services from deps
}
```

The default parameter `= AppDependencies()` is evaluated **once** during struct creation, achieving the same safety as `@Service` would.

### Claim 4: "Use SwiftUI's natural pattern (Environment)"

**Verdict: ALREADY DOING THIS**

The app already uses Environment extensively:
- `@Environment(\.appDependencies)` - Line 123 of MoltenApp.swift
- `@Environment(EntitlementService.self)` - Used in 9+ views
- `@modifier(DependenciesEnvironmentModifier)` - Line 123 of MoltenApp.swift

---

## Why @Service Exists (Even Though Unused)

### Purpose: Runtime Safety Guard

The `@Service` wrapper is part of `CoreDataSafetyGuards.swift`, which also includes:

1. **Persistent History Deletion Guard** (lines 13-62)
   - Prevents CloudKit-breaking operations
   - Crashes in DEBUG if you try to delete history

2. **Service Creation Anti-Pattern Guard** (lines 64-143)
   - Documents the `.task`/`.onAppear` anti-pattern
   - Provides `@Service` as a **fallback option**
   - Actual production code uses `init()` pattern instead

### Why It's Not Used

The init pattern is superior for this codebase:

**Init Pattern:**
```swift
// ✅ Better: Explicit, testable, clear dependencies
init(deps: AppDependencies = AppDependencies()) {
    self.catalogService = deps.catalogService
    self.inventoryService = deps.inventoryTrackingService
}
```

**@Service Pattern:**
```swift
// ❌ Worse: Implicit, harder to test, hidden dependencies
@Service var catalog = AppDependencies.shared.catalogService
@Service var inventory = AppDependencies.shared.inventoryTrackingService
```

The init pattern makes dependencies **explicit and testable** (protocol-based ViewModel pattern).

---

## Architect's Proposed Solution

```swift
// In MoltenApp:
@main
struct MoltenApp: App {
    let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.catalogService, dependencies.catalogService)
        }
    }
}

// In views:
struct CatalogView: View {
    @Environment(\.catalogService) private var catalog
}
```

### Problems with This Proposal

**1. Already Implemented (Different Style)**

The app already does this, just with the dependency container:

```swift
// Current (line 123):
.modifier(DependenciesEnvironmentModifier(dependencies: dependencies))

// Views access:
@Environment(\.appDependencies) private var deps
let catalog = deps.catalogService
```

**2. Loses Testability**

Current pattern:
```swift
// ✅ Test can inject mock
init(
    catalogService: CatalogService,  // Protocol - can be mock
    inventoryService: InventoryTrackingService  // Protocol - can be mock
)
```

Proposed pattern:
```swift
// ❌ Harder to test - need to override Environment
@Environment(\.catalogService) private var catalog
```

**3. More Boilerplate**

To use the architect's pattern, you'd need:

```swift
// For EACH service (30+ services in this app):
private struct CatalogServiceKey: EnvironmentKey {
    static let defaultValue: CatalogService = AppDependencies.shared.catalogService
}

extension EnvironmentValues {
    var catalogService: CatalogService {
        get { self[CatalogServiceKey.self] }
        set { self[CatalogServiceKey.self] = newValue }
    }
}
```

**30 services × 10 lines = 300 lines of boilerplate** vs. current 10 lines.

**4. Modern Pattern is Better**

The app uses modern `@Observable`:

```swift
@Environment(EntitlementService.self) private var entitlementService
```

This is **Apple's recommended pattern** for SwiftUI in iOS 17+. It's cleaner than EnvironmentKey.

---

## Actual Architecture: Hybrid Approach

The app uses a **pragmatic mix** based on use case:

### Use Case 1: Cross-Cutting Services (Entitlements, Subscriptions)

**Pattern**: `@Environment(ServiceType.self)` with `@Observable`

```swift
// MoltenApp.swift (line 124):
.environment(dependencies.entitlementService)

// Views (InventoryView.swift:19):
@Environment(EntitlementService.self) private var entitlementService
```

**Why**: These services are needed by many views, injecting at app level is clean.

### Use Case 2: Feature-Specific Services (Catalog, Inventory)

**Pattern**: `init()` with default parameters

```swift
init(deps: AppDependencies = AppDependencies()) {
    self.catalogService = deps.catalogService
    self.inventoryService = deps.inventoryTrackingService
}
```

**Why**:
- Explicit dependencies (self-documenting)
- Testable (protocol-based injection)
- No Environment pollution (30 services would clutter Environment)

### Use Case 3: Whole Dependency Container

**Pattern**: `@Environment(\.appDependencies)`

```swift
@Environment(\.appDependencies) private var deps
let catalog = deps.catalogService
```

**Why**: Convenience for views that need multiple services occasionally.

---

## Performance Comparison

### Current Architecture

**View Creation (InventoryView):**
```
1. SwiftUI creates struct
2. init() evaluates default parameter: AppDependencies()
3. AppDependencies returns shared singleton
4. Services extracted once, stored in let properties
5. Total: ~O(1), single allocation
```

**View Render:**
```
- No lookups (services stored in properties)
- Direct property access
- Total: O(0)
```

### Architect's Proposed Architecture

**View Creation:**
```
1. SwiftUI creates struct
2. @Environment reads from EnvironmentValues dictionary
3. Dictionary lookup for catalogService key
4. Extract service
5. Repeat for each @Environment property (N lookups)
6. Total: O(N) where N = number of services
```

**View Render:**
```
- Each @Environment is a computed property
- Re-reads from EnvironmentValues on every access
- Total: O(M) where M = service access count
```

**Performance**: Current approach is **faster** (O(1) vs O(N+M)).

---

## The Real Anti-Pattern (Correctly Documented)

The `@Service` wrapper guards against THIS anti-pattern:

```swift
// ❌ WRONG: Creating services in .task
struct MyView: View {
    @State private var service: CatalogService?

    var body: some View {
        Text("Content")
            .task {
                if service == nil {
                    service = AppDependencies.shared.catalogService  // ❌ Creates new Core Data context!
                }
            }
    }
}
```

**Why this breaks:**
- SwiftUI views are value types, recreated on parent state changes
- `.task` runs on every recreation
- Each `AppDependencies.shared.catalogService` call creates new actor instance
- Actors contain Core Data contexts
- Multiple contexts on same queue → `_dispatch_assert_queue_fail` crash

**The fix (already implemented):**
```swift
// ✅ CORRECT: Create in init()
init(deps: AppDependencies = AppDependencies()) {
    self.catalogService = deps.catalogService  // ✅ Evaluated ONCE
}
```

The default parameter `= AppDependencies()` is evaluated **once** during struct initialization, not on every render.

---

## Recommendations

### Keep Current Architecture ✅

**Reasons:**
1. **Already using Environment** - For cross-cutting concerns (EntitlementService)
2. **Already using @Observable** - Modern SwiftUI pattern (iOS 17+)
3. **Already using init injection** - Best for testability
4. **More performant** - O(1) vs O(N+M)
5. **Less boilerplate** - 10 lines vs 300+ lines
6. **Testable** - Protocol-based ViewModels work with init injection

### Potential Improvements

**Option 1: Document the Hybrid Approach**

Add to CLAUDE.md:

```markdown
## Dependency Injection Patterns

Use the right pattern for the use case:

1. **Cross-cutting services** (EntitlementService, SubscriptionManager):
   - Use `@Environment(ServiceType.self)` with `@Observable`
   - Injected at app level in MoltenApp.swift

2. **Feature-specific services** (CatalogService, InventoryTrackingService):
   - Use `init()` with default parameters
   - Enables protocol-based testing

3. **Multiple services** (views needing 5+ services):
   - Use `@Environment(\.appDependencies)` for convenience
   - Extract needed services in computed properties
```

**Option 2: Remove @Service Wrapper (Optional)**

Since it's unused in production, you could:
1. Remove the `@Service` definition
2. Keep the anti-pattern documentation in comments
3. Update CLAUDE.md to show `init()` pattern only

**Rationale**: Reduces confusion about which pattern to use.

---

## Final Verdict: Architect Score 6/10

**What they got right:**
- ✅ Environment is a good pattern for dependency injection
- ✅ Property wrappers can be confusing if overused

**What they got wrong:**
- ❌ Assumed `@Service` is actually used (it's not)
- ❌ Claimed architecture "fights SwiftUI" (it follows SwiftUI patterns)
- ❌ Ignored existing Environment usage
- ❌ Ignored modern `@Observable` pattern
- ❌ Proposed solution has worse performance (O(N+M) vs O(1))
- ❌ Proposed solution requires 300+ lines of boilerplate
- ❌ Proposed solution makes testing harder

**The architect is giving generic advice without understanding the actual implementation.**

---

## Actual State of Affairs

| Pattern | Used? | Where | Purpose |
|---------|-------|-------|---------|
| `@Environment(\.appDependencies)` | ✅ Yes | MoltenApp.swift:123 | Convenience access to dependency container |
| `@Environment(ServiceType.self)` | ✅ Yes | 9+ views | Cross-cutting services (modern @Observable) |
| `init()` with default params | ✅ Yes | Most views | Feature-specific services (testable) |
| `@Service` wrapper | ❌ No | Only in docs | Documented anti-pattern guard (unused) |

**Conclusion**: The architecture is already doing what the architect recommends, just in a more pragmatic and performant way. No changes needed.
