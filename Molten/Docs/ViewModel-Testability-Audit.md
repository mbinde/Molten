# ViewModel Testability Audit

**Date:** October 27, 2025
**Purpose:** Assess current ViewModel implementation patterns and provide recommendations for improving UI testability

---

## Executive Summary

**Current State:**
- ✅ **Good**: One ViewModel (`InventoryViewModel`) with comprehensive tests
- ✅ **Good**: Solid test infrastructure (`TestConfiguration`, `TestDataSetup`)
- ⚠️ **Opportunity**: Most views manage state directly without ViewModels
- ⚠️ **Opportunity**: No protocol-based design for dependency injection
- ⚠️ **Opportunity**: Limited preview coverage for different states

**Recommendations:**
1. Extract ViewModels from complex views (CatalogView, ShoppingListView, PurchasesView)
2. Adopt protocol-based ViewModel pattern for better testability
3. Expand use of `TestDataBuilder` for consistent test scenarios
4. Add SwiftUI Previews for all major states (empty, loading, error, success)
5. Implement accessibility identifiers for UI testing

---

## Current ViewModel Implementation

### ✅ InventoryViewModel (Excellent)

**Location:** `Molten/Sources/Views/Inventory/ViewModel/InventoryViewModel.swift`

**Strengths:**
- ✅ Well-structured with clear separation of concerns
- ✅ Comprehensive test coverage (`InventoryViewModelTests.swift`)
- ✅ Uses dependency injection for services
- ✅ Handles loading states, errors, and async operations
- ✅ Exposes services for advanced operations
- ✅ Factory methods for easy instantiation

**Test Coverage:**
```swift
Tests/MoltenTests/Views/Inventory/InventoryViewModelTests.swift
- 14 test cases covering:
  - Initialization
  - Loading items
  - Search functionality
  - Filtering by type
  - CRUD operations
  - Loading states
  - Computed properties
  - Low stock detection
```

**Opportunities for Improvement:**
1. **Protocol-based design**: Not currently using a protocol for the ViewModel interface
   - **Impact**: Harder to mock for view-level tests
   - **Fix**: Extract `InventoryViewModelProtocol` interface
   - **Benefit**: Can create fast mock implementations for UI tests

2. **State management**: Multiple boolean flags instead of an enum
   - **Current**: `isLoading`, `hasError`, `hasData` (separate booleans)
   - **Better**: `enum ViewState { case idle, loading, loaded, error(String) }`
   - **Benefit**: Impossible to have invalid states (e.g., loading + error simultaneously)

3. **Preview support**: No SwiftUI Previews using mock ViewModels
   - **Current**: View would need to create real services for previews
   - **Better**: Previews with `MockInventoryViewModel(scenario: .loaded)`
   - **Benefit**: Instant visual feedback for all states

**Example Refactor:**
```swift
// Define protocol
protocol InventoryViewModelProtocol: ObservableObject {
    var filteredItems: [CompleteInventoryItemModel] { get }
    var viewState: ViewState { get }
    func loadInventoryItems() async
}

// Add to InventoryViewModel
extension InventoryViewModel: InventoryViewModelProtocol {
    // Already implements the protocol!
}

// Create mock
class MockInventoryViewModel: InventoryViewModelProtocol {
    // Fast, synchronous implementation for testing
}
```

---

## Views Without ViewModels (Opportunities)

### ⚠️ CatalogView (High Priority)

**Location:** `Molten/Sources/Views/Catalog/CatalogView.swift`

**Current State:**
- Complex state management directly in the view
- Multiple `@State` variables for filtering, searching, sorting
- Direct service access without abstraction layer
- Difficult to test presentation logic in isolation

**Complexity Indicators:**
```swift
@State private var searchText = ""
@State private var searchTitlesOnly = true
@State private var sortOption: SortOption = .name
@State private var selectedTags: Set<String> = []
@State private var showingAllTags = false
@State private var selectedCOEs: Set<Int32> = []
@State private var showingCOESelection = false
@State private var selectedManufacturers: Set<String> = []
@State private var showingManufacturerFilterSelection = false
// ... more state variables
```

**Testability Issues:**
1. ❌ Can't test filtering logic without SwiftUI
2. ❌ Can't test search logic independently
3. ❌ Can't test sort logic without full view hierarchy
4. ❌ Can't verify computed properties in isolation
5. ❌ Can't test error handling without UI test

**Recommendation: HIGH PRIORITY - Extract CatalogViewModel**

