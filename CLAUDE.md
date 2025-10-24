# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

### Data Flow & Service Orchestration

**Glass Item Creation Flow**:
1. View calls `CatalogService.createGlassItem()`
2. CatalogService delegates to `InventoryTrackingService.createCompleteItem()`
3. InventoryTrackingService coordinates:
   - `glassItemRepository.createItem()` - Creates the glass item
   - `itemTagsRepository.addTags()` - Adds tags
   - `inventoryRepository.createInventories()` - Creates inventory records
4. Returns `CompleteInventoryItemModel` with all related data

**Search Flow**:
1. View calls `CatalogService.searchGlassItems(request:)`
2. CatalogService:
   - Queries `glassItemRepository.searchItems()` for text matches
   - Applies filters (tags, manufacturers, COE, inventory status)
   - Batches inventory lookup for performance (avoids N+1 queries)
   - Sorts and paginates results
3. Returns `GlassItemSearchResult` with complete models

### Key Design Patterns

**Service Coordination**: Services expose their repositories for advanced operations (e.g., `CatalogService.inventoryRepository` allows direct inventory queries)

**Batch Operations**: Services fetch inventory in bulk and group by item natural key to avoid N+1 query problems

**Complete Models**: `CompleteInventoryItemModel` aggregates data from multiple repositories (GlassItem + Inventory + Tags + Locations)

**Natural Keys**: Glass items use natural keys like "bullseye-clear-001" instead of UUIDs for human-readable identification

**Manufacturer Storage**: Manufacturers are stored as short abbreviations (e.g., "be", "cim", "ef") NOT full names. Full names like "Bullseye Glass Co" are mapped to abbreviations in the codebase for display purposes only. The abbreviation is always extracted from the code field (e.g., "CIM-123" → manufacturer = "cim")

### User Image Upload System

Users can upload custom photos for glass items. Images stored locally in Application Support directory as JPEG files. Uses `FileSystemUserImageRepository` (production) or `MockUserImageRepository` (testing).

**Key Points**:
- Images: `~/Library/Application Support/UserImages/` (backed up to iCloud)
- Metadata: UserDefaults (`molten.userImages.metadata`)
- Loading priority: User image → Bundle image → Manufacturer default
- **Multi-device**: Images backed up to iCloud but NOT synced via CloudKit across active devices
- Requires photo library and camera permissions in Info.plist

## Development Workflow

### TDD (Test-Driven Development)
This project follows strict TDD practices:

1. **RED**: Write failing test first
2. **GREEN**: Implement simplest solution
3. **REFACTOR**: Improve without changing behavior

**Architecture Verification Checklist**:
- ✅ Business logic in models
- ✅ Services orchestrate operations
- ✅ Repositories handle persistence
- ✅ No cross-layer logic duplication

### Adding New Features

Follow this order to maintain clean architecture:

1. **Write Tests First** (TDD)
   - Write unit tests in `Tests/MoltenTests/`
   - Write repository tests in `Tests/RepositoryTests/` if needed

2. **Define Domain Model** in `Models/Domain/`
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
9. **⚠️ CACHE COMPLEX VIEWS IN @State** - Never call view factory methods directly in body (see below)

### SwiftUI View Lifecycle Patterns

**CRITICAL: Always cache complex view instances in `@State`**

❌ **WRONG** (causes "NavigationRequestObserver tried to update multiple times per frame"):
```swift
var body: some View {
    createMainTabView()  // ❌ Called on every body re-evaluation!
        .sheet(...)
}
```

✅ **CORRECT** (view created once and cached):
```swift
@State private var mainTabView: MainTabView?

var body: some View {
    if mainTabView == nil {
        Color.clear.onAppear {
            mainTabView = createMainTabView()  // ✅ Created once on MainActor
        }
    } else {
        mainTabView!
            .sheet(...)
    }
}
```

**Why this matters:**
- SwiftUI re-evaluates `body` on EVERY state change
- Direct function calls create new instances each time
- Multiple instances trigger update loops and crashes
- Caching in `@State` ensures single instance throughout lifecycle

**Real-world example from MoltenApp.swift:**
- Bug: `createMainTabView()` called twice, creating duplicate MainTabView instances
- Symptom: "Update NavigationRequestObserver tried to update multiple times per frame"
- Crash: `_dispatch_assert_queue_fail` (dispatch queue threading violation)
- Fix: Cache in `@State`, create in `.onAppear` (guaranteed MainActor)
- Debug: Added `assertionFailure` in `createMainTabView()` to detect future violations

**Pattern applies to:**
- Complex view initialization (MainTabView, feature root views)
- Service dependencies that should persist (LabelPrintingService, etc.)
- `@Observable` object creation (to avoid initialization loops)

**⚠️ CRITICAL: Service Instantiation Pattern**

Services should NEVER be created as stored properties in SwiftUI views:

❌ **WRONG** (service recreated on every body evaluation):
```swift
struct MyView: View {
    private let service = LabelPrintingService()  // ❌ New instance each time!

    var body: some View {
        // ...
    }
}
```

✅ **CORRECT** (service cached in @State):
```swift
struct MyView: View {
    @State private var service: LabelPrintingService?

    var body: some View {
        // ...
        .onAppear {
            if service == nil {
                service = LabelPrintingService()  // ✅ Created once
            }
        }
    }
}
```

