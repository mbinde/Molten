# Investigation: Replacing Service Locator with Dependency Injection

**Date:** 2025-11-10
**Question:** Should we replace `RepositoryFactory` (service locator) with proper dependency injection?

---

## Executive Summary

**Recommendation: YES** - Replace service locator with constructor injection.

**Key Finding:** Current architecture violates Swift 6 concurrency safety and hides dependencies, but the fix is mechanical and low-risk.

**Estimated effort:** 20-30 hours
**Risk level:** Medium (touches many files, but changes are mechanical)
**Expected benefits:** Swift 6 safety, explicit dependencies, better testability

---

## Investigation Results

### 1. Current Architecture Problems

**RepositoryFactory issues:**
- 19 static mutable variables (all `nonisolated(unsafe)`)
- Service locator anti-pattern (hidden dependencies)
- Global mutable state (race conditions in Swift 6)
- Test pollution (tests share state via static variables)
- Unclear object lifecycle (who owns what?)

**Example of the problem:**
```swift
// In RepositoryFactory.swift
nonisolated(unsafe) static var mockGlassItemRepo: MockGlassItemRepository? = nil

// Thread 1
RepositoryFactory.configureForTesting()
let repo1 = RepositoryFactory.createGlassItemRepository()

// Thread 2 (concurrent)
RepositoryFactory.configureForProduction()  // ⚠️ Race condition!
let repo2 = RepositoryFactory.createGlassItemRepository()  // ⚠️ Wrong mode!
```

**Swift 6 concurrency violations:**
```
warning: static property 'mode' is not concurrency-safe because it is
nonisolated global shared mutable state
```

### 2. RepositoryFactory Usage Analysis

**Total usage in views:** 141 occurrences

**Top services created:**
1. `createCatalogService()` - 26 uses
2. `createKilnScheduleService()` - 15 uses
3. `createInventoryTrackingService()` - 14 uses
4. `createUserImageRepository()` - 13 uses
5. `createUnifiedLocationService()` - 12 uses

**Files affected:**
- Views: ~60 files
- ViewModels: ~20 files
- Services: ~15 files
- Tests: ~100 files
- **Total:** ~195 files

**Current pattern (service locator):**
```swift
struct CatalogView: View {
    private let catalogService: CatalogService

    // Hidden dependency - could create new service on every view recreation!
    init(catalogService: CatalogService = RepositoryFactory.createCatalogService()) {
        self.catalogService = catalogService
    }
}
```

**Problems with this pattern:**
1. **Hidden dependency:** Can't see what CatalogService needs by looking at init
2. **Unclear ownership:** Is the service shared or per-view?
3. **Hard to test:** Must manipulate global state to inject mocks
4. **SwiftUI lifecycle issues:** Default parameters evaluated at call time

### 3. Dependency Graph Analysis

**Root dependencies:**
```
NSManagedObjectContext
    ↓
Repositories (15 types)
    ↓
Services (10 types)
    ↓
Views (60+ files)
```

**Key insight:** Only 2 root dependencies!
- `localContext` (catalog data) - but moving to in-memory, so 1 less!
- `cloudContext` (user data)

**What this means:**
- If catalog data moves to in-memory store: **Only 1 Core Data context needed**
- Create repositories once at app startup
- Pass down through view hierarchy

---

## Migration Path

### Option A: Full Dependency Injection (Recommended)

**Effort:** 20-30 hours
**Risk:** Medium
**Benefits:** Complete solution, Swift 6 safe, best long-term

#### Step 1: Create Dependency Container (4-6 hours)

**New pattern:**
```swift
/// Dependency container created once at app startup
@MainActor
class AppDependencies {
    // Core Data
    let persistenceController: PersistenceController
    let cloudContext: NSManagedObjectContext

    // Repositories
    let glassItemRepository: GlassItemRepository
    let inventoryRepository: InventoryRepository
    let locationRepository: LocationRepository
    // ... (15 repositories)

    // Services
    let catalogService: CatalogService
    let inventoryTrackingService: InventoryTrackingService
    let shoppingListService: ShoppingListService
    // ... (10 services)

    init(mode: RepositoryMode = .production) {
        // Create Core Data
        self.persistenceController = PersistenceController.shared
        self.cloudContext = persistenceController.cloudContext!

        // Create repositories
        self.glassItemRepository = CoreDataGlassItemRepository(context: cloudContext)
        self.inventoryRepository = CoreDataInventoryRepository(context: cloudContext)
        // ...

        // Create services
        self.catalogService = CatalogService(
            glassItemRepository: glassItemRepository,
            inventoryRepository: inventoryRepository,
            // ... explicit dependencies
        )
        // ...
    }

    /// Factory for testing with mocks
    static func forTesting() -> AppDependencies {
        return AppDependencies(mode: .mock)
    }
}
```

**Benefits:**
- Single point of object creation
- Clear dependency graph
- Easy to swap implementations
- Type-safe (no dynamic lookups)

#### Step 2: Update App Entry Point (1 hour)

