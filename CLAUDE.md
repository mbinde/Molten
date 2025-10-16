# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flameworker is a SwiftUI iOS app for managing glass art inventory. It tracks glass items (rods, tubes, frits) with their manufacturers, COE ratings, inventory quantities, locations, and purchase records. The app uses Core Data with CloudKit for persistence and follows a clean architecture with repository pattern.

## Build & Test Commands

### Building
```bash
# Build the main app
xcodebuild -project Flameworker.xcodeproj -scheme Flameworker -configuration Debug build

# Build for simulator
xcodebuild -project Flameworker.xcodeproj -scheme Flameworker -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Running Tests
```bash
# Run all tests
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test plans
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -testPlan UnitTestsOnly -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -testPlan RepositoryTests -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -testPlan UITests -destination 'platform=iOS Simulator,name=iPhone 15'

# Run a single test
xcodebuild test -project Flameworker.xcodeproj -scheme Flameworker -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:FlameworkerTests/TestClassName/testMethodName
```

### Test Targets
- **FlameworkerTests**: Unit tests for business logic, services, and utilities
  - **MUST use mocks only** - Never touches Core Data
  - Tests should use `RepositoryFactory.configureForTesting()`
  - Fast, isolated tests that don't require persistence
- **RepositoryTests**: Repository layer tests (Core Data operations)
  - **Tests Core Data implementations directly**
  - Uses `RepositoryFactory.configureForTestingWithCoreData()` with isolated test controllers
  - Tests persistence, migrations, and Core Data-specific behavior
- **PerformanceTests**: Performance and load testing
- **FlameworkerUITests**: UI automation tests

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
- Location: `Flameworker/Sources/Models/`
  - **Domain/**: Core business entities with embedded logic (`GlassItemModel`, `InventoryModel`, `WeightUnit`)
  - **Helpers/**: Supporting utilities for business rules (`CatalogItemHelpers`)

**Layer 2: Services (Application/Orchestration)**
- Coordinate repository operations
- Handle async/await patterns
- Cross-entity coordination
- Application-level business flows
- **NO business logic** (delegates to models)
- Location: `Flameworker/Sources/Services/`
  - **Core/**: Primary services (`CatalogService`, `InventoryTrackingService`, `ShoppingListService`, `PurchaseRecordService`)
  - **DataLoading/**: Data import services (`GlassItemDataLoadingService`, `JSONDataLoader`)
  - **Coordination/**: Cross-entity coordination (`EntityCoordinator`, `ReportingService`)

**Layer 3: Repositories (Infrastructure/Persistence)**
- Data storage/retrieval
- Technology-specific implementations (Core Data, Mock)
- Context and transaction management
- **NO business logic**
- Location: `Flameworker/Sources/Repositories/`
  - **Protocols/**: Repository interfaces for dependency injection (`GlassItemRepository`, `InventoryRepository`, `LocationRepository`)
  - **CoreData/**: Core Data implementations (production)
  - **Mock/**: Test doubles for unit testing

**Views Layer** (SwiftUI Interface)
- SwiftUI views organized by feature: Catalog, Inventory, Purchases, ProjectLog, Settings
- Feature-based organization with consistent subdirectory patterns
- Location: `Flameworker/Sources/Views/`
  - Each feature: Main views + Components/ + ViewModels/ + Helpers/ + Debug/
  - **Shared/**: Cross-feature reusable components

**App Layer** (Infrastructure)
- App entry point (`FlameworkerApp.swift`)
- App-wide configuration, navigation, dependency injection
- Location: `Flameworker/Sources/App/`
  - **Factories/**: Dependency injection factories (`RepositoryFactory`, `CatalogViewFactory`)
  - **Configuration/**: App-wide settings and feature flags (`DebugConfig`)

**Utilities** (Cross-Cutting Concerns)
- Generic utilities used across multiple features
- Pure utility functions (formatting, validation, extensions)
- Could be extracted to separate package
- Location: `Flameworker/Sources/Utilities/`

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

The app uses a versioned Core Data model (`Flameworker.xcdatamodeld`) with multiple versions. The current model includes entities for:
- CatalogItem (glass items with manufacturer, SKU, COE)
- Inventory records (quantity, type)
- Location tracking (where items are stored)
- Purchase records

**Model Management**:
- Uses `PersistenceController.shared` for production data
- Includes automatic migration recovery for model changes
- Entity resolution is validated at startup to catch issues early
- **❌ NEVER CREATE MANUAL CORE DATA FILES** - Uses Xcode's automatic code generation to avoid "Multiple commands produce" build conflicts

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
   - Write unit tests in `Tests/FlameworkerTests/`
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

## File Organization

```
Flameworker/Sources/
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
    ├── FlameworkerTests/   # Unit tests
    ├── RepositoryTests/    # Repository layer tests
    ├── PerformanceTests/   # Performance tests
    └── FlameworkerUITests/ # UI tests
```

## Important Files

- **`FlameworkerApp.swift`**: App entry point, configures services and handles data loading
- **`RepositoryFactory.swift`**: Central factory for creating repositories and services
- **`CatalogService.swift`**: Main service for catalog operations (orchestration only, no business logic)
- **`InventoryTrackingService.swift`**: Orchestrates inventory across multiple repositories
- **`Persistence.swift`**: Core Data stack with CloudKit and migration recovery
- **`CompleteInventoryItemModel`** (in `InventoryModels.swift`): Aggregates all item data
- **`Flameworker/README.md`**: Detailed architecture principles and file organization guidelines

## Why This Architecture?

### Improved Maintainability
- **Clear file location**: Developers know exactly where to find code
- **Reduced coupling**: Clean separation between layers
- **Easier testing**: Mock repositories enable fast unit tests

### Better Scalability
- **Feature-based organization**: Easy to add new domains
- **Modular structure**: Components can be extracted to packages
- **Clear dependencies**: Services depend on repositories, not vice versa

### Enhanced Developer Experience
- **Faster navigation**: Logical grouping reduces search time
- **Clearer responsibilities**: Each directory has a single purpose
- **Better code reviews**: Changes are localized to appropriate areas

## Swift 6 & Concurrency

- **Async/await** throughout repository operations
- **Swift Testing** with `#expect()` assertions
- **Clean concurrency boundaries** via repository pattern
- **Thread-safe** service and utility implementations

## Git Commit Guidelines

When creating git commits:
- **DO NOT** add "Generated with Claude Code" footer or "Co-Authored-By: Claude" lines to commit messages
- Write clear, concise commit messages that describe the changes
- Follow conventional commit format if applicable (e.g., "fix:", "feat:", "refactor:")
