# ViewModel Protocol Pattern for UI Testability

This document demonstrates how to make ViewModels testable by using protocol-based design. This pattern allows you to:
1. **Unit test** presentation logic with fast, synchronous mocks
2. **UI test** only user interactions and navigation
3. **Maintain flexibility** for future implementation changes

## The Pattern

### 1. Define a Protocol

Create a protocol that defines the ViewModel's public interface:

```swift
// Views/Catalog/ViewModels/CatalogViewModelProtocol.swift
import Foundation

/// Protocol defining the catalog view's presentation logic
@MainActor
protocol CatalogViewModelProtocol: ObservableObject {
    // State
    var items: [CompleteInventoryItemModel] { get }
    var filteredItems: [CompleteInventoryItemModel] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var searchText: String { get set }
    var selectedManufacturers: Set<String> { get set }
    var selectedCOEs: Set<Int32> { get set }

    // Actions
    func loadItems() async
    func search(_ text: String) async
    func applyFilters() async
    func refreshData() async

    // Computed properties
    var hasData: Bool { get }
    var availableManufacturers: [String] { get }
    var availableCOEs: [Int32] { get }
}
```

### 2. Implement the Concrete ViewModel

The production ViewModel implements the protocol:

```swift
// Views/Catalog/ViewModels/CatalogViewModel.swift
import Foundation
import SwiftUI

@MainActor
@Observable
class CatalogViewModel: CatalogViewModelProtocol {
    private let catalogService: CatalogService

    // MARK: - Published State

    var items: [CompleteInventoryItemModel] = []
    var filteredItems: [CompleteInventoryItemModel] = []
    var isLoading = false
    var errorMessage: String?
    var searchText = "" {
        didSet {
            if searchText != oldValue {
                Task { await search(searchText) }
            }
        }
    }
    var selectedManufacturers: Set<String> = [] {
        didSet {
            Task { await applyFilters() }
        }
    }
    var selectedCOEs: Set<Int32> = [] {
        didSet {
            Task { await applyFilters() }
        }
    }

    // MARK: - Initialization

    init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }

    // MARK: - Actions

    func loadItems() async {
        isLoading = true
        errorMessage = nil

        do {
            items = try await catalogService.getAllGlassItems()
            filteredItems = items
        } catch {
            errorMessage = "Failed to load items: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func search(_ text: String) async {
        guard !text.isEmpty else {
            filteredItems = items
            return
        }

        do {
            filteredItems = try await catalogService.searchItems(
                text: text,
                manufacturers: Array(selectedManufacturers),
                coes: Array(selectedCOEs)
            )
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }

    func applyFilters() async {
        do {
            filteredItems = try await catalogService.searchItems(
                text: searchText,
                manufacturers: Array(selectedManufacturers),
                coes: Array(selectedCOEs)
            )
        } catch {
            errorMessage = "Filter failed: \(error.localizedDescription)"
        }
    }

    func refreshData() async {
        await loadItems()
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !items.isEmpty
    }

    var availableManufacturers: [String] {
        let manufacturers = Set(items.map { $0.glassItem.manufacturer })
        return Array(manufacturers).sorted()
    }

    var availableCOEs: [Int32] {
        let coes = Set(items.map { $0.glassItem.coe })
        return Array(coes).sorted()
    }
}
```

### 3. Update the View to Use the Protocol

The view accepts any implementation of the protocol:

```swift
// Views/Catalog/CatalogView.swift
import SwiftUI

struct CatalogView<ViewModel: CatalogViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel

    // Default parameter allows injection while maintaining convenience
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading catalog...")
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.refreshData() }
                    }
                } else if viewModel.filteredItems.isEmpty {
                    EmptyStateView(message: "No items found")
                } else {
                    itemsList
                }
            }
            .navigationTitle("Catalog")
            .searchable(text: $viewModel.searchText)
            .toolbar {
                filterButtons
            }
            .task {
                if !viewModel.hasData {
                    await viewModel.loadItems()
                }
            }
        }
    }

    private var itemsList: some View {
        List(viewModel.filteredItems, id: \.glassItem.stable_id) { item in
            CatalogItemRow(item: item)
        }
    }

    private var filterButtons: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button("Manufacturers") {
                // Show manufacturer filter
            }
            Button("COE") {
                // Show COE filter
            }
        }
    }
}

// MARK: - Default Parameter Extension (for production use)

extension CatalogView where ViewModel == CatalogViewModel {
    /// Convenience initializer that creates a production ViewModel
    init(catalogService: CatalogService = AppDependencies.createCatalogService()) {
        self.init(viewModel: CatalogViewModel(catalogService: catalogService))
    }
}
```

