# Dependency Injection Migration - Progress Tracker

**Status:** Phase 0 Complete
**Started:** 2025-11-10
**Goal:** Replace RepositoryFactory static methods with AppDependencies DI container

---

## Phase 0: Foundation ✅ COMPLETE

**Files created:**
- `Molten/Sources/App/Factories/AppDependencies.swift` ✅
- Environment extension added ✅

**Files modified:**
- `Molten/Sources/App/MoltenApp.swift` - Partial (init only) ✅

**Verification:**
```bash
xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' build
# Result: BUILD SUCCEEDED ✅
```

**Commit status:** NOT COMMITTED (Phase 0 complete but isolated)

---

## Phase 1: MoltenApp Complete Integration ✅ COMPLETE

**Estimate:** 2-3 hours
**Actual:** ~2 hours (including debugging environment object crashes)

### Files Modified

**1. `Molten/Sources/App/MoltenApp.swift`** - Lines to update:

Line 99-122: `body`
```swift
// CURRENT:
.environment(entitlementService)  // OLD: uses RepositoryFactory

// CHANGE TO:
.environment(\.appDependencies, dependencies!)
```

Line 111-122: `.onAppear`
```swift
// ADD at start:
if dependencies == nil {
    dependencies = AppDependencies()
}
// UPDATE subscription:
if subscriptionManager == nil {
    subscriptionManager = SubscriptionManager(entitlementService: dependencies!.entitlementService)
}
```

Line 336-369: `createMainTabView()`
```swift
// CURRENT:
let catalogService = RepositoryFactory.createCatalogService()
let purchaseService = RepositoryFactory.createPurchaseRecordService()
if !isRunningUITests, syncMonitor == nil, let container = RepositoryFactory.persistentContainer as? NSPersistentCloudKitContainer {

// CHANGE TO:
guard let deps = dependencies else { fatalError("Dependencies not initialized") }
let catalogService = deps.catalogService
let purchaseService = deps.purchaseRecordService
if !isRunningUITests, syncMonitor == nil, let container = deps.persistenceController.container as? NSPersistentCloudKitContainer {
```

Line 407-421: `performBackgroundCatalogUpdate()`
```swift
// CURRENT:
let backgroundUpdateService = RepositoryFactory.createBackgroundUpdateService()

// CHANGE TO:
guard let deps = dependencies else { return }
let backgroundUpdateService = deps.backgroundUpdateService
```

Line 424-463: `configureUITestEnvironment()`
```swift
// CURRENT:
RepositoryFactory.configureForProduction()
RepositoryFactory.configureForTesting()

// CHANGE TO:
if isRunningUITests {
    dependencies = AppDependencies()  // Production mode
} else {
    dependencies = AppDependencies(forTesting: true)  // Mock mode
}
```

Line 590-641: `populateTestData()`
```swift
// CURRENT:
let glassItemRepo = RepositoryFactory.createGlassItemRepository()
let inventoryRepo = RepositoryFactory.createInventoryRepository()

// CHANGE TO:
guard let deps = dependencies else { return }
let glassItemRepo = deps.glassItemRepository
let inventoryRepo = deps.inventoryRepository
```

Line 564-586: `resetCoreDataStore()`
```swift
// CURRENT:
guard let container = RepositoryFactory.persistentContainer else {

// CHANGE TO:
guard let deps = dependencies,
      let container = deps.persistenceController.container else {
```

### Verification Commands

```bash
# Build
xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' build

# Quick test (if tests exist for MoltenApp)
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MoltenTests/MoltenAppTests
```

### Changes Made

- ✅ Added `DependenciesEnvironmentModifier` for SwiftUI environment injection
- ✅ `.onAppear` initializes `AppDependencies()` or `AppDependencies(forTesting: true)`
- ✅ `createMainTabView()` uses `dependencies.catalogService` etc.
- ✅ `performBackgroundCatalogUpdate()` uses `dependencies.backgroundUpdateService`
- ✅ `configureUITestEnvironment()` creates appropriate dependencies
- ✅ `resetCoreDataStore()` uses `dependencies.persistenceController`
- ✅ `populateTestData()` uses `dependencies.glassItemRepository` etc.

### Verification

```bash
xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' build
# Result: BUILD SUCCEEDED ✅
```

### Commit Status: ✅ COMMITTED

**Initial completion:**
```bash
git add Molten/Sources/App/ Docs/DI-Migration-Progress.md
git commit -m "refactor(di): Phase 1 complete - MoltenApp uses AppDependencies"
```

