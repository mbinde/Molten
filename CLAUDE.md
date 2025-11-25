# CLAUDE.md

Technical reference for working with the Molten codebase.

---

## Project Overview

**Molten** is a SwiftUI iOS app for managing glass art studios. It handles:
- **Catalog**: 2,500+ glass items (rods, tubes, frits) with manufacturer data, COE ratings, specs
- **Inventory**: Multi-location stock tracking with quantities, storage locations
- **Purchases**: Purchase history with line items, vendors, dates
- **Projects**: Project planning and execution logs (project plans, steps, logbook entries)
- **Shopping**: Shopping lists with minimums, low-stock alerts
- **Kiln Schedules**: Custom firing schedules with segments

**Tech Stack**: SwiftUI, Core Data + CloudKit, Swift 6 strict concurrency, dependency injection via Repository pattern.

---

## 🔴 TDD is MANDATORY

**Write tests FIRST, then implement. No exceptions.**

1. New feature or bug fix? → Write failing test
2. Run test → Verify it fails for the right reason
3. Write minimum code to pass test
4. Refactor if needed, tests still pass
5. Uncertain if TDD applies? → ASK before skipping

**Test Locations**:
- Unit tests (mocks only): `Molten/Tests/MoltenTests/`
- Core Data integration: `Molten/Tests/RepositoryTests/`
- UI tests: `Molten/Tests/MoltenUITests/`

---

## Architecture: 3-Layer Clean Architecture

### The Golden Rule
**"Business logic lives in Models. Services orchestrate. Repositories persist."**

### Layers

**1. Models** (`Molten/Sources/Models/`)
- Business rules, validation, calculations
- Domain entities: `GlassItemModel`, `InventoryModel`, `PurchaseRecordModel`
- NO dependencies on Services or Repositories

**2. Services** (`Molten/Sources/Services/`)
- Orchestrate repository operations
- Async/await coordination
- NO business logic (delegate to models)
- Examples: `CatalogService`, `InventoryTrackingService`, `ShoppingListService`

**3. Repositories** (`Molten/Sources/Repositories/`)
- Persistence layer (Core Data, FileSystem, Mock)
- CRUD operations only
- NO business logic

**4. Views** (`Molten/Sources/Views/`)
- SwiftUI views organized by feature
- ViewModels for presentation logic (use protocols for testability)
- Feature structure: `[Feature]/`, `[Feature]/Components/`, `[Feature]/ViewModels/`

---

## Core Data: Two-Store Architecture (CRITICAL)

**The app MUST use two separate persistent stores to prevent CloudKit duplication:**

**STORE 1: Local Store (No CloudKit)**
- `GlassItem` - Catalog data (shipped with app, identical for all users)
- `ItemTags` - Catalog metadata
- Parent: `Item`

**STORE 2: Cloud Store (CloudKit Sync)**
- `Inventory` - User's stock
- `PurchaseRecord/PurchaseRecordItem` - Purchase history
- `Project*` - Project planning entities
- `Logbook*` - Project logs
- `KilnScheduleEntity/KilnSegmentEntity` - User kiln schedules
- `Location`, `Store` - User locations
- `ItemShopping`, `ItemMinimum` - Shopping data

**Why?** Catalog data is identical for all users. If it syncs via CloudKit:
- Device A uploads 2,659 catalog items
- Device B downloads 2,659 catalog items
- Device B now has 5,318+ duplicates (2,659 local + 2,659 from CloudKit)

**Cross-Store References**: Use **string-based lookups** (`stable_id`), NOT CoreData relationships.

**CloudKit Rules**:
1. NEVER manually purge persistent history (breaks CloudKit sync state)
2. ALWAYS use `automaticallyMergesChangesFromParent = true`
3. NEVER create Transformable attributes (causes CloudKit conflicts)
4. Let CloudKit manage its own history tokens