### 4. Create a Mock ViewModel for Testing

For unit testing the view or for UI test scenarios:

```swift
// Tests/MoltenTests/Views/Catalog/MockCatalogViewModel.swift
import Foundation
@testable import Molten

@MainActor
@Observable
class MockCatalogViewModel: CatalogViewModelProtocol {
    // State
    var items: [CompleteInventoryItemModel]
    var filteredItems: [CompleteInventoryItemModel]
    var isLoading: Bool
    var errorMessage: String?
    var searchText: String
    var selectedManufacturers: Set<String>
    var selectedCOEs: Set<Int32>

    // Test controls
    var loadItemsCalled = false
    var searchCalled = false
    var applyFiltersCalled = false
    var refreshDataCalled = false

    init(scenario: Scenario = .loaded) {
        switch scenario {
        case .empty:
            self.items = []
            self.filteredItems = []
            self.isLoading = false
            self.errorMessage = nil

        case .loading:
            self.items = []
            self.filteredItems = []
            self.isLoading = true
            self.errorMessage = nil

        case .error:
            self.items = []
            self.filteredItems = []
            self.isLoading = false
            self.errorMessage = "Failed to load catalog"

        case .loaded:
            let mockItems = [
                CompleteInventoryItemModel.mock(name: "Clear", manufacturer: "bullseye"),
                CompleteInventoryItemModel.mock(name: "Red", manufacturer: "bullseye"),
                CompleteInventoryItemModel.mock(name: "Blue", manufacturer: "spectrum")
            ]
            self.items = mockItems
            self.filteredItems = mockItems
            self.isLoading = false
            self.errorMessage = nil
        }

        self.searchText = ""
        self.selectedManufacturers = []
        self.selectedCOEs = []
    }

    enum Scenario {
        case empty
        case loading
        case error
        case loaded
    }

    // MARK: - Actions (tracked for verification)

    func loadItems() async {
        loadItemsCalled = true
        // Mock implementation - can customize per test
    }

    func search(_ text: String) async {
        searchCalled = true
        // Mock implementation - could filter items in memory
        if text.isEmpty {
            filteredItems = items
        } else {
            filteredItems = items.filter { item in
                item.glassItem.name.localizedCaseInsensitiveContains(text)
            }
        }
    }

    func applyFilters() async {
        applyFiltersCalled = true
        // Mock implementation
    }

    func refreshData() async {
        refreshDataCalled = true
        await loadItems()
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !items.isEmpty
    }

    var availableManufacturers: [String] {
        let manufacturers = Set(items.map { $0.glassItem.manufacturer })
        return Array(manufacturers).sorted()
    }

    var availableCOEs: [Int32] {
        let coes = Set(items.map { $0.glassItem.coe })
        return Array(coes).sorted()
    }
}

// MARK: - Mock Data Helper

extension CompleteInventoryItemModel {
    static func mock(
        name: String,
        manufacturer: String,
        coe: Int32 = 96,
        inventory: [InventoryModel] = []
    ) -> CompleteInventoryItemModel {
        let stableId = generateStableId(manufacturer: manufacturer, sku: "mock")
        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: "mock",
            manufacturer: manufacturer,
            mfr_notes: "Mock item",
            coe: coe,
            url: nil,
            mfr_status: "available"
        )
        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: []
        )
    }
}
```

### 5. Write Unit Tests

Test the ViewModel in isolation with mocks:

```swift
// Tests/MoltenTests/Views/Catalog/CatalogViewModelTests.swift
import Testing
@testable import Molten

@Suite("CatalogViewModel Tests")
@MainActor
struct CatalogViewModelTests {

    @Test("Should load items on initialization")
    func testLoadItems() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)

        // Act
        await viewModel.loadItems()

        // Assert
        #expect(viewModel.items.count == 3)
        #expect(viewModel.filteredItems.count == 3)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Should filter items by search text")
    func testSearch() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadItems()

        // Act
        await viewModel.search("Clear")

        // Assert
        #expect(viewModel.filteredItems.count > 0)
        #expect(viewModel.filteredItems.allSatisfy { item in
            item.glassItem.name.localizedCaseInsensitiveContains("Clear")
        })
    }

    @Test("Should filter by manufacturer")
    func testFilterByManufacturer() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.multiManufacturer)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadItems()

        // Act
        viewModel.selectedManufacturers = ["bullseye"]
        await viewModel.applyFilters()

        // Assert
        #expect(viewModel.filteredItems.allSatisfy { $0.glassItem.manufacturer == "bullseye" })
    }

    @Test("Should compute available manufacturers correctly")
    func testAvailableManufacturers() async throws {
        // Arrange
        let builder = try await TestDataBuilder()
            .withScenario(.multiManufacturer)
            .build()

        let viewModel = CatalogViewModel(catalogService: builder.catalogService)
        await viewModel.loadItems()

        // Assert
        let manufacturers = viewModel.availableManufacturers
        #expect(manufacturers.contains("bullseye"))
        #expect(manufacturers.contains("spectrum"))
        #expect(manufacturers.contains("kokomo"))
        #expect(manufacturers == manufacturers.sorted()) // Should be sorted
    }
}
```

### 6. Write SwiftUI Preview Tests

Use the mock for instant previews:

```swift
// Views/Catalog/CatalogView.swift (preview section)
#Preview("Empty State") {
    CatalogView(viewModel: MockCatalogViewModel(scenario: .empty))
}

#Preview("Loading State") {
    CatalogView(viewModel: MockCatalogViewModel(scenario: .loading))
}

#Preview("Error State") {
    CatalogView(viewModel: MockCatalogViewModel(scenario: .error))
}

#Preview("Loaded with Data") {
    CatalogView(viewModel: MockCatalogViewModel(scenario: .loaded))
}
```

## Benefits of This Pattern

### 1. **Testability**
- Unit test ViewModels without SwiftUI
- Mock ViewModels for view-level tests
- Fast, synchronous tests

### 2. **Separation of Concerns**
- Presentation logic in ViewModel
- Business logic in Services/Models
- UI rendering in Views

### 3. **Flexibility**
- Easy to swap implementations
- Support for feature flags
- A/B testing capabilities

### 4. **Developer Experience**
- SwiftUI Previews with mock data
- Fast iteration cycles
- Better debugging

## Migration Strategy

To migrate an existing View to this pattern:

1. **Extract State**: Identify all `@State` variables that represent presentation logic
2. **Define Protocol**: Create a protocol with those properties and any actions
3. **Create ViewModel**: Move logic from View to ViewModel
4. **Update View**: Accept protocol-typed ViewModel via dependency injection
5. **Create Mock**: Build mock implementation for testing
6. **Write Tests**: Add comprehensive unit tests

## When to Use This Pattern

✅ **Use for:**
- Complex views with business logic
- Views that need extensive testing
- Features with multiple states (loading, error, success)
- Views with filtering, searching, or sorting

❌ **Skip for:**
- Simple, stateless presentation components
- Views that only display data passed as parameters
- One-off screens with no reusable logic

## Related Patterns

- **Service Layer**: ViewModels orchestrate services, don't contain business logic
- **Repository Pattern**: Services use repositories for data access
- **Dependency Injection**: ViewModels receive dependencies via constructor
- **Observer Pattern**: SwiftUI's `@Observable` provides automatic updates

---

## 🚨 CRITICAL: Mock Naming Conventions

### The Name Collision Problem

When creating mock repositories for ViewModel tests, **NEVER** reuse the name of a production mock. This causes Swift's type resolution to pick the wrong implementation, silently breaking your tests.