**Critical bug fix (environment object crashes):**
- Issue: Views with `@Environment(SubscriptionManager.self)` crashed when subscriptionManager was nil
- Root cause: Dependencies initialized in `.onAppear`, but views evaluated BEFORE `.onAppear` ran
- Solution: Initialize dependencies in `body` via `ensureDependenciesInitialized()` BEFORE view tree creation
- Affected views: SettingsView.swift (2 places), UpgradePromptView.swift
- Commits:
  - `81b6b074` - Re-added RepositoryFactory configuration for unmigrated views
  - `c7ccdf71` - Fixed environment object initialization timing

---

## Phase 2: High-Traffic Views

**Estimate:** 8-10 hours

### Pattern to Apply

**BEFORE:**
```swift
struct MyView: View {
    private let service: MyService

    init(service: MyService = RepositoryFactory.createMyService()) {
        self.service = service
    }
}
```

**AFTER:**
```swift
struct MyView: View {
    @Environment(\.appDependencies) private var dependencies

    var body: some View {
        MyViewContent(service: dependencies.myService)
    }
}

struct MyViewContent: View {
    let service: MyService

    var body: some View {
        // actual view code
    }
}
```

**Alternative (if view needs service in init):**
```swift
struct MyView: View {
    let service: MyService

    init(service: MyService) {
        self.service = service
    }
}

// Parent creates with:
MyView(service: dependencies.myService)
```

### Files to Update (Priority Order)

**Batch 1: Main Navigation (2-3 hours)**
1. `MainTabView.swift` - Entry point
2. `CatalogView.swift` - Tab 1
3. `InventoryView.swift` - Tab 2
4. `ShoppingListView.swift` - Tab 3
5. `PurchasesView.swift` - Tab 4
6. `ProjectLogView.swift` - Tab 5
7. `SettingsView.swift` - Tab 6

**Batch 2: Catalog Feature (2-3 hours)**
8. `AddGlassItemView.swift`
9. `EditGlassItemView.swift`
10. `GlassItemDetailView.swift`
11. `CatalogSearchView.swift`
12. `ManufacturerFilterView.swift`
13. `DeepLinkedItemView.swift`

**Batch 3: Inventory Feature (2-3 hours)**
14. `AddInventoryItemView.swift`
15. `EditInventoryView.swift`
16. `InventoryDetailView.swift`
17. `LocationsView.swift`
18. `LocationDetailView.swift`

**Batch 4: Other Features (1-2 hours)**
19. `PurchaseRecordDetailView.swift`
20. `AddLogbookEntryView.swift`
21. `LogbookDetailView.swift`
22. `ProjectDetailView.swift`
23. `ImportInventoryView.swift`
24. `ImportPlanView.swift`

### Search Commands

Find all RepositoryFactory usage in views:
```bash
grep -r "RepositoryFactory\.create" Molten/Sources/Views --include="*.swift" -l | sort
```

Count remaining:
```bash
grep -r "RepositoryFactory\.create" Molten/Sources/Views --include="*.swift" | wc -l
```

### Verification Per Batch

```bash
# After each batch, build to catch errors early
xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' build

# If build succeeds, commit the batch:
git add Molten/Sources/Views/[Feature]/
git commit -m "refactor(di): migrate [Feature] views to AppDependencies

Batch X of Phase 2 - [FeatureName] views"
```

### Commit Point (After All Batches)

```bash
git add Molten/Sources/Views/
git commit -m "refactor(di): complete Phase 2 - all views migrated to AppDependencies

Updated 60+ view files to use dependency injection.
Views now access services via @Environment(\.appDependencies)"
```

---

## Phase 3: Remaining Views & Services

**Estimate:** 4-6 hours

### Find All Remaining Files

```bash
# Find any remaining RepositoryFactory usage in Sources/
grep -r "RepositoryFactory\.create" Molten/Sources --include="*.swift" -l | grep -v "RepositoryFactory.swift"
```

### Categories

**Services that create other services:**
- Check if any services use RepositoryFactory internally
- Update to receive dependencies in constructor

**Helper/Utility files:**
- Views/Shared/Helpers
- Views/[Feature]/Helpers

**ViewModels:**
- Views/[Feature]/ViewModels

### Verification

```bash
# Should return 0 results (except RepositoryFactory.swift itself):
grep -r "RepositoryFactory\.create" Molten/Sources --include="*.swift" | grep -v "RepositoryFactory.swift"

# Build
xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### Commit Point

```bash
git add Molten/Sources/
git commit -m "refactor(di): complete Phase 3 - all sources migrated