**Why this matters:**
- SwiftUI structs are value types - the entire view is recreated on state changes
- Stored properties (`private let`) are re-initialized each time
- Services with heavy operations (QR code generation, PDF rendering) cause performance issues
- Multiple service instances can cause threading conflicts and dispatch queue crashes

**Real-world examples:**
- LabelDesignerView: Creating `LabelPrintingService()` on every body evaluation
- LabelPreviewView: Nested `QRCodeView` creating service in body
- Both caused `_dispatch_assert_queue_fail` crashes during PDF generation

**Fix pattern:**
1. Change `private let service = Service()` to `@State private var service: Service?`
2. Initialize in `.onAppear { if service == nil { service = Service() } }`
3. Pass service to child views as parameters instead of letting them create their own

## File Organization

```
Molten/Sources/
├── App/                    # App entry point and configuration
│   ├── Factories/          # Service factories
│   └── Configuration/      # Debug and app config
├── Models/
│   ├── Domain/             # Core business models
│   └── Helpers/            # Model utilities
├── Services/
│   ├── Core/               # Main business logic services
│   ├── DataLoading/        # Data loading from JSON
│   └── Coordination/       # Cross-service orchestration
├── Repositories/
│   ├── Protocols/          # Repository interfaces
│   ├── CoreData/           # Core Data implementations
│   ├── FileSystem/         # File system implementations (images, files)
│   └── Mock/               # Mock implementations
├── Views/                  # SwiftUI views by feature
│   ├── Catalog/            # Browse and search glass items
│   ├── Inventory/          # Manage inventory quantities
│   ├── Purchases/          # Track purchases
│   ├── ProjectLog/         # Project notes
│   ├── Settings/           # App settings
│   └── Shared/             # Reusable components
├── Utilities/              # General utilities
└── Tests/                  # All test targets
    ├── MoltenTests/        # Unit tests
    ├── RepositoryTests/    # Repository layer tests
    ├── PerformanceTests/   # Performance tests
    └── MoltenUITests/      # UI tests
```

## Important Files

- **`MoltenApp.swift`**: App entry point, configures services and handles data loading
- **`RepositoryFactory.swift`**: Central factory for creating repositories and services
- **`CatalogService.swift`**: Main service for catalog operations (orchestration only, no business logic)
- **`InventoryTrackingService.swift`**: Orchestrates inventory across multiple repositories
- **`Persistence.swift`**: Core Data stack with CloudKit and migration recovery
- **`CompleteInventoryItemModel`** (in `InventoryModels.swift`): Aggregates all item data
- **`Molten/README.md`**: Detailed architecture principles and file organization guidelines

## Why This Architecture?

- Clear file locations and reduced coupling
- Feature-based organization enables easy scaling
- Mock repositories enable fast, isolated testing
- Clean layer separation improves maintainability

## Swift 6 & Concurrency

- **Async/await** throughout repository operations
- **Swift Testing** with `#expect()` assertions
- **Clean concurrency boundaries** via repository pattern
- **Thread-safe** service and utility implementations

### 🔥 CRITICAL: Swift 6 Strict Concurrency Guide

#### Key Rules

1. **NEVER write `nonisolated struct`** - Invalid syntax, causes EXC_BREAKPOINT crashes
2. **Sendable structs are already safe** - No annotations needed on struct declaration
3. **Mark individual members** - Use `nonisolated` on init/static methods only when needed
4. **Service classes need `@preconcurrency`** - Prevents MainActor inference
5. **Test suites need `@MainActor`** - When accessing MainActor-isolated properties

#### Common Patterns

**Domain Models (Structs)**:
```swift
struct GlassItemModel: Sendable {  // ✅ No nonisolated on struct
    let natural_key: String        // ✅ Already safe

    nonisolated init(...) { }      // ✅ Mark members only
    nonisolated static func parse(...) { }
}
```

**Service Classes**:
```swift
@preconcurrency  // ✅ Prevents MainActor inference
class CatalogService {
    nonisolated(unsafe) private let repository: Repository
    nonisolated init(...) { }
}
```

**Test Files**:
```swift
@Suite("Tests")
@MainActor  // ✅ When accessing MainActor-isolated code
struct MyTests { }
```

#### Special Cases

**Structs accessing ObservableObject**: Mark specific methods as `@MainActor`:
```swift
struct TypeSystem {
    nonisolated static func getType(...) { }  // Regular method

    @MainActor static func displayName(...) {  // Needs ObservableObject access
        return Settings.shared.displayName(...)
    }
}
```

**ObservableObjects**: Keep MainActor-isolated, never mark `nonisolated`

#### Quick Diagnostic

**Error: "property 'X' can not be mutated from nonisolated context"** (in service class init)
- Fix: Add `@preconcurrency` before `class` declaration

**Error: "property 'X' cannot be accessed from outside of actor"** (in tests)
- Fix: Add `@MainActor` to test suite

**EXC_BREAKPOINT crash at runtime**
- Cause: Invalid `nonisolated struct` syntax
- Fix: Remove `nonisolated` from struct declarations

**Error: "call to main actor-isolated initializer"**
- Fix: Mark initializer `nonisolated` or mark caller `@MainActor`


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