**🛡️ Runtime Enforcement** (`CoreDataSafetyGuards.swift`):
```swift
// DEBUG builds crash if you try to delete history
#if DEBUG
extension NSPersistentContainer {
    @MainActor
    func safeExecute(_ request: NSPersistentStoreRequest,
                     with context: NSManagedObjectContext) throws -> NSPersistentStoreResult {
        // Detect persistent history deletion attempts
        if request is NSPersistentHistoryChangeRequest {
            let requestDescription = String(describing: request)
            if requestDescription.contains("deleteHistory") {
                fatalError("""
                    ❌ FATAL: Attempted to delete persistent history - this BREAKS CloudKit sync!

                    CloudKit sync relies on persistent history to track changes across devices.
                    Manually purging history destroys sync state and causes:
                    - Data duplication (CloudKit re-imports already-synced data)
                    - Data loss (local changes never sync to cloud)
                    - Sync conflicts (mismatched history tokens)

                    NEVER call:
                    - NSPersistentHistoryChangeRequest.deleteHistory(before:)
                    - context.execute(deleteHistoryRequest)

                    Let CloudKit manage its own history tokens.
                    """)
            }
        }
        return try context.execute(request)
    }
}
#endif
```

This makes the mistake **impossible to ship** - it will crash during development if anyone tries to purge history.

**Detection Method**: While `NSPersistentHistoryChangeRequest` doesn't expose a public `requestType` property, we can detect deletion attempts by examining the request's string representation. Requests created via `deleteHistory(before:)` will contain "deleteHistory" in their description.

**🚨 CRITICAL: Tests MUST Use Two-Store Architecture**

**THE PROBLEM**: The Core Data model has entities **explicitly assigned** to "Local" and "Cloud" configurations:
- **Local configuration**: GlassItem, CoatingItem, ToolItem, ItemTags, ItemRating (catalog data)
- **Cloud configuration**: Project, Inventory, PurchaseRecord, KilnScheduleEntity, UserTags, UserNotes (user data)

When entities are explicitly assigned to configurations, Core Data **cannot use a single store** with `configuration = nil`. Attempting this causes zombie object crashes in `NSRelationshipDescription.description` when the model layer deallocates due to configuration mismatch.

**THE FIX** (`Persistence.swift`): Tests MUST create two separate in-memory stores, just like production:

```swift
if inMemory {
    // TWO-STORE ARCHITECTURE for tests (same as production)
    // The Core Data model has entities explicitly assigned to "Local" and "Cloud" configurations
    // Tests MUST use two stores to match production, otherwise Core Data crashes with configuration mismatch

    // STORE 1: Local (in-memory)
    let localDescription = NSPersistentStoreDescription()
    localDescription.url = URL(fileURLWithPath: "/dev/null")
    localDescription.configuration = "Local"

    // STORE 2: Cloud (in-memory)
    let cloudDescription = NSPersistentStoreDescription()
    cloudDescription.url = URL(fileURLWithPath: "/dev/null")
    cloudDescription.configuration = "Cloud"

    // Set both store descriptions
    container.persistentStoreDescriptions = [localDescription, cloudDescription]
    loadStoresSynchronously()
}
```

Then in `loadStoresSynchronously()`, create **separate contexts for each store**:
```swift
// Create separate contexts for local and cloud stores (same as production)
let local = container.newBackgroundContext()
local.automaticallyMergesChangesFromParent = true
local.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

let cloud = container.newBackgroundContext()
cloud.automaticallyMergesChangesFromParent = true
cloud.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

stateLock.withLock {
    $0.localContext = local
    $0.cloudContext = cloud
}
```

**Why this works**:
- Entities assigned to "Local" configuration can ONLY be accessed through a store with `configuration = "Local"`
- Entities assigned to "Cloud" configuration can ONLY be accessed through a store with `configuration = "Cloud"`
- Setting `configuration = nil` does NOT work when entities are explicitly assigned to configurations
- Tests must mirror production's two-store architecture to access all entities

