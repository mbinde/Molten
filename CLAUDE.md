# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## ⚠️ STOP: Before Writing ANY Code

**Test-Driven Development (TDD) is MANDATORY for this project.**

1. **Is this a new feature or bug fix?** → Write the test FIRST (TDD)
2. **Does a test already exist?** → Run it to see current behavior
3. **Think TDD might not apply?** → ASK THE USER before proceeding without tests
4. **Only then** write/modify implementation code

**Never write implementation code before tests unless explicitly told to skip TDD.**

---

## Project Overview

Molten is a SwiftUI iOS app for managing glass art inventory. It tracks glass items (rods, tubes, frits) with their manufacturers, COE ratings, inventory quantities, locations, and purchase records. The app uses Core Data with CloudKit for persistence and follows a clean architecture with repository pattern.

## Build & Test Commands

### Building
```bash
# Build the main app
xcodebuild -project Molten.xcodeproj -scheme Molten -configuration Debug build

# Build for simulator
xcodebuild -project Molten.xcodeproj -scheme Molten -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test plans
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan RepositoryTests -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -project Molten.xcodeproj -scheme Molten -testPlan UITests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run a single test
xcodebuild test -project Molten.xcodeproj -scheme Molten -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:MoltenTests/TestClassName/testMethodName
```

### Test Targets
- **MoltenTests**: Unit tests for business logic, services, and utilities
  - **MUST use mocks only** - Never touches Core Data
  - Tests should use `RepositoryFactory.configureForTesting()`
  - Fast, isolated tests that don't require persistence
- **RepositoryTests**: Repository layer tests (Core Data operations)
  - **Tests Core Data implementations directly**
  - Uses `RepositoryFactory.configureForTestingWithCoreData()` with isolated test controllers
  - Tests persistence, migrations, and Core Data-specific behavior
- **PerformanceTests**: Performance and load testing
- **MoltenUITests**: UI automation tests

### Debugging Common Crashes

**EXC_BREAKPOINT (code=1)**

This is NOT a user-set breakpoint - it's Swift hitting a fatal error in your code.

Common causes:
1. **`fatalError()` or `preconditionFailure()`** - Search codebase for these calls
2. **Invalid `nonisolated struct` syntax** - Remove `nonisolated` from struct declarations
3. **Force unwrapping nil** - Check for `!` operators on optionals
4. **Array/Dictionary out of bounds** - Check index access

**How to debug:**
1. Check the Xcode console for the actual error message before the crash
2. Use `grep -r "fatalError\|preconditionFailure" Sources/` to find fatal errors
3. Look at the call stack in Xcode to see which function triggered it
4. Add breakpoints on "All Exceptions" in Xcode to catch it earlier

**Example:** If you see `EXC_BREAKPOINT` with logs about "Missing stable_id", that's a `fatalError()` being hit in `CoreDataGlassItemRepository.swift`.

## Architecture Overview

### 🎯 THE GOLDEN RULE
**"Business logic lives in the Model layer. Services orchestrate. Repositories persist."**

This project follows strict **3-Layer Clean Architecture** with TDD (Test-Driven Development):

### Layer Structure

