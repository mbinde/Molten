# UI Testing Guide for Molten

**Status**: Planning Document
**Created**: 2025-10-20
**Purpose**: Comprehensive guide for implementing UI tests in Molten

---

## 📋 Table of Contents

1. [Why UI Tests Matter](#why-ui-tests-matter)
2. [Current State Analysis](#current-state-analysis)
3. [UI Testing Architecture](#ui-testing-architecture)
4. [Getting Started: Baby Steps](#getting-started-baby-steps)
5. [Critical Workflows to Test](#critical-workflows-to-test)
6. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
7. [Implementation Roadmap](#implementation-roadmap)
8. [Reference Examples](#reference-examples)

---

## Why UI Tests Matter

UI tests are important because they:

1. **Catch integration bugs** that unit tests miss (like the step-saving bug we just found!)
2. **Verify real user workflows** end-to-end
3. **Prevent regressions** when refactoring UI code
4. **Document expected behavior** through executable examples
5. **Build confidence** in release quality

**The Truth About UI Tests**: They're intimidating because they're **integration tests disguised as UI tests**. You're testing the entire stack at once: UI → Services → Repositories → Core Data → Persistence.

---

## Current State Analysis

### What We Have

✅ **UI Test Target**: `MoltenUITests` is configured and builds
✅ **Basic Infrastructure**: XCTest framework is set up
✅ **Test Stubs**: Two template files exist:
- `FlameworkerUITests.swift` - Empty test example
- `FlameworkerUITestsLaunchTests.swift` - Launch screenshot test

### What We're Missing

❌ **No actual test coverage** - Templates are empty
❌ **No test data strategy** - How do we ensure consistent test state?
❌ **No accessibility identifiers** - Hard to find UI elements reliably
❌ **No Page Object pattern** - Tests would be brittle and hard to maintain
❌ **No test environment detection** - App shows "Test Environment" but doesn't configure properly

### Key Architectural Challenges

**Challenge 1: Test Data Isolation**
- Problem: UI tests run against the real app with real Core Data
- Risk: Tests pollute production data or interfere with each other
- Solution: Need a test-only Core Data container

**Challenge 2: App Launch Performance**
- App has complex startup sequence:
  1. Launch screen (0.3s)
  2. First-run data loading (Core Data initialization)
  3. Terminology onboarding (if first run)
  4. Alpha disclaimer
- Tests need to handle or skip these flows

**Challenge 3: Finding UI Elements**
- SwiftUI views don't have explicit IDs by default
- Need to add `.accessibilityIdentifier()` modifiers
- Need consistent naming convention

---

## UI Testing Architecture

### The Big Picture

```
┌─────────────────────────────────────────────────┐
│           XCTest UI Test Runner                 │
│  (Runs in separate process from app)            │
└────────────┬────────────────────────────────────┘
             │
             │ XCUIApplication.launch()
             ▼
┌─────────────────────────────────────────────────┐
│              Molten App Process                  │
│  ┌───────────────────────────────────────────┐  │
│  │ MoltenApp.swift                           │  │
│  │ - Detects test environment                │  │
│  │ - Configures test-only Core Data          │  │
│  │ - Skips onboarding screens                │  │
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │ RepositoryFactory                         │  │
│  │ - Uses in-memory Core Data for tests      │  │
│  │ - Loads minimal test fixtures             │  │
│  └───────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────┐  │
│  │ Views with Accessibility IDs              │  │
│  │ - Buttons: "catalog.add.button"           │  │
│  │ - Lists: "catalog.list"                   │  │
│  │ - Text Fields: "catalog.search.field"     │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
```

### Test Environment Detection

**Current Implementation** (MoltenApp.swift:24-26):
```swift
private var isRunningTests: Bool {
    return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
```

**What We Need to Add**:
1. Configure RepositoryFactory for testing when `isRunningTests` is true
2. Skip onboarding screens
3. Load minimal test data
4. Use in-memory Core Data store

### Page Object Pattern

Instead of writing brittle tests like this:
```swift
// ❌ BAD: Fragile, hard to maintain
func testAddInventory() {
    let app = XCUIApplication()
    app.launch()
    app.buttons["Inventory"].tap()
    app.buttons["Add"].tap()
    app.textFields.element(boundBy: 0).tap()
    app.textFields.element(boundBy: 0).typeText("Bullseye Clear")
    // ... brittle and unclear
}
```

Use Page Objects like this:
```swift
// ✅ GOOD: Readable, maintainable
func testAddInventory() {
    let app = XCUIApplication()
    app.launch()

    let catalogPage = CatalogPage(app: app)
    catalogPage.tapInventoryTab()
    catalogPage.tapAddButton()
    catalogPage.enterItemName("Bullseye Clear")
    catalogPage.selectQuantity(5)
    catalogPage.tapSaveButton()

    XCTAssertTrue(catalogPage.itemExists("Bullseye Clear"))
}
```

---

## Getting Started: Baby Steps

### Step 1: Add Accessibility Identifiers (1-2 hours)

**Goal**: Make UI elements findable in tests

**Where to Start**: MainTabView.swift

```swift
// BEFORE
TabView {
    CatalogView(catalogService: catalogService)
        .tabItem {
            Label("Catalog", systemImage: "books.vertical")
        }

    // ... other tabs
}

// AFTER
TabView {
    CatalogView(catalogService: catalogService)
        .tabItem {
            Label("Catalog", systemImage: "books.vertical")
        }
        .accessibilityIdentifier("tab.catalog")

    InventoryView()
        .tabItem {
            Label("Inventory", systemImage: "cube.box")
        }
        .accessibilityIdentifier("tab.inventory")

    // ... continue for all tabs
}
```

**Naming Convention**:
- Format: `{feature}.{component}.{type}`
- Examples:
  - `catalog.search.field`
  - `catalog.add.button`
  - `catalog.item.list`
  - `inventory.quantity.field`
  - `projects.create.button`

**Priority Areas** (add identifiers to these first):
1. ✅ Tab bar items
2. ✅ Primary action buttons ("Add", "Save", "Cancel", "Done")
3. ✅ Search fields
4. ✅ Lists/ScrollViews
5. ✅ Text input fields
6. ✅ Navigation bar items

### Step 2: Configure Test Environment (2-3 hours)

**Goal**: App launches cleanly in test mode with test data

**File**: MoltenApp.swift

Update the test environment handling:

```swift
// CURRENT (line 33-38)
if isRunningTests {
    // During tests, show a simple view without data loading
    Text("Test Environment")
        .onAppear {
            isLaunching = false
        }
}

// PROPOSED
if isRunningTests {
    // Configure for UI testing
    createMainTabView()
        .onAppear {
            configureTestEnvironment()
        }
}

// NEW METHOD
@MainActor
private func configureTestEnvironment() {
    print("🧪 Configuring UI Test Environment")

    // 1. Use in-memory Core Data
    RepositoryFactory.configureForUITesting()

    // 2. Skip onboarding
    GlassTerminologySettings.shared.hasCompletedOnboarding = true
    UserDefaults.standard.set(true, forKey: "hasAcknowledgedAlphaDisclaimer")

    // 3. Load minimal test fixtures
    Task {
        await loadTestFixtures()
    }
}
```

**File**: RepositoryFactory.swift

Add new test configuration mode:

```swift
// ADD TO RepositoryFactory
static func configureForUITesting() {
    mode = .uiTesting

    // Create in-memory store
    let controller = PersistenceController.createInMemoryController()
    persistentContainer = controller.container

    print("✅ RepositoryFactory configured for UI testing")
}

// UPDATE RepositoryMode enum
enum RepositoryMode {
    case production
    case development
    case testing        // For unit tests (mocks)
    case uiTesting      // For UI tests (in-memory Core Data)
}
```

### Step 3: Create First Page Object (1 hour)

**Goal**: Encapsulate catalog screen interactions

**File**: Create `Molten/Tests/MoltenUITests/PageObjects/CatalogPage.swift`

```swift
import XCTest

/// Page Object for the Catalog screen
class CatalogPage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var catalogTab: XCUIElement {
        app.buttons["tab.catalog"]
    }

    var searchField: XCUIElement {
        app.searchFields["catalog.search.field"]
    }

    var addButton: XCUIElement {
        app.buttons["catalog.add.button"]
    }

    var itemList: XCUIElement {
        app.scrollViews["catalog.item.list"]
    }

    // MARK: - Actions

    func tapCatalogTab() {
        catalogTab.tap()
    }

    func search(for text: String) {
        searchField.tap()
        searchField.typeText(text)
    }

    func tapAddButton() {
        addButton.tap()
    }

    func itemCell(named name: String) -> XCUIElement {
        app.cells.containing(.staticText, identifier: name).firstMatch
    }

    func tapItem(named name: String) {
        itemCell(named: name).tap()
    }

    // MARK: - Assertions

    func waitForCatalogToLoad(timeout: TimeInterval = 5) -> Bool {
        itemList.waitForExistence(timeout: timeout)
    }

    func itemExists(_ name: String) -> Bool {
        itemCell(named: name).exists
    }

    func numberOfItems() -> Int {
        app.cells.count
    }
}
```

### Step 4: Write First Real Test (30 minutes)

**Goal**: Test the simplest workflow - app launches and shows catalog

**File**: Update `Molten/Tests/MoltenUITests/FlameworkerUITests.swift`

```swift
import XCTest

final class CatalogUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        // Launch arguments for test configuration
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Basic Tests

    func testAppLaunches() throws {
        // Verify app launches and shows main tab bar
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testCatalogTabLoads() throws {
        let catalogPage = CatalogPage(app: app)

        // Tap catalog tab
        catalogPage.tapCatalogTab()

        // Wait for catalog to load
        XCTAssertTrue(catalogPage.waitForCatalogToLoad())
    }

    func testSearchField() throws {
        let catalogPage = CatalogPage(app: app)

        catalogPage.tapCatalogTab()
        XCTAssertTrue(catalogPage.waitForCatalogToLoad())

        // Verify search field exists and is tappable
        XCTAssertTrue(catalogPage.searchField.exists)
        catalogPage.search(for: "clear")

        // Verify text was entered
        XCTAssertEqual(catalogPage.searchField.value as? String, "clear")
    }
}
```

### Step 5: Run and Debug (1-2 hours)

**Run the test**:
```bash
xcodebuild test \
  -project Molten.xcodeproj \
  -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenUITests/CatalogUITests/testAppLaunches
```

**Expected Issues and Fixes**:

1. **"Element not found"**
   - Problem: Missing accessibility identifier
   - Fix: Add `.accessibilityIdentifier()` to the view

2. **"Test data not loaded"**
   - Problem: Test fixtures not loading
   - Fix: Implement `loadTestFixtures()` function

3. **"App doesn't launch"**
   - Problem: Test environment not configured
   - Fix: Check `isRunningTests` detection and RepositoryFactory configuration

---

## Critical Workflows to Test

### Priority 1: Core Data Persistence (HIGH IMPACT)

These tests catch bugs like the step-saving issue we just fixed:

```swift
func testProjectPlanStepsPersist() throws {
    let projectsPage = ProjectsPage(app: app)

    // Create a new project plan
    projectsPage.tapCreateButton()
    projectsPage.enterTitle("Test Project")
    projectsPage.tapSaveButton()

    // Add a step
    projectsPage.tapAddStepButton()
    projectsPage.enterStepTitle("First Step")
    projectsPage.enterStepDescription("Test description")
    projectsPage.tapSaveStepButton()

    // Restart app to verify persistence
    app.terminate()
    app.launch()

    // Verify step persisted
    projectsPage.tapProjectNamed("Test Project")
    XCTAssertTrue(projectsPage.stepExists("First Step"))
}
```

### Priority 2: Multi-Step Workflows (MEDIUM IMPACT)

```swift
func testAddInventoryItemCompleteFlow() throws {
    let catalogPage = CatalogPage(app: app)
    let inventoryPage = InventoryPage(app: app)

    // 1. Search for item in catalog
    catalogPage.tapCatalogTab()
    catalogPage.search(for: "Bullseye Clear")
    catalogPage.tapItem(named: "Bullseye Clear 001")

    // 2. Add to inventory
    catalogPage.tapAddToInventoryButton()
    inventoryPage.enterQuantity("5")
    inventoryPage.selectUnit("rods")
    inventoryPage.selectLocation("Studio - Shelf A")
    inventoryPage.tapSaveButton()

    // 3. Verify in inventory list
    inventoryPage.tapInventoryTab()
    XCTAssertTrue(inventoryPage.itemExists("Bullseye Clear 001"))
    XCTAssertEqual(inventoryPage.quantityFor("Bullseye Clear 001"), "5 rods")
}
```

### Priority 3: Search & Filtering (MEDIUM IMPACT)

```swift
func testCatalogSearch() throws {
    let catalogPage = CatalogPage(app: app)

    catalogPage.tapCatalogTab()

    // Before search - show all items
    let initialCount = catalogPage.numberOfItems()
    XCTAssertGreaterThan(initialCount, 0)

    // After search - filtered results
    catalogPage.search(for: "clear")
    let filteredCount = catalogPage.numberOfItems()
    XCTAssertLessThan(filteredCount, initialCount)

    // Clear search
    catalogPage.clearSearch()
    XCTAssertEqual(catalogPage.numberOfItems(), initialCount)
}
```

### Priority 4: Edge Cases (LOW IMPACT, HIGH VALUE)

```swift
func testEmptyStateHandling() throws {
    let inventoryPage = InventoryPage(app: app)

    // With no inventory items
    inventoryPage.tapInventoryTab()
    XCTAssertTrue(inventoryPage.emptyStateExists())
    XCTAssertTrue(inventoryPage.emptyStateMessage.exists)
}

func testValidationErrors() throws {
    let catalogPage = CatalogPage(app: app)

    // Try to save without required fields
    catalogPage.tapAddButton()
    catalogPage.tapSaveButton()

    // Should show validation error
    XCTAssertTrue(catalogPage.validationErrorExists())
}
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Flaky Tests (Timing Issues)

**Problem**: Test fails randomly because UI hasn't loaded yet

```swift
// ❌ BAD
app.buttons["Save"].tap()  // Might not exist yet!

// ✅ GOOD
let saveButton = app.buttons["Save"]
XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
saveButton.tap()
```

**Solution**: Always use `waitForExistence(timeout:)` before interacting with elements

### Pitfall 2: Hard-Coded Element Indexes

**Problem**: Tests break when UI order changes

```swift
// ❌ BAD
app.textFields.element(boundBy: 0).tap()  // Which field is this?

// ✅ GOOD
app.textFields["catalog.search.field"].tap()  // Clear and specific
```

**Solution**: Always use accessibility identifiers

### Pitfall 3: Test Data Pollution

**Problem**: Tests fail because previous test left data behind

```swift
// ✅ GOOD: Clean state in setUp
override func setUpWithError() throws {
    app = XCUIApplication()
    app.launchArguments = ["UI-Testing", "ResetState"]
    app.launch()
}
```

**Solution**: Reset test state before each test

### Pitfall 4: Over-Assertion

**Problem**: Tests are too specific and break on minor UI changes

```swift
// ❌ BAD: Too specific
XCTAssertEqual(catalogPage.numberOfItems(), 157)  // Breaks if data changes

// ✅ GOOD: Test behavior, not exact values
XCTAssertGreaterThan(catalogPage.numberOfItems(), 0)
XCTAssertTrue(catalogPage.itemExists("Bullseye Clear 001"))
```

**Solution**: Assert on behavior, not implementation details

### Pitfall 5: No Page Objects

**Problem**: Duplicated element selectors across tests

```swift
// ❌ BAD: Duplicated in every test
app.buttons["catalog.add.button"].tap()
app.buttons["catalog.add.button"].tap()
app.buttons["catalog.add.button"].tap()

// ✅ GOOD: Centralized in Page Object
catalogPage.tapAddButton()
```

**Solution**: Always use Page Objects

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)

**Goal**: Infrastructure for running basic tests

- [ ] Add accessibility identifiers to MainTabView tabs
- [ ] Configure `RepositoryFactory.configureForUITesting()`
- [ ] Update MoltenApp to detect and configure test environment
- [ ] Create in-memory test data loading
- [ ] Write first Page Object (CatalogPage)
- [ ] Write first passing test (testAppLaunches)

**Success Criteria**:
- ✅ One UI test passes consistently
- ✅ Test runs in under 10 seconds
- ✅ Test data doesn't pollute production

### Phase 2: Core Workflows (Week 2)

**Goal**: Test the most critical user journeys

- [ ] Add accessibility identifiers to Catalog views
- [ ] Add accessibility identifiers to Inventory views
- [ ] Create InventoryPage object
- [ ] Test: Add item to inventory
- [ ] Test: Search catalog
- [ ] Test: Update inventory quantity

**Success Criteria**:
- ✅ 5-10 tests covering main features
- ✅ Tests run in CI without flakiness
- ✅ Tests catch regression bugs

### Phase 3: Project Plans (Week 3)

**Goal**: Test complex multi-entity workflows

- [ ] Add accessibility identifiers to Project views
- [ ] Create ProjectsPage object
- [ ] Test: Create project plan
- [ ] Test: Add steps to plan (the bug we just fixed!)
- [ ] Test: Add glass to steps
- [ ] Test: Project plan persists across app restarts

**Success Criteria**:
- ✅ Project workflows fully tested
- ✅ Persistence bugs caught by tests
- ✅ Complex interactions verified

### Phase 4: Edge Cases & Polish (Week 4)

**Goal**: Comprehensive coverage and stability

- [ ] Test empty states
- [ ] Test validation errors
- [ ] Test network-dependent features
- [ ] Test CloudKit sync (if applicable)
- [ ] Optimize test performance
- [ ] Document test patterns

**Success Criteria**:
- ✅ 80%+ critical path coverage
- ✅ Tests run in under 5 minutes total
- ✅ New features include UI tests by default

---

## Reference Examples

### Minimal Test Template

```swift
import XCTest

final class FeatureUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    func testFeatureName() throws {
        // Arrange
        let page = FeaturePage(app: app)

        // Act
        page.performAction()

        // Assert
        XCTAssertTrue(page.expectedState())
    }
}
```

### Page Object Template

```swift
import XCTest

class FeaturePage {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    // MARK: - Elements

    var mainButton: XCUIElement {
        app.buttons["feature.main.button"]
    }

    // MARK: - Actions

    func performAction() {
        mainButton.tap()
    }

    // MARK: - Assertions

    func expectedState() -> Bool {
        return app.staticTexts["Success"].exists
    }
}
```

### Test Fixture Loader

```swift
// In MoltenApp.swift or separate TestDataLoader.swift

@MainActor
private func loadTestFixtures() async {
    guard isRunningTests else { return }

    print("🧪 Loading test fixtures")

    let catalogService = RepositoryFactory.createCatalogService()

    // Load minimal catalog data for tests
    let testItems = [
        GlassItemModel(
            name: "Test Clear Glass",
            natural_key: "test-clear-001",
            manufacturer: "test",
            sku: "CLEAR-001",
            coe: "96",
            category: .rod,
            form: .solid
        ),
        GlassItemModel(
            name: "Test Blue Glass",
            natural_key: "test-blue-001",
            manufacturer: "test",
            sku: "BLUE-001",
            coe: "96",
            category: .rod,
            form: .solid
        )
    ]

    for item in testItems {
        do {
            _ = try await catalogService.createGlassItem(item)
        } catch {
            print("❌ Failed to load test item: \(error)")
        }
    }

    print("✅ Test fixtures loaded")
}
```

---

## Next Steps

Tomorrow we can:

1. **Start with Phase 1, Step 1**: Add accessibility identifiers to MainTabView
2. **Walk through a live example**: I'll help you write and run the first test
3. **Debug together**: Figure out any environment setup issues
4. **Build momentum**: Each passing test makes the next one easier

**Remember**: UI tests are intimidating, but they're just integration tests with a fancy UI driver. Start small, build incrementally, and celebrate each passing test! 🎉

---

## Helpful Commands

```bash
# Run all UI tests
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenUITests

# Run specific test class
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenUITests/CatalogUITests

# Run specific test method
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenUITests/CatalogUITests/testAppLaunches

# Run with verbose output
xcodebuild test -project Molten.xcodeproj -scheme Molten \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:MoltenUITests | xcpretty
```

---

**Good luck! Remember: The journey of a thousand tests begins with a single `app.launch()` 🚀**