**Red herrings that DON'T fix this**:
- Setting `configuration = nil` (doesn't work when entities are explicitly assigned)
- Using a single in-memory store (Core Data requires matching store configurations)
- Storing PersistenceController/contexts as properties (already required, but not the issue)

---

## Dependency Injection Pattern

**Use `AppDependencies` for all service and repository access:**

```swift
// Production (Core Data) - automatically configured
let dependencies = AppDependencies()

// Testing (Mocks, isolated from Core Data)
let dependencies = AppDependencies(forTesting: true)

// Access services
let catalogService = dependencies.catalogService
let inventoryService = dependencies.inventoryTrackingService
```

**CRITICAL**: `AppDependencies.shared` auto-detects test environment and provides appropriate implementations (mocks for tests, Core Data for production).

---

## 🚨 CRITICAL: Service Creation Anti-Pattern

**THE PROBLEM**: SwiftUI views are **value types** that get recreated on parent state changes. Creating services in `.onAppear`/`.task` creates multiple Core Data contexts → `_dispatch_assert_queue_fail` crash.

**❌ WRONG**:
```swift
struct MyView: View {
    @State private var service: MyService?

    var body: some View {
        Text("Content")
            .task {
                // ❌ Creates NEW service on every view recreation
                if service == nil {
                    service = AppDependencies.shared.catalogService
                }
            }
    }
}
```

**✅ CORRECT (Option 1 - Traditional Pattern)**:
```swift
struct MyView: View {
    private let service: MyService  // NOT @State, NOT optional

    init(service: MyService = AppDependencies.shared.catalogService) {
        self.service = service  // Default parameter evaluated ONCE
    }

    var body: some View {
        Text("Content")
            .task { await loadData() }  // ✅ Use service, never create
    }
}
```

**✅ CORRECT (Option 2 - Property Wrapper Enforcement)**:
```swift
struct MyView: View {
    @Service var catalog = AppDependencies.shared.catalogService

    var body: some View {
        Text("Content")
            .task { await loadData() }  // ✅ Use service, never create
    }

    func loadData() async {
        let items = try? await catalog.fetchAllItems()
    }
}
```

The `@Service` property wrapper (defined in `CoreDataSafetyGuards.swift`) uses `@autoclosure` to evaluate the service creation expression **exactly once** during property initialization. This makes it **impossible** to create services in `.task` - the wrapper enforces single creation at compile-time.

**Rule**: Create services in `init()` with default parameters OR use `@Service` property wrapper. Both ensure single creation.

### 🚨 SAME ANTI-PATTERN APPLIES TO TESTS!

**THE PROBLEM IN TESTS**: Test helper methods that create `AppDependencies`, extract services, then return those services cause the **EXACT SAME BUG**. When the helper method returns, `AppDependencies` and `PersistenceController` get deallocated, leaving services with **zombie Core Data objects** → intermittent `objc_msgSend` crashes in `NSRelationshipDescription`.

**❌ WRONG (Test Anti-Pattern)**:
```swift
@Suite("My Tests")
struct MyTests {
    func createTestService() -> MyService {
        let deps = AppDependencies(persistenceController: .createTestController())
        return deps.myService  // ❌ deps deallocates → zombie Core Data objects!
    }

    @Test func testSomething() async throws {
        let service = createTestService()  // Gets service with zombie objects
        try await service.doSomething()    // ❌ CRASH (intermittent, ARC timing-dependent)
    }
}
```

**✅ CORRECT (Test Pattern)**:
```swift
@Suite("My Tests")
struct MyTests {
    // ✅ Store AppDependencies at struct level (lives for entire test suite)
    private let deps = AppDependencies(persistenceController: .createTestController())

    private var testService: MyService {
        deps.myService  // ✅ PersistenceController stays alive
    }

    @Test func testSomething() async throws {
        let service = testService  // ✅ No crash - Core Data objects still valid
        try await service.doSomething()
    }
}
```

**Why This Matters**: This bug caused intermittent Core Data crashes that only appeared after multiple builds (memory reuse patterns). Clearing DerivedData would fix it temporarily because it reset the memory allocator. The crash was in Apple's Core Data framework (`NSRelationshipDescription.description`), making it extremely difficult to diagnose without understanding the ARC lifecycle issue.

---

## Swift 6 Concurrency

**Key Patterns**:
- Models are `Sendable` for safe cross-actor usage
- Use `nonisolated` for static methods and computed properties that don't need actor isolation
- Services and repositories handle async/await operations
- Clean actor boundaries via repository pattern

**Common Issues**:
- `nonisolated struct` is INVALID syntax - remove `nonisolated` from struct declarations
- Use `nonisolated` on methods/properties, not types
- See `Molten/Docs/Swift6-Concurrency-Guide.md` for detailed patterns

---

## Build & Test Commands

**NOTE**: If you encounter mysterious Core Data crashes (`NSRelationshipDescription`, `objc_msgSend`) that don't make sense given the code has been stable, the issue is likely stale Derived Data. Aggressively delete ALL Derived Data directories: `sudo rm -rf ~/Library/Developer/Xcode/DerivedData/Molten-*` and clean build.

### Build
```bash
xcodebuild -project Molten.xcodeproj -scheme Molten -configuration Debug build
```

### Run Tests
```bash
# All tests
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15'

# Unit tests only (fast, mocks)
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 15'

# Repository tests (Core Data integration)
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan RepositoryTests -destination 'platform=iOS Simulator,name=iPhone 15'

# Single test
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MoltenTests/TestClassName/testMethodName
```

---

## Testing Strategy

**Testing Pyramid** (70% unit, 20% integration, 10% UI):

**Unit Tests** (`MoltenTests/`)
- ViewModels, Models, Services, Utilities
- Use mocks only, never Core Data
- Use `AppDependencies(forTesting: true)` or `AppDependencies.shared` (auto-detects tests)
- Use `TestDataBuilder` for consistent test scenarios

**Integration Tests** (`RepositoryTests/`)
- Core Data repositories, persistence, migrations
- Use `PersistenceController.createTestController()` for isolated Core Data contexts
- **ALWAYS verify Core Data schema before writing tests**:
  ```bash
  cat Molten/Molten.xcdatamodeld/.xccurrentversion
  grep "entity name=" Molten/Molten.xcdatamodeld/Molten\ XX.xcdatamodel/contents
  ```

**UI Tests** (`MoltenUITests/`)
- Critical user journeys only
- Use accessibility identifiers: `feature.element[.specifics]`
- Keep this layer thin

**TestDataBuilder** - Use for consistent test scenarios:
```swift
let builder = try await TestDataBuilder()
    .withScenario(.inventoryWithLowStock)
    .build()
```

---

## Key Design Patterns

- **Service Coordination**: Services expose repositories for advanced operations
- **Batch Operations**: Fetch inventory in bulk to avoid N+1 queries
- **Complete Models**: `CompleteInventoryItemModel` aggregates data from multiple repositories
- **Natural Keys**: Glass items use `manufacturer-sku-variant` format (e.g., "bullseye-001-0")
- **Manufacturer Storage**: Abbreviations ("be", "cim", "ef"), not full names
- **Protocol-Based ViewModels**: For testability (see `Molten/Docs/ViewModel-Protocol-Pattern.md`)

---

## 🎨 Design System (MANDATORY)

**All UI code MUST use the design system. No exceptions.**

### Color Rules

**NEVER use raw SwiftUI colors in Views:**
```swift
// ❌ WRONG - These are violations
Color.red
Color.orange
Color.green
Color.blue
Color.yellow
Color.purple
Color.pink
Color.cyan

// ✅ CORRECT - Use design system
DesignSystem.Colors.accentDanger      // instead of Color.red
DesignSystem.Colors.accentWarning     // instead of Color.orange/yellow
DesignSystem.Colors.accentSuccess     // instead of Color.green
DesignSystem.Colors.accentSecondary   // instead of Color.blue
DesignSystem.Colors.accentUser        // instead of Color.purple

// ✅ ALSO CORRECT - Use Color.molten* extensions
Color.moltenOrange   // primary brand
Color.moltenAmber    // warnings, low stock
Color.moltenTeal     // links, success, in-stock
Color.moltenDanger   // errors, destructive
Color.moltenUser     // user-created content
```

### Detect Violations

Run this command to find color violations:
```bash
grep -r "Color\.\(red\|blue\|green\|orange\|yellow\|purple\|pink\|cyan\)" Molten/Sources/Views/
```

**If this returns results, those are bugs that need fixing.**

### Brand Colors ("Luminous Precision" Palette)

| Name | Hex | Usage |
|------|-----|-------|
| Molten Orange | `#FF5722` | Primary actions, active states, tint color |
| Warm Amber | `#FFC107` | Warnings, low-stock indicators |
| Slate Teal | `#00796B` | Links, success, in-stock counts |
| Charcoal | `#212121` | Primary text |
| Off-White Ash | `#F8F9FA` | Backgrounds |

### Typography, Spacing, Corners

Always use `DesignSystem.*` constants:
```swift
// Typography
DesignSystem.Typography.pageTitle
DesignSystem.Typography.sectionHeader
DesignSystem.Typography.rowTitle
DesignSystem.Typography.caption

// Spacing
DesignSystem.Spacing.xs   // 4pt
DesignSystem.Spacing.sm   // 6pt
DesignSystem.Spacing.md   // 8pt (most common)
DesignSystem.Spacing.lg   // 12pt
DesignSystem.Spacing.xl   // 16pt

// Corner Radius
DesignSystem.CornerRadius.small   // 4pt
DesignSystem.CornerRadius.medium  // 8pt (most common)
DesignSystem.CornerRadius.large   // 10pt
```

### Reference

- **Design system file**: `Molten/Sources/Utilities/DesignSystem.swift`
- **Design notes**: `design-notes/DESIGN-ANALYSIS.md`

---

## File Organization

```
Molten/
├── Sources/
│   ├── App/          # MoltenApp, Factories, Configuration
│   ├── Models/       # Domain (business logic), Helpers
│   ├── Services/     # Core, DataLoading, Coordination
│   ├── Repositories/ # Protocols, CoreData, FileSystem, Mock
│   ├── Views/        # Catalog, Inventory, Purchases, ProjectLog, Settings, Shared
│   └── Utilities/    # Cross-cutting utilities
├── Tests/
│   ├── MoltenTests/       # Unit tests (mocks only)
│   ├── RepositoryTests/   # Core Data integration tests
│   └── MoltenUITests/     # UI automation tests
└── Docs/
    ├── Swift6-Concurrency-Guide.md        # Concurrency patterns
    ├── SwiftUI-View-Lifecycle-Guide.md    # View lifecycle best practices
    └── ViewModel-Protocol-Pattern.md      # ViewModel testability
```

---

## Common Pitfalls

1. **Service creation in `.onAppear`/`.task`** → Crashes (see anti-pattern above)
2. **Business logic in Services** → Belongs in Models
3. **Not using AppDependencies** → Create dependencies in init, not in view lifecycle
4. **N+1 queries** → Batch fetch inventory
5. **Manual Core Data files** → Use Xcode's automatic code generation only
6. **Skipping TDD** → Write tests first, always
7. **Creating Transformable attributes** → Breaks CloudKit sync
8. **Purging persistent history** → Breaks CloudKit sync state
9. **Cross-store CoreData relationships** → Use string-based lookups (`stable_id`)
10. **Assuming Core Data schema** → Verify entity names/attributes before writing tests

---

## Important Files

- **`MoltenApp.swift`**: App entry point, creates and provides `AppDependencies`
- **`AppDependencies.swift`**: Dependency injection container (replaces old RepositoryFactory pattern)
- **`Persistence.swift`**: Core Data stack with two-store architecture, CloudKit, migration recovery
- **`CompleteInventoryItemModel`**: Aggregates glass item + inventory + tags
- **`TestDataBuilder.swift`**: Fluent API for creating test scenarios

---

## Debugging

**EXC_BREAKPOINT (code=1)** = Swift hit a fatal error:
1. Check Xcode console for error message before crash
2. Search: `grep -r "fatalError\|preconditionFailure" Sources/`
3. Add breakpoint on "All Exceptions" in Xcode
4. Check for invalid `nonisolated struct` syntax (should be `nonisolated` on methods, not structs)

**Common Crashes**:
- Multiple Core Data contexts → Service creation anti-pattern (see above)
- Force unwrapping nil → Check `!` operators
- Array/dictionary bounds → Check index access

---

## Logging and Error Tracking

**Use the unified logging system for all error tracking:**

```swift
struct MyService {
    private let logger: LoggingService

    init(logger: LoggingService = AppDependencies.shared.loggingService) {
        self.logger = logger
    }

    func doSomething() async throws {
        logger.info("Starting operation", context: ["operation": "my-operation"])

        do {
            try await riskyOperation()
        } catch {
            // Log with context for pattern detection in Sentry
            logger.error("Operation failed", context: [
                "operation": "my-operation",
                "retry_count": 3
            ], error: error)
            throw error
        }
    }
}
```

**Log Levels**:
- `.debug` - Detailed debugging (local only)
- `.info` - General information (local only)
- `.warning` - Potential issues (local only)
- `.error` - Errors needing attention (sent to Sentry)
- `.critical` - Critical failures (sent to Sentry)

**Pattern Detection**: Use consistent `operation` keys in context:
- `operation:catalog-download` - Track catalog download failures
- `operation:rating-cache-rebuild` - Track rating cache issues
- `operation:cloudkit-sync` - Track CloudKit sync problems

**Automatic Features**:
- Logs to OSLog (local) and Sentry (remote errors only)
- Filters sensitive data (passwords, emails, tokens)
- Captures breadcrumbs (user actions leading to errors)
- Auto-detects test environment (uses MockLogger)
- Enriches errors with app version, device info, memory usage

See `Molten/Docs/Logging-and-Error-Tracking.md` for complete setup and usage.

---

## Additional Documentation

For detailed guidance on specific topics, see:
- `Molten/Docs/Logging-and-Error-Tracking.md` - Sentry setup, pattern detection, alerting
- `Molten/Docs/Swift6-Concurrency-Guide.md` - Concurrency patterns and diagnostics
- `Molten/Docs/SwiftUI-View-Lifecycle-Guide.md` - View lifecycle patterns
- `Molten/Docs/ViewModel-Protocol-Pattern.md` - Protocol-based ViewModels for testability
- `Molten/Docs/Transformable-Attributes-Review.md` - Core Data anti-patterns

---

## Adding New Tests Workflow

**Claude's workflow**:
1. Create test files in `Molten/Tests/MoltenTests/` (or `RepositoryTests/`, `MoltenUITests/`)
2. Commit: `git add Molten/Tests/MoltenTests/YourTests.swift && git commit -m "test: add YourTests"`
3. Tell user: "Created N new test files - ready to add to Xcode"

**User's workflow**:
1. Right-click project root in Xcode → "Add Files to Molten..."
2. Select entire `Molten/Tests` folder
3. Choose "Create groups", select correct target (MoltenTests/RepositoryTests/MoltenUITests)
4. Xcode adds only new files, preserves structure
5. Commit: `git add Molten.xcodeproj/project.pbxproj && git commit -m "chore: add test files to Xcode"`
6. **Verify**: `xcodebuild build-for-testing` to catch missing mocks/dependencies
7. Clean build: Product → Clean Build Folder (⇧⌘K)