**Proposed Structure:**
```swift
// 1. Protocol
protocol CatalogViewModelProtocol: ObservableObject {
    var items: [CompleteInventoryItemModel] { get }
    var filteredItems: [CompleteInventoryItemModel] { get }
    var viewState: ViewState { get }
    var searchText: String { get set }
    var selectedManufacturers: Set<String> { get set }
    var selectedCOEs: Set<Int32> { get set }
    var sortOption: SortOption { get set }

    func loadItems() async
    func applyFilters() async

    var availableManufacturers: [String] { get }
    var availableCOEs: [Int32] { get }
}

// 2. Concrete implementation
@Observable
class CatalogViewModel: CatalogViewModelProtocol {
    private let catalogService: CatalogService
    // ... implementation
}

// 3. Update view
struct CatalogView<ViewModel: CatalogViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel
    // Simplified body with less state management
}
```

**Benefits:**
- ✅ Test filtering without SwiftUI
- ✅ Test search independently
- ✅ Test sort logic in isolation
- ✅ Verify computed properties
- ✅ Test error handling
- ✅ Fast, synchronous unit tests
- ✅ SwiftUI Previews for all states

**Estimated Effort:** 4-6 hours
- 2 hours: Extract ViewModel and protocol
- 1 hour: Update view to use ViewModel
- 2 hours: Write comprehensive tests
- 1 hour: Add Previews for all states

---

### ⚠️ ShoppingListView (Medium Priority)

**Expected Complexity:**
- Shopping list state management
- Item completion tracking
- Filtering purchased/unpurchased items
- Minimum quantity logic

**Recommendation: MEDIUM PRIORITY - Extract ShoppingListViewModel**

**Benefits:**
- Test shopping list logic independently
- Test minimum quantity calculations
- Test completion state transitions
- Preview different list states

**Estimated Effort:** 3-4 hours

---

### ⚠️ PurchasesView (Medium Priority)

**Expected Complexity:**
- Purchase record management
- Date filtering
- Vendor filtering
- Total calculations

**Recommendation: MEDIUM PRIORITY - Extract PurchasesViewModel**

**Benefits:**
- Test filtering logic
- Test date range calculations
- Test total aggregations
- Preview different filter states

**Estimated Effort:** 3-4 hours

---

### ⚠️ Other Views (Lower Priority)

**LogbookView, SettingsView, and others:**
- Lower complexity
- Less presentation logic
- Can remain as direct SwiftUI views
- Extract ViewModels only if logic becomes complex

---

## Testing Infrastructure Assessment

### ✅ Existing Infrastructure (Excellent)

**TestConfiguration.swift:**
- ✅ Enforces mock-only testing
- ✅ Prevents Core Data leakage
- ✅ Provides isolated repository creation
- ✅ Well-documented and easy to use

**TestDataSetup.swift:**
- ✅ Provides standard test datasets
- ✅ Creates consistent glass items, inventory, tags
- ✅ Includes factory methods for services
- ✅ Comprehensive test data coverage

**InventoryViewModelTests.swift:**
- ✅ Excellent example of ViewModel testing
- ✅ Comprehensive coverage (14 test cases)
- ✅ Tests all major functionality
- ✅ Good use of arrange-act-assert pattern

### 🎉 New Additions (Just Created)

**TestDataBuilder.swift:**
- ✅ Fluent API for building test scenarios
- ✅ Predefined scenarios for common cases
- ✅ Custom scenario building
- ✅ Service access for tests
- ✅ Well-documented with examples

**Usage Example:**
```swift
let builder = try await TestDataBuilder()
    .withScenario(.inventoryWithLowStock)
    .withGlassItem(manufacturer: "bullseye", sku: "001", name: "Clear")
    .withInventory(manufacturer: "bullseye", sku: "001", quantity: 2.0)
    .build()

let viewModel = InventoryViewModel(
    inventoryTrackingService: builder.inventoryTrackingService,
    catalogService: builder.catalogService
)
```

**DesignSystem+Accessibility.swift:**
- ✅ Centralized accessibility identifiers
- ✅ Consistent naming convention
- ✅ Organized by feature
- ✅ Helper methods for dynamic identifiers
- ✅ Accessibility labels and hints

**Usage Example:**
```swift
Button("Add Item") {
    // action
}
.accessibility(
    identifier: DesignSystem.AccessibilityID.Catalog.addButton,
    label: DesignSystem.AccessibilityLabel.addCatalogItem,
    hint: DesignSystem.AccessibilityHint.addCatalogItem
)
```

---

## Recommendations Summary

### Immediate Actions (Next Sprint)

1. **Extract CatalogViewModel (HIGH PRIORITY)**
   - Most complex view with extensive presentation logic
   - High value for testing
   - Clear protocol interface
   - **Deliverables:**
     - `CatalogViewModelProtocol.swift`
     - `CatalogViewModel.swift` (refactored)
     - `MockCatalogViewModel.swift`
     - `CatalogViewModelTests.swift`
     - Updated `CatalogView.swift`
     - Previews for all states