**❌ WRONG - Name Collision**:
```swift
// Sources/Repositories/Mock/MockLogbookRepository.swift
actor MockLogbookRepository: LogbookRepository {
    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        print("🔍 Using REAL implementation")  // ← This never prints!
        // ... your implementation
    }
}

// Tests/MoltenTests/Views/LogbookViewModelTests.swift
final class MockLogbookRepository: LogbookRepository {  // ← Swift picks THIS one!
    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        // ... inline implementation for testing
    }
}
```

**Symptoms**:
- You edit the production mock in `Sources/`, but tests don't reflect your changes
- Debug prints in production mock never appear
- Tests fail in ways that suggest your code isn't running
- No compiler errors or warnings

**Why This Happens**: Swift's type resolution picks `class` over `actor` when both types have the same name in scope. When test files import `@testable import Molten` and also define an inline mock with the same name, the inline version shadows the production version.

### The Fix: Use Suffixed Names

**✅ CORRECT - Suffixed Name**:
```swift
// Sources/Repositories/Mock/MockLogbookRepository.swift
actor MockLogbookRepository: LogbookRepository {
    // Production mock used by TestDataBuilder
}

// Tests/MoltenTests/Views/LogbookViewModelTests.swift
final class MockLogbookRepositoryForViewModel: LogbookRepository {  // ✅ Unique name
    // Test-specific mock for special scenarios
}
```

### Naming Convention

Use this pattern for ViewModel-specific mocks:

- `MockXXXForViewModel` - When testing ViewModels with special test scenarios
- `MockXXXForIntegration` - When testing integration flows
- `MockXXXForUITest` - When testing UI with specific test data

**Example**:
```swift
// Production mocks (in Sources/Repositories/Mock/)
actor MockLogbookRepository: LogbookRepository { }
actor MockPurchaseRecordRepository: PurchaseRecordRepository { }
actor MockInventoryRepository: InventoryRepository { }

// ViewModel test mocks (in Tests/)
final class MockLogbookRepositoryForViewModel: LogbookRepository { }
final class MockPurchaseServiceForViewModel: PurchaseRecordService { }
```

### When to Use Production Mocks vs Custom Mocks

**✅ Use Production Mocks** (`Sources/Repositories/Mock/`):
- Full CRUD operations work correctly
- Well-tested and maintained
- Used with `TestDataBuilder` for consistency
- Support all repository methods

**✅ Use Custom ViewModel Mocks** (suffixed names):
- Testing specific error conditions
- Testing edge cases that are hard to set up with real data
- Fast, synchronous mock implementations for UI Previews
- When you need to track method calls for assertions

**❌ NEVER**:
- Reuse production mock names in test files
- Create inline mocks for full CRUD operations
- Define test mocks without unique suffixes

### Debugging Name Collisions

If you suspect a name collision:

1. **Add debug print** to verify which implementation is running:
```swift
func someMethod() async throws -> Result {
    print("🔍 Using [ClassName] implementation")
    // ... rest of implementation
}
```

2. **Search for duplicate names**:
```bash
grep -r "class MockLogbookRepository\|actor MockLogbookRepository" Tests/ Sources/
```

3. **Verify behavior change** - Make an intentional breaking change (like `fatalError()`) to confirm which version is running.

### Historical Context

This issue was discovered during a 4+ hour debugging session where:
- The production `actor MockLogbookRepository` was being edited
- But tests continued to use an inline `class MockLogbookRepository` defined in the test file
- Swift silently picked the `class` over the `actor`
- All edits to the production mock were ignored
- No compilation errors or warnings were shown

**Lesson learned**: Always use suffixed names for test-specific mocks to avoid this silent failure mode.

---

## 📚 Additional Resources

For more testing pitfalls and debugging strategies, see:
- `Testing-Pitfalls-and-Best-Practices.md` - Comprehensive testing guide
- `CLAUDE.md` - Full testing guidelines and TDD workflow
- `Swift6-Concurrency-Guide.md` - Concurrency and actor patterns