**Change MoltenApp:**
```swift
@main
struct MoltenApp: App {
    @State private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dependencies, dependencies)
        }
    }
}

// Environment key for DI
extension EnvironmentValues {
    @Entry var dependencies: AppDependencies = AppDependencies()
}
```

**Benefits:**
- Dependencies created once at app launch
- Shared across entire app
- SwiftUI environment for easy access

#### Step 3: Update Views (12-18 hours)

**Pattern 1: Root views (pass dependencies down)**
```swift
// Before (service locator)
struct CatalogView: View {
    private let catalogService: CatalogService

    init(catalogService: CatalogService = RepositoryFactory.createCatalogService()) {
        self.catalogService = catalogService
    }
}

// After (dependency injection)
struct CatalogView: View {
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        CatalogListView(catalogService: dependencies.catalogService)
    }
}
```

**Pattern 2: Child views (receive dependencies)**
```swift
// Before (service locator - creates own)
struct CatalogListView: View {
    private let catalogService: CatalogService

    init(catalogService: CatalogService = RepositoryFactory.createCatalogService()) {
        self.catalogService = catalogService
    }
}

// After (dependency injection - receives)
struct CatalogListView: View {
    let catalogService: CatalogService  // Injected, no default!

    init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }
}
```

**Files to update:**
- ~60 view files
- ~20 view model files
- Mechanical change (search & replace)

#### Step 4: Update Tests (2-4 hours)

**Pattern change:**
```swift
// Before (global state manipulation)
func testCatalogView() {
    RepositoryFactory.configureForTesting()  // Global!
    let view = CatalogView()
}

// After (explicit injection)
func testCatalogView() {
    let deps = AppDependencies.forTesting()
    let view = CatalogView(dependencies: deps)
}
```

**Test infrastructure:**
```swift
extension AppDependencies {
    static func forTesting(
        catalogService: CatalogService? = nil,
        inventoryService: InventoryTrackingService? = nil
    ) -> AppDependencies {
        let deps = AppDependencies(mode: .mock)

        // Allow override for specific tests
        if let catalogService = catalogService {
            deps.catalogService = catalogService
        }

        return deps
    }
}
```

**Benefits:**
- Explicit mocking (pass fake service)
- No global state pollution
- Tests run in parallel safely
- Clear test setup

#### Step 5: Remove RepositoryFactory (1-2 hours)

**After all views/tests migrated:**
1. Delete `RepositoryFactory.swift` (~960 lines)
2. Remove static factory methods
3. Update documentation
4. Celebrate! 🎉

**Benefits:**
- 960 lines of code deleted
- No more `nonisolated(unsafe)`
- Swift 6 concurrency-safe
- Simpler mental model

### Option B: Hybrid Approach (Faster but incomplete)

**Effort:** 8-12 hours
**Risk:** Low
**Benefits:** Quick win, but doesn't fully solve the problem

**Changes:**
1. Keep `RepositoryFactory` but remove static mutables
2. Create dependency container, pass it to factory
3. Views still use factory, but factory uses container

**Code:**
```swift
// Dependency container
@MainActor
class AppDependencies {
    let cloudContext: NSManagedObjectContext
    // ... dependencies

    lazy var catalogService = {
        CatalogService(/* dependencies */)
    }()
}

// RepositoryFactory becomes stateless
struct RepositoryFactory {
    let dependencies: AppDependencies

    func createCatalogService() -> CatalogService {
        return dependencies.catalogService
    }
}

// Views still use factory pattern
struct CatalogView: View {
    @Environment(\.dependencies) var dependencies
    private let catalogService: CatalogService

    init() {
        let factory = RepositoryFactory(dependencies: dependencies)
        self.catalogService = factory.createCatalogService()
    }
}
```

**Pros:**
- Faster migration (fewer files to change)
- Removes static mutables (Swift 6 safe)
- Smaller code diff

**Cons:**
- Still hides dependencies (factory pattern)
- More verbose than pure DI
- Half-measure (should finish the job)

---

## Recommended Approach

### Timeline

**Phase 1: Preparation (1-2 hours)**
- Create feature branch
- Run full test suite (establish baseline)
- Commit working state

**Phase 2: Create AppDependencies (4-6 hours)**
- Implement dependency container
- Add test factory
- Unit test container creation
- Keep RepositoryFactory for now (parallel implementation)

**Phase 3: Migrate Views (12-18 hours)**
- Start with leaf views (no children)
- Move up the tree to root views
- Test each major view after migration
- Keep both patterns working during transition

**Phase 4: Migrate Tests (2-4 hours)**
- Update test infrastructure
- Migrate tests file by file
- Run tests frequently

**Phase 5: Remove RepositoryFactory (1-2 hours)**
- Delete factory code
- Remove imports
- Update documentation
- Final test run

**Phase 6: Rollout (1 week)**
- PR review
- QA testing
- Staged rollout (if possible)
- Monitor crash rates

### Risk Mitigation

**Risks:**
1. **Breaking existing views:** Mitigate with incremental migration + testing
2. **Performance regression:** Mitigate with benchmarks before/after
3. **Test failures:** Mitigate with frequent test runs during migration
4. **Merge conflicts:** Mitigate with short-lived feature branch