Zero RepositoryFactory usage remaining in Sources/ (except factory itself)"
```

---

## Phase 4: Test Infrastructure

**Estimate:** 4-6 hours

### Update Test Helpers

**1. `TestDataBuilder.swift`** - Already done ✅

**2. `TestDataSetup.swift`** - Already done ✅

**3. Create `TestDependencies.swift`** (new file):
```swift
extension AppDependencies {
    /// Convenience factory for tests with specific overrides
    static func forTesting(
        catalogService: CatalogService? = nil,
        inventoryService: InventoryTrackingService? = nil
        // ... other overrides
    ) -> AppDependencies {
        let deps = AppDependencies(forTesting: true)
        // Allow test-specific overrides if needed
        return deps
    }
}
```

### Update Test Files Pattern

**BEFORE:**
```swift
func testSomething() {
    RepositoryFactory.configureForTesting()
    let view = MyView()
}
```

**AFTER:**
```swift
func testSomething() {
    let deps = AppDependencies(forTesting: true)
    let view = MyView(service: deps.myService)
}
```

### Find All Test Files Using RepositoryFactory

```bash
grep -r "RepositoryFactory" Molten/Tests --include="*.swift" -l | sort
```

Count:
```bash
grep -r "RepositoryFactory" Molten/Tests --include="*.swift" | wc -l
```

### Batch Strategy

**Batch 1: Infrastructure tests** (MoltenTests/Infrastructure/)
**Batch 2: Integration tests** (MoltenTests/Integration/)
**Batch 3: Service tests** (MoltenTests/Services/)
**Batch 4: View tests** (MoltenTests/Views/)
**Batch 5: Utility tests** (MoltenTests/Utilities/)
**Batch 6: Performance tests** (PerformanceTests/)
**Batch 7: Repository tests** (RepositoryTests/)

### Verification Per Batch

```bash
# Run tests for specific batch
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MoltenTests/Infrastructure

# Commit after each batch passes
git add Molten/Tests/MoltenTests/Infrastructure/
git commit -m "test(di): migrate Infrastructure tests to AppDependencies"
```

### Final Test Run

```bash
# All tests
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Commit Point

```bash
git add Molten/Tests/
git commit -m "refactor(di): complete Phase 4 - all tests migrated

All test files now use AppDependencies(forTesting: true).
Zero RepositoryFactory usage in tests."
```

---

## Phase 5: Cleanup & Remove RepositoryFactory

**Estimate:** 1-2 hours

### Final Verification

```bash
# Should only show RepositoryFactory.swift itself:
grep -r "RepositoryFactory" Molten --include="*.swift" -l

# Count should be exactly 1 (the file itself):
grep -r "RepositoryFactory" Molten --include="*.swift" -l | wc -l
```

### Remove Static Mutables from RepositoryFactory

**Option A: Delete entire file**
```bash
git rm Molten/Sources/App/Factories/RepositoryFactory.swift
```

**Option B: Keep file but gut it (for backward compat during transition)**
```swift
// RepositoryFactory.swift - DEPRECATED, use AppDependencies
@available(*, deprecated, message: "Use AppDependencies instead")
final class RepositoryFactory {
    // Empty - all methods removed
}
```

### Update CLAUDE.md

Remove references to RepositoryFactory, update with AppDependencies pattern.

### Verification

```bash
# Build
xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' build

# All tests
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17'

# Check for Swift 6 warnings (should be 0 nonisolated(unsafe)):
xcodebuild -project Molten.xcodeproj -scheme Molten build 2>&1 | grep "nonisolated"
```

### Final Commit

```bash
git add -A
git commit -m "refactor(di): complete migration - remove RepositoryFactory

Phase 5 complete:
- Deleted RepositoryFactory.swift (960 lines removed)
- Zero nonisolated(unsafe) warnings
- All services use AppDependencies DI container
- Swift 6 strict concurrency compliant

Migration stats:
- Files modified: ~195
- Lines changed: ~800
- Static mutables removed: 19
- Build: ✅ SUCCESS
- Tests: ✅ ALL PASSING"
```

---

## Quick Reference

### Current Phase Status

| Phase | Status | Files Modified | Commit |
|-------|--------|----------------|--------|
| 0: Foundation | ✅ COMPLETE | 2 | YES |
| 1: MoltenApp | ✅ COMPLETE | 1 | YES |
| 2: High-Traffic Views | ⏳ PENDING | ~60 | NO |
| 3: Remaining Sources | ⏳ PENDING | ~40 | NO |
| 4: Tests | ⏳ PENDING | ~100 | NO |
| 5: Cleanup | ⏳ PENDING | 1-2 | NO |

### Key Commands

**Check remaining work:**
```bash
grep -r "RepositoryFactory\.create" Molten/Sources --include="*.swift" | wc -l
grep -r "RepositoryFactory" Molten/Tests --include="*.swift" | wc -l
```

**Build:**
```bash
xcodebuild -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Test:**
```bash
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Files Under Active Development (Don't Touch)

**Update this list as user reports conflicts:**
- (None reported yet)

### Blocked Items

**Current blockers:**
- None

### Notes

- AppDependencies is @MainActor isolated (thread-safe)
- Uses @Observable for SwiftUI reactivity
- PersistenceController must be initialized before AppDependencies
- Tests use `AppDependencies(forTesting: true)` for mocks
