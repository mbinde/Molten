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
- Technology-specific implementations (Core Data, Mock, FileSystem)
- Context and transaction management
- **NO business logic**
- Location: `Flameworker/Sources/Repositories/`
  - **Protocols/**: Repository interfaces for dependency injection (`GlassItemRepository`, `InventoryRepository`, `LocationRepository`, `UserImageRepository`)
  - **CoreData/**: Core Data implementations (production)
  - **FileSystem/**: File system implementations (for images and file-based storage)
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

### User Image Upload System

**Overview**: Users can upload custom photos for glass items from their camera or photo library. Images are stored locally using a FileSystem repository pattern.

**Storage Architecture**:
- **Images**: Application Support directory (`~/Library/Application Support/UserImages/`)
  - Format: JPEG at 0.85 compression quality
  - Naming: `{UUID}.jpg`
  - Max size: 2048px (auto-resized on upload)
  - Backed up via iCloud device backup
- **Metadata**: UserDefaults (key: `flameworker.userImages.metadata`)
  - JSON-encoded dictionary mapping UUID → UserImageModel
  - Includes natural key, image type, dates, file extension

**Repository Implementation**:
- Protocol: `UserImageRepository`
- Mock: `MockUserImageRepository` (for testing)
- Production: `FileSystemUserImageRepository` (actor-based for thread safety)
- Factory method: `RepositoryFactory.createUserImageRepository()`

**Image Loading Priority**:
1. User-uploaded primary image (highest priority)
2. Bundle product image (`manufacturer-sku.jpg`)
3. Manufacturer default image (fallback)

**Image Types**:
- **Primary**: Main image shown for an item (only one per item)
- **Alternate**: Additional images (future enhancement)

**UI Integration**:
- `ProductImageDetail` component shows "Add Image" / "Replace Image" button
- Enabled on `GlassItemCard` large variant (detail views)
- Uses modern iOS `PhotosPicker` and camera support
- Automatic cache invalidation on upload

**⚠️ IMPORTANT CAVEAT - Multi-Device Sync**:
- Images are **backed up to iCloud** and will restore when changing iPhones ✅
- Images are **NOT synced via CloudKit** across multiple active devices ❌
- If using multiple devices simultaneously, each device maintains its own set of user images
- This is a conscious design decision to avoid complexity of CloudKit CKAsset management
- **Future Enhancement**: If multi-device real-time sync is needed, implement CloudKit storage:
  - Store images as CKAsset in CloudKit
  - Sync metadata via existing CloudKit Core Data sync
  - Add conflict resolution for when different devices upload different images
  - Handle offline mode and network connectivity edge cases
  - This is NOT currently implemented but architecture supports adding it later

**Testing**:
- Always use `RepositoryFactory.configureForTesting()` to use mock repository
- Mock repository stores images in memory only
- File system repository only used in production builds

**Permissions Required** (in Info.plist):
- `NSPhotoLibraryUsageDescription`: "Flameworker needs access to your photo library to let you upload custom images for your glass inventory items."
- `NSCameraUsageDescription`: "Flameworker needs access to your camera to let you take photos of your glass inventory items."

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

## UI Design System

### Central Design System (`DesignSystem.swift`)

**CRITICAL**: Always use `DesignSystem` constants instead of hardcoded values to maintain UI consistency.

Location: `Flameworker/Sources/Utilities/DesignSystem.swift`

#### Spacing Guidelines

Use the spacing scale defined in `DesignSystem.Spacing`:
- **`.md` (8pt)** - Most common, use for related content in VStack/HStack
- **`.lg` (12pt)** - Between sections or form groups
- **`.xl` (16pt)** - Between major sections
- **`.xs` (4pt)** - Tight spacing in text hierarchies

Example:
```swift
VStack(spacing: DesignSystem.Spacing.md) {  // NOT spacing: 8
    // Content
}
```

#### Padding Guidelines

Use the padding values defined in `DesignSystem.Padding`:
- **`.standard` (12pt)** - Most common for cards and forms
- **`.compact` (8pt)** - Internal padding for tight layouts
- **`.rowVertical` (8pt)** - Vertical padding for list rows

Example:
```swift
.padding(.horizontal, DesignSystem.Padding.standard)  // NOT .padding(.horizontal, 12)
.padding(.vertical, DesignSystem.Padding.rowVertical)
```

#### Corner Radius Guidelines

Use the radius values defined in `DesignSystem.CornerRadius`:
- **`.medium` (8pt)** - Most common for cards and containers
- **`.large` (10pt)** - Search bars and input fields
- **`.extraLarge` (12pt)** - Detail view cards

Example:
```swift
.cornerRadius(DesignSystem.CornerRadius.medium)  // NOT .cornerRadius(8)
```

#### Typography Guidelines

Use semantic fonts defined in `DesignSystem.Typography`:
- **`.rowTitle`** - For list row titles (headline)
- **`.label`** - For form field labels (subheadline with medium weight)
- **`.caption`** - For helper text and secondary information

Apply weights from `DesignSystem.FontWeight`:
```swift
Text("Section Header")
    .font(DesignSystem.Typography.sectionHeader)
    .fontWeight(DesignSystem.FontWeight.semibold)
```

#### Color Guidelines

Use semantic colors defined in `DesignSystem.Colors`:
- **`.textSecondary`** - Most common for helper text and descriptions
- **`.accentPrimary`** - Primary actions, selected states, numeric values
- **`.backgroundSecondary`** - Cards and form backgrounds
- **`.tintBlue`, `.tintGray`** - Tag backgrounds

Example:
```swift
.foregroundColor(DesignSystem.Colors.textSecondary)  // NOT .foregroundColor(.secondary)
.background(DesignSystem.Colors.backgroundSecondary)
```

#### Component Style Modifiers

Use built-in convenience modifiers:

**Card Style:**
```swift
VStack {
    // Content
}
.cardStyle()  // Applies standard card padding, background, and corner radius
```

**Chip/Tag Style:**
```swift
Text("Tag")
    .chipStyle(isSelected: false)  // Applies standard tag styling
```

**Search Bar Style:**
```swift
HStack {
    // Search bar content
}
.searchBarStyle()  // Applies standard search bar styling
```

### Common Layout Patterns

When creating new views, reference these established patterns:

#### List Row Pattern
```swift
HStack(spacing: DesignSystem.Spacing.md) {
    // Icon or image
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
        Text(title).font(DesignSystem.Typography.rowTitle)
        Text(subtitle)
            .font(DesignSystem.Typography.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
    }
    Spacer()
    // Right content
}
.padding(.vertical, DesignSystem.Padding.rowVerticalCompact)
```

#### Form Section Pattern
```swift
VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
    Text("Label")
        .font(DesignSystem.Typography.label)
        .fontWeight(DesignSystem.FontWeight.medium)
    // Input field or picker
}
```

#### Empty State Pattern
```swift
VStack(spacing: DesignSystem.Spacing.xxl) {
    Image(systemName: "icon")
        .font(DesignSystem.Typography.iconLarge)
        .foregroundColor(DesignSystem.Colors.textSecondary)
    VStack(spacing: DesignSystem.Spacing.xs) {
        Text("Title")
            .font(DesignSystem.Typography.sectionHeader)
            .fontWeight(DesignSystem.FontWeight.bold)
        Text("Description")
            .font(DesignSystem.Typography.label)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .multilineTextAlignment(.center)
    }
}
.padding()
```

### UI Consistency Checklist

Before creating or modifying a view, verify:
- ✅ Using `DesignSystem` constants (not hardcoded values)
- ✅ Matching spacing patterns from existing screens
- ✅ Using semantic colors (`.textSecondary` not `.secondary`)
- ✅ Following established typography hierarchy
- ✅ Using convenience modifiers (`.cardStyle()`, `.chipStyle()`)

### Reference Screens

When in doubt, reference these established patterns:
- **CatalogView** - Standard list with search and filters
- **InventoryView** - Card-based layout with sections
- **AddInventoryItemView** - Form layout with validation
- **PurchaseRecordDetailView** - Detail view with sections

## Git Commit Guidelines

When creating git commits:
- **DO NOT** add "Generated with Claude Code" footer or "Co-Authored-By: Claude" lines to commit messages
- Write clear, concise commit messages that describe the changes
- Follow conventional commit format if applicable (e.g., "fix:", "feat:", "refactor:")