**Rollback plan:**
- Keep RepositoryFactory during transition
- Feature flag for new DI system
- Can revert to factory if critical issues

### Success Criteria

**Must have:**
- [ ] All 141 RepositoryFactory usages migrated
- [ ] All tests passing
- [ ] Zero Swift 6 concurrency warnings
- [ ] App launches successfully
- [ ] All major features working

**Nice to have:**
- [ ] Improved app launch time
- [ ] Reduced memory usage
- [ ] Better test execution time
- [ ] Cleaner architecture documentation

---

## Cost-Benefit Analysis

### Costs

**Development time:** 20-30 hours
- Phase 1 (Preparation): 1-2 hours
- Phase 2 (AppDependencies): 4-6 hours
- Phase 3 (Migrate views): 12-18 hours
- Phase 4 (Migrate tests): 2-4 hours
- Phase 5 (Cleanup): 1-2 hours

**Risk factors:**
- Many files touched (~195 files)
- Potential for merge conflicts
- Testing every view migration
- Regression risk if not careful

### Benefits

**Immediate:**
1. **Swift 6 concurrency-safe**
   - No more `nonisolated(unsafe)` warnings
   - Compiler-enforced thread safety
   - Future-proof for Swift 6 strict mode

2. **Explicit dependencies**
   - Clear what each component needs
   - Easier to understand data flow
   - Better IDE autocomplete

3. **Better testability**
   - No global state pollution
   - Parallel test execution safe
   - Clear test setup

4. **Simpler code**
   - Delete 960 lines (RepositoryFactory)
   - Remove 19 static mutables
   - Clearer object ownership

**Long-term:**
1. **Maintainability**
   - New developers understand DI pattern
   - Easier to refactor services
   - Less coupling between components

2. **Scalability**
   - Add new services without factory
   - Easy to swap implementations
   - Support multiple configurations

3. **Architecture clarity**
   - Dependency graph visible
   - No hidden couplings
   - Follow iOS best practices

---

## Comparison: Service Locator vs Dependency Injection

| Aspect | Service Locator (Current) | Dependency Injection (Proposed) |
|--------|---------------------------|----------------------------------|
| **Dependencies** | Hidden (factory creates) | Explicit (constructor params) |
| **Thread safety** | ❌ Unsafe (static mutables) | ✅ Safe (actor/container) |
| **Testing** | Global state manipulation | Inject mocks directly |
| **Ownership** | Unclear | Clear (passed from parent) |
| **Lifecycle** | Hidden | Visible |
| **Lines of code** | +960 (factory file) | -960 (deleted!) |
| **Swift 6** | ❌ 19 warnings | ✅ Zero warnings |
| **Learning curve** | Medium (anti-pattern) | Low (standard pattern) |

---

## Recommendation

**YES - Migrate to dependency injection**

**Why:**
1. **Technical debt:** Service locator is an anti-pattern
2. **Swift 6:** Current approach won't work in strict concurrency mode
3. **Maintainability:** Explicit > implicit
4. **Industry standard:** DI is the standard iOS pattern

**When:**
- **After catalog migration** (if doing both) - fewer dependencies to inject
- **Before Swift 6 strict mode** - forced to fix anyway
- **When you have 1-2 weeks** - needs focused effort

**How:**
- Follow Option A (full DI)
- Incremental migration (view by view)
- Frequent testing
- Short-lived feature branch

---

## Alternative: Keep Service Locator

**If you decide NOT to migrate:**

**To make current approach safer:**
1. Replace `nonisolated(unsafe)` with actors
2. Add thread safety checks
3. Make factory methods non-static (instance-based)
4. Document the pattern clearly

**This buys time but doesn't solve:**
- Hidden dependencies
- Testing difficulties
- Architectural anti-pattern
- Future Swift 6 strict mode issues

**When this makes sense:**
- About to ship, can't afford risk
- Team unfamiliar with DI pattern
- Planning major rewrite anyway

---

## Questions to Resolve Before Starting

1. **Timing:** Can you allocate 1-2 weeks for this?
2. **Team buy-in:** Does everyone understand DI pattern?
3. **Testing capacity:** Can you QA all major flows after migration?
4. **Dependencies:** Should we do catalog migration first?
5. **Rollback:** What's the plan if critical issues emerge?

**Decision matrix:**

| If... | Then... |
|-------|---------|
| Doing catalog migration | Do DI after (fewer dependencies) |
| Not doing catalog migration | Do DI now (independent change) |
| Swift 6 strict mode planned | MUST do DI (forced by compiler) |
| Shipping in 2 weeks | Wait until after release |
| Team needs DI training | Schedule training first |

---

## Next Steps

1. **Decide:** Migrate now, later, or never?
2. **If now:**
   - Schedule 1-2 weeks of focused time
   - Create feature branch
   - Follow phase plan above
3. **If later:**
   - Document decision and timeline
   - Add to tech debt backlog
   - Revisit in 3 months
4. **If never:**
   - Implement safety improvements
   - Document the pattern
   - Accept Swift 6 limitations