**Layer 1: Models (Domain/Business Logic)**
- Business rules applied during construction
- Data validation and normalization
- Change detection logic
- Domain-specific behavior
- Location: `Molten/Sources/Models/`
  - **Domain/**: Core business entities with embedded logic (`GlassItemModel`, `InventoryModel`, `WeightUnit`)
  - **Helpers/**: Supporting utilities for business rules (`CatalogItemHelpers`)

**Layer 2: Services (Application/Orchestration)**
- Coordinate repository operations
- Handle async/await patterns
- Cross-entity coordination
- Application-level business flows
- **NO business logic** (delegates to models)
- Location: `Molten/Sources/Services/`
  - **Core/**: Primary services (`CatalogService`, `InventoryTrackingService`, `ShoppingListService`, `PurchaseRecordService`)
  - **DataLoading/**: Data import services (`GlassItemDataLoadingService`, `JSONDataLoader`)
  - **Coordination/**: Cross-entity coordination (`EntityCoordinator`, `ReportingService`)

**Layer 3: Repositories (Infrastructure/Persistence)**
- Data storage/retrieval
- Technology-specific implementations (Core Data, Mock, FileSystem)
- Context and transaction management
- **NO business logic**
- Location: `Molten/Sources/Repositories/`
  - **Protocols/**: Repository interfaces for dependency injection (`GlassItemRepository`, `InventoryRepository`, `LocationRepository`, `UserImageRepository`)
  - **CoreData/**: Core Data implementations (production)
  - **FileSystem/**: File system implementations (for images and file-based storage)
  - **Mock/**: Test doubles for unit testing

**Views Layer** (SwiftUI Interface)
- SwiftUI views organized by feature: Catalog, Inventory, Purchases, ProjectLog, Settings
- Feature-based organization with consistent subdirectory patterns
- Location: `Molten/Sources/Views/`
  - Each feature: Main views + Components/ + ViewModels/ + Helpers/ + Debug/
  - **Shared/**: Cross-feature reusable components

**App Layer** (Infrastructure)
- App entry point (`MoltenApp.swift`)
- App-wide configuration, navigation, dependency injection
- Location: `Molten/Sources/App/`
  - **Factories/**: Dependency injection factories (`RepositoryFactory`, `CatalogViewFactory`)
  - **Configuration/**: App-wide settings and feature flags (`DebugConfig`)

**Utilities** (Cross-Cutting Concerns)
- Generic utilities used across multiple features
- Pure utility functions (formatting, validation, extensions)
- Could be extracted to separate package
- Location: `Molten/Sources/Utilities/`

### Repository Pattern & Factory

The app uses `RepositoryFactory` to switch between Mock and Core Data implementations:

```swift
// Configure for production (uses Core Data)
RepositoryFactory.configureForProduction()

// Configure for testing (uses mocks, isolated from Core Data)
RepositoryFactory.configureForTesting()

// Create services
let catalogService = RepositoryFactory.createCatalogService()
let inventoryService = RepositoryFactory.createInventoryTrackingService()
```

**CRITICAL**: `RepositoryFactory.mode` defaults to `.mock` to prevent tests from polluting production Core Data. Production code must explicitly call `configureForProduction()` or `configureForDevelopment()`.

### Core Data Model

The app uses a versioned Core Data model (`Molten.xcdatamodeld`) with multiple versions. The current model includes entities for:
- CatalogItem (glass items with manufacturer, SKU, COE)
- Inventory records (quantity, type)
- Location tracking (where items are stored)
- Purchase records

**Model Management**:
- Uses `PersistenceController.shared` for production data
- Includes automatic migration recovery for model changes
- Entity resolution is validated at startup to catch issues early
- **❌ NEVER CREATE MANUAL CORE DATA FILES** - Uses Xcode's automatic code generation to avoid "Multiple commands produce" build conflicts

**⚠️ CRITICAL: Avoid Transformable Attributes**:
- **DO NOT** create new Transformable attributes in Core Data entities
- Transformable attributes cause CloudKit sync conflicts (cannot merge binary blobs)
- Transformable attributes hurt performance (full serialization/deserialization on every access)
- **Instead**, use proper Core Data relationships with dedicated entities
- **Example**: Instead of `tags: Transformable` storing `[String]`, create a `ProjectTag` entity with a many-to-many relationship
- **See**: `Molten/Docs/Transformable-Attributes-Review.md` for detailed analysis and migration strategy
- **Known Legacy Issues**: ProjectLog, ProjectPlan, and ProjectStep entities have Transformable attributes that need refactoring

### Key Design Patterns

- **Service Coordination**: Services expose repositories for advanced operations
- **Batch Operations**: Fetch inventory in bulk to avoid N+1 queries
- **Complete Models**: `CompleteInventoryItemModel` aggregates data from multiple repositories
- **Natural Keys**: Glass items use keys like "bullseye-clear-001" (format: `manufacturer-sku-variant`)
- **Manufacturer Storage**: Stored as abbreviations ("be", "cim", "ef"), not full names

### User Image Upload System

Users can upload custom photos for glass items. Images stored locally in Application Support directory as JPEG files. Uses `FileSystemUserImageRepository` (production) or `MockUserImageRepository` (testing).

**Key Points**:
- Images: `~/Library/Application Support/UserImages/` (backed up to iCloud)
- Metadata: UserDefaults (`molten.userImages.metadata`)
- Loading priority: User image → Bundle image → Manufacturer default
- **Multi-device**: Images backed up to iCloud but NOT synced via CloudKit across active devices
- Requires photo library and camera permissions in Info.plist

## Development Workflow

### 🔴 TDD (Test-Driven Development) - MANDATORY FOR ALL CODE CHANGES

**When to use TDD:**
- ✅ Adding new features (always)
- ✅ Fixing bugs (always)
- ✅ Refactoring existing code (always)
- ✅ Adding new methods to existing classes (always)
- ⚠️ **Uncertain if TDD applies?** → ASK THE USER before skipping

**The TDD Cycle (never skip a step):**

1. **🔴 RED**: Write a failing test that describes the desired behavior
   - Test location: `Tests/MoltenTests/` (unit tests with mocks) or `Tests/RepositoryTests/` (Core Data integration)
   - Run test → verify it fails for the right reason

2. **🟢 GREEN**: Write the simplest code that makes the test pass
   - Implement in appropriate layer (Model/Service/Repository)
   - Run test → verify it passes

3. **🔵 REFACTOR**: Improve code quality without changing behavior
   - Clean up implementation
   - Run test again → verify still passes

**Architecture Verification (during refactor step):**
- ✅ Business logic in models
- ✅ Services orchestrate operations
- ✅ Repositories handle persistence
- ✅ No cross-layer logic duplication

### Adding New Features

**🔴 TDD Checklist (complete BEFORE writing implementation):**
- [ ] Write failing test in `Tests/MoltenTests/` or `Tests/RepositoryTests/`
- [ ] Run test → confirm it fails for the right reason
- [ ] Implement minimum code to make test pass
- [ ] Run test → confirm it passes
- [ ] Refactor code if needed
- [ ] Run test again → confirm still passes

**Then follow this architecture order:**

1. **Define Domain Model** in `Models/Domain/`
   - Include business rules and validation in the model
   - Add helper utilities in `Models/Helpers/` if needed

3. **Update Repository Protocol** in `Repositories/Protocols/`
   - Define required methods for data operations

4. **Implement Repository** in both locations:
   - `Repositories/Mock/` for testing
   - `Repositories/CoreData/` for production

5. **Add Service Logic** in appropriate service
   - Services orchestrate, they don't contain business logic
   - Delegate business rules to models

6. **Create Views** in `Views/[Feature]/`
   - Follow feature-based organization
   - Extract reusable components to `Components/` subdirectory

### File Placement Decision Tree

When creating a new file, ask these questions in order:

1. **Is this a SwiftUI view struct?**
   - Reused within feature? → `Views/[Feature]/Components/`
   - Not reused? → `Views/[Feature]/` (main directory)
   - Used across features? → `Views/Shared/Components/`

2. **Is this an ObservableObject managing view state?**
   - → `Views/[Feature]/ViewModels/`

3. **Is this non-UI logic supporting feature views?**
   - → `Views/[Feature]/Helpers/`

4. **Is this domain logic or business rules?**
   - → `Models/Domain/` or `Models/Helpers/`

5. **Is this a cross-cutting utility (search, validation, formatting)?**
   - → `Utilities/`

6. **Does this orchestrate repository operations?**
   - → `Services/Core/` or `Services/Coordination/`

7. **Does this handle data persistence?**
   - → `Repositories/CoreData/` or `Repositories/Mock/`

8. **Is this app-wide configuration or dependency injection?**
   - → `App/Factories/` or `App/Configuration/`

### Testing Guidelines

- **Always use `RepositoryFactory.configureForTesting()`** in test setup to use mocks
- For Core Data tests, use `RepositoryFactory.configureForTestingWithCoreData()` with isolated controller
- Create test controllers with `PersistenceController.createTestController()` for isolation
- Tests should be independent and not share state
- Use Swift Testing with `#expect()` assertions
- Test async/await patterns throughout

### Creating New Tests - Workflow

1. Create test files in final destination: `Tests/MoltenTests/` (unit) or `Tests/RepositoryTests/` (Core Data)
2. Pause for user to add files to Xcode project
3. Run tests after confirmation

### Core Data Migrations

When changing the Core Data model:
1. Create a new model version in Xcode (Editor > Add Model Version)
2. Update `.xccurrentversion` to point to new version
3. Test migration path from previous version
4. App includes automatic recovery for migration failures (deletes and recreates store)

### Common Pitfalls

1. **Don't forget to configure RepositoryFactory** - Views will fail silently if using wrong mode
2. **Never put business logic in Services** - Business rules belong in Models; Services only orchestrate
3. **Batch fetch inventory** - Always fetch inventory in bulk, not per-item, to avoid performance issues
4. **Validate entity resolution** - Core Data entity resolution can fail on some devices (iPhone 17 known issue)
5. **Use natural keys consistently** - Format is `manufacturer-sku-variant` (e.g., "bullseye-clear-001")
6. **Handle Core Data migration failures** - App includes auto-recovery but test thoroughly
7. **❌ NEVER CREATE MANUAL CORE DATA FILES** - Use Xcode's automatic code generation only
8. **Follow TDD** - Write tests first, then implement (RED → GREEN → REFACTOR)
9. **🚨 CRITICAL: Service Creation Pattern** - NEVER create services in `.onAppear`/`.task` (causes `_dispatch_assert_queue_fail` crashes - see below)

### 🚨 CRITICAL: Service Creation Anti-Pattern

**THE PROBLEM**: SwiftUI view structs are **value types** that get recreated whenever parent state changes. If you create services in `.onAppear`/`.task`, you create multiple Core Data contexts accessing the same data → `_dispatch_assert_queue_fail` crash.

**❌ ANTI-PATTERN (CRASHES)**:
```swift
struct MyView: View {
    @State private var service: MyService?

    var body: some View {
        Text("Content")
            .task {
                // ❌ BAD: Creates NEW service every time view is recreated
                if service == nil {
                    service = RepositoryFactory.createService()
                }
            }
    }
}
```

**Why this crashes**:
1. View struct created → `init()` runs
2. `.task` runs → Creates Core Data context A
3. Parent state changes → View struct **recreated**
4. `.task` runs **again** → Creates Core Data context B
5. Context A + B access same data → **CRASH**

**✅ CORRECT PATTERN**:
```swift
struct MyView: View {
    private let service: MyService  // NOT optional, NOT @State

    // Default parameter evaluated ONCE per view instance
    init(service: MyService = RepositoryFactory.createService()) {
        self.service = service
    }

    var body: some View {
        Text("Content")
            .task {
                await loadData()  // ✅ Use service, never create it
            }
    }
}
```

**Why this works**: Default parameters evaluated at call time = ONE service per view instance, stable for its lifetime.

**Applies to**: All services (`CatalogService`, `InventoryTrackingService`), repositories (`UserImageRepository`), any Core Data dependencies.

**Files using this pattern**: `CatalogView`, `InventoryView`, `ShoppingListView`, `PurchasesView`, `LogbookView`, `AddLogbookEntryView`, `ImageHelpers.swift` (20+ files total, fixed October 2025).

### SwiftUI View Lifecycle Patterns

**🚨 CRITICAL**: If you see timing-based crashes ("crashes 10 seconds after launch", "sometimes works, sometimes crashes"), view factory methods called in `body`, or services created as stored properties:

→ See `Molten/Docs/SwiftUI-View-Lifecycle-Guide.md` for complete patterns

**Quick rules:**
- ✅ Create services with default parameters in `init()`, store as `private let`
- ✅ Cache complex views in `@State`, create in `.onAppear`
- ❌ NEVER create services in `.onAppear`/`.task`
- ❌ NEVER call factory methods directly in `body`

## File Organization

```
Molten/Sources/
├── App/          # Factories, Configuration
├── Models/       # Domain, Helpers
├── Services/     # Core, DataLoading, Coordination
├── Repositories/ # Protocols, CoreData, FileSystem, Mock
├── Views/        # Feature dirs (Catalog, Inventory, Purchases, ProjectLog, Settings, Shared)
├── Utilities/    # Cross-cutting utilities
└── Tests/        # MoltenTests, RepositoryTests, PerformanceTests, MoltenUITests
```

## Important Files

- **`MoltenApp.swift`**: App entry point, configures services
- **`RepositoryFactory.swift`**: Central factory for creating repositories and services
- **`Persistence.swift`**: Core Data stack with CloudKit and migration recovery
- **`CompleteInventoryItemModel`**: Aggregates all item data

## Swift 6 & Concurrency

This project uses Swift 6 with strict concurrency:
- **Async/await** throughout repository operations
- **Swift Testing** with `#expect()` assertions
- **Clean concurrency boundaries** via repository pattern
- **Thread-safe** service and utility implementations

**🔥 For concurrency issues (especially `nonisolated struct` errors, `@MainActor` errors, or service class concurrency):**
→ See `Molten/Docs/Swift6-Concurrency-Guide.md` for detailed patterns and diagnostics


## UI Design System

**CRITICAL**: Always use `DesignSystem` constants (in `Utilities/DesignSystem.swift`) instead of hardcoded values.

**Common values**:
- Spacing: `.md` (8pt), `.lg` (12pt), `.xl` (16pt), `.xs` (4pt)
- Padding: `.standard` (12pt), `.compact` (8pt), `.rowVertical` (8pt)
- Corner Radius: `.medium` (8pt), `.large` (10pt), `.extraLarge` (12pt)
- Colors: `.textSecondary`, `.accentPrimary`, `.backgroundSecondary`
- Typography: `.rowTitle`, `.label`, `.caption`

**Style modifiers**: `.cardStyle()`, `.chipStyle(isSelected:)`, `.searchBarStyle()`

**Reference screens**: CatalogView, InventoryView, AddInventoryItemView, PurchaseRecordDetailView

## Git Commit Guidelines

When creating git commits:
- **DO NOT** add "Generated with Claude Code" footer or "Co-Authored-By: Claude" lines to commit messages
- Write clear, concise commit messages that describe the changes
- Follow conventional commit format if applicable (e.g., "fix:", "feat:", "refactor:")