2. **Add Accessibility Identifiers to Key Views**
   - Use new `DesignSystem.AccessibilityID` constants
   - Start with CatalogView, InventoryView, ShoppingListView
   - **Deliverables:**
     - Updated views with identifiers
     - Basic UI test demonstrating usage

3. **Refactor InventoryViewModel to Protocol Pattern**
   - Extract `InventoryViewModelProtocol`
   - Create `MockInventoryViewModel`
   - Add Previews
   - **Deliverables:**
     - Protocol and mock
     - Updated view
     - Previews

### Medium Term (Next 2 Sprints)

4. **Extract ShoppingListViewModel**
   - Apply protocol pattern
   - Comprehensive tests
   - Previews

5. **Extract PurchasesViewModel**
   - Apply protocol pattern
   - Comprehensive tests
   - Previews

6. **Add UI Tests for Critical User Journeys**
   - Add item to catalog → Add inventory → View in list
   - Create shopping list → Mark complete → Clear
   - Add purchase → View detail → Edit

### Long Term (Future Consideration)

7. **Standardize State Management Pattern**
   - Consider using `ViewState` enum pattern across all ViewModels
   - Provides clearer state transitions
   - Prevents impossible states

8. **Snapshot Testing** (Optional)
   - Consider adding snapshot tests for visual regression
   - Useful for complex layouts
   - Can catch unintended UI changes

9. **Accessibility Audit**
   - Run full VoiceOver test
   - Test with Dynamic Type at all sizes
   - Verify color contrast
   - Test keyboard navigation

---

## Migration Guide

For each view that needs a ViewModel:

### Step 1: Define the Protocol (30 min)
```swift
protocol [Feature]ViewModelProtocol: ObservableObject {
    // Published state
    var items: [ItemType] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }

    // Actions
    func loadItems() async

    // Computed properties
    var hasData: Bool { get }
}
```

### Step 2: Extract ViewModel (1-2 hours)
```swift
@MainActor
@Observable
class [Feature]ViewModel: [Feature]ViewModelProtocol {
    private let service: [Service]

    // Implement protocol
    // Move logic from view
}
```

### Step 3: Update View (1 hour)
```swift
struct [Feature]View<ViewModel: [Feature]ViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel

    // Simplified body
}
```

### Step 4: Create Mock (30 min)
```swift
class Mock[Feature]ViewModel: [Feature]ViewModelProtocol {
    enum Scenario {
        case empty, loading, error, loaded
    }

    init(scenario: Scenario) {
        // Set up state based on scenario
    }
}
```

### Step 5: Write Tests (2 hours)
```swift
@Suite("[Feature]ViewModel Tests")
@MainActor
struct [Feature]ViewModelTests {
    @Test("Should load items")
    func testLoadItems() async throws {
        let builder = try await TestDataBuilder()
            .withScenario(.basicCatalog)
            .build()

        let viewModel = [Feature]ViewModel(service: builder.service)
        await viewModel.loadItems()

        #expect(viewModel.items.count > 0)
    }
}
```

### Step 6: Add Previews (30 min)
```swift
#Preview("Empty") {
    [Feature]View(viewModel: Mock[Feature]ViewModel(scenario: .empty))
}

#Preview("Loaded") {
    [Feature]View(viewModel: Mock[Feature]ViewModel(scenario: .loaded))
}
```

---

## Success Metrics

Track these metrics to measure improvement:

### Test Coverage
- **Target**: 80%+ coverage for ViewModels
- **Current**: ~90% for InventoryViewModel ✅
- **Goal**: Maintain high coverage as new ViewModels are added

### Test Speed
- **Target**: <100ms per ViewModel test
- **Current**: Mocks are fast ✅
- **Goal**: Keep all unit tests under 1 second total

### UI Test Coverage
- **Target**: 10-15 critical user journey tests
- **Current**: TBD (need baseline)
- **Goal**: Cover all main features with at least 1 UI test

### Preview Coverage
- **Target**: All complex views have 4+ preview states
- **Current**: Limited preview usage
- **Goal**: Empty, Loading, Error, Success (minimum)

### Accessibility
- **Target**: 100% of interactive elements have labels
- **Current**: TBD (need audit)
- **Goal**: Pass VoiceOver testing on all major flows

---

## Conclusion

The project has a **solid foundation** with excellent test infrastructure and one well-tested ViewModel. The **main opportunity** is to extract ViewModels from complex views (especially CatalogView) to improve testability.

With the new `TestDataBuilder` and accessibility infrastructure in place, you're well-positioned to:
1. ✅ Write fast, reliable unit tests for presentation logic
2. ✅ Create comprehensive SwiftUI Previews
3. ✅ Build targeted UI tests for critical flows
4. ✅ Ensure accessibility compliance

**Recommended Starting Point:** Extract CatalogViewModel (highest complexity, highest value).

**Follow the Guide:** Use the ViewModel-Protocol-Pattern.md document as a detailed implementation reference.
