//
//  ShoppingListViewModelTests.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  TDD tests for ShoppingListViewModel - Protocol-based testability
//

import Foundation
import Testing
@testable import Molten

@Suite("ShoppingListViewModel Tests - Protocol-Based Design")
@MainActor
struct ShoppingListViewModelTests {

    // MARK: - Mock-Based Tests (Protocol-Based Design)

    @Test("Mock: Should initialize with empty state")
    func testMockEmptyState() async throws {
        // Arrange & Act
        let viewModel = MockShoppingListViewModel(scenario: .empty)

        // Assert
        #expect(viewModel.shoppingLists.isEmpty)
        #expect(viewModel.filteredItems.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.hasData)
        #expect(!viewModel.isShoppingModeActive)
    }

    @Test("Mock: Should initialize with loaded data")
    func testMockLoadedState() async throws {
        // Arrange & Act
        let viewModel = MockShoppingListViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.shoppingLists.count == 2) // Two stores
        #expect(viewModel.filteredItems.count == 3) // Total items across stores
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasData)
        #expect(!viewModel.isShoppingModeActive)
    }

    @Test("Mock: Should initialize with loading state")
    func testMockLoadingState() async throws {
        // Arrange & Act
        let viewModel = MockShoppingListViewModel(scenario: .loading)

        // Assert
        #expect(viewModel.isLoading)
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with error state")
    func testMockErrorState() async throws {
        // Arrange & Act
        let viewModel = MockShoppingListViewModel(scenario: .error)

        // Assert
        #expect(viewModel.hasError)
        #expect(viewModel.errorMessage == "Failed to load shopping lists")
        #expect(!viewModel.hasData)
    }

    @Test("Mock: Should initialize with shopping mode active")
    func testMockShoppingModeState() async throws {
        // Arrange & Act
        let viewModel = MockShoppingListViewModel(scenario: .shoppingMode)

        // Assert
        #expect(viewModel.isShoppingModeActive)
        #expect(viewModel.checkedItems.count == 1)
        #expect(viewModel.filteredItems.count == 3)
    }

    @Test("Mock: Should initialize with filtered scenario")
    func testMockFilteredState() async throws {
        // Arrange & Act
        let viewModel = MockShoppingListViewModel(scenario: .filtered)

        // Assert
        #expect(viewModel.shoppingLists.count == 2) // Still two stores
        #expect(viewModel.filteredItems.count == 1) // But only 1 filtered item
        #expect(viewModel.searchText == "Clear")
    }

    @Test("Mock: Should search items correctly")
    func testMockSearchItems() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .loaded)

        // Act
        viewModel.searchItems(text: "Clear")

        // Assert
        #expect(viewModel.searchItemsCalled)
        #expect(viewModel.searchText == "Clear")
        #expect(viewModel.filteredItems.count >= 1)
        #expect(viewModel.filteredItems.allSatisfy { $0.glassItem.name.contains("Clear") })
    }

    @Test("Mock: Should clear filters correctly")
    func testMockClearFilters() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .filtered)
        #expect(viewModel.searchText == "Clear")
        #expect(viewModel.filteredItems.count == 1)

        // Act
        viewModel.clearFilters()

        // Assert
        #expect(viewModel.clearFiltersCalled)
        #expect(viewModel.searchText.isEmpty)
        #expect(viewModel.filteredItems.count == 3)
    }

    @Test("Mock: Should start shopping mode")
    func testMockStartShoppingMode() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .loaded)
        #expect(!viewModel.isShoppingModeActive)

        // Act
        viewModel.startShoppingMode()

        // Assert
        #expect(viewModel.startShoppingModeCalled)
        #expect(viewModel.isShoppingModeActive)
        #expect(viewModel.checkedItems.isEmpty)
    }

    @Test("Mock: Should cancel shopping mode")
    func testMockCancelShoppingMode() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .shoppingMode)
        #expect(viewModel.isShoppingModeActive)

        // Act
        viewModel.cancelShoppingMode()

        // Assert
        #expect(viewModel.cancelShoppingModeCalled)
        #expect(!viewModel.isShoppingModeActive)
        #expect(viewModel.checkedItems.isEmpty)
    }

    @Test("Mock: Should toggle item checked")
    func testMockToggleItemChecked() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .shoppingMode)
        let itemId = viewModel.filteredItems.first!.shoppingListItem.id
        let initialCount = viewModel.checkedItems.count

        // Act - toggle off (item starts checked in shoppingMode scenario)
        viewModel.toggleItemChecked(itemId)

        // Assert
        #expect(viewModel.toggleItemCheckedCalled)
        #expect(viewModel.checkedItems.count == initialCount - 1)

        // Act - toggle back on
        viewModel.toggleItemChecked(itemId)

        // Assert
        #expect(viewModel.checkedItems.count == initialCount)
    }

    @Test("Mock: Should perform checkout")
    func testMockPerformCheckout() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .shoppingMode)
        #expect(viewModel.isShoppingModeActive)

        // Act
        try await viewModel.performCheckout()

        // Assert
        #expect(viewModel.performCheckoutCalled)
        #expect(!viewModel.isShoppingModeActive)
    }

    @Test("Mock: Should compute total items count")
    func testMockTotalItemsCount() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.totalItemsCount == 3)
    }

    @Test("Mock: Should compute items needing restock count")
    func testMockItemsNeedingRestockCount() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .loaded)

        // Assert
        #expect(viewModel.itemsNeedingRestockCount == 3)  // All mock items need restock
    }

    @Test("Mock: Should compute available tags")
    func testMockAvailableTags() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .loaded)

        // Assert
        let tags = viewModel.availableTags
        #expect(tags.count > 0)
        #expect(tags.contains("transparent"))
        #expect(tags.contains("opaque"))
        #expect(tags == tags.sorted())  // Should be sorted
    }

    @Test("Mock: Should compute available COEs")
    func testMockAvailableCOEs() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .loaded)

        // Assert
        let coes = viewModel.availableCOEs
        #expect(coes.count == 2)
        #expect(coes.contains(90))
        #expect(coes.contains(96))
        #expect(coes == coes.sorted())  // Should be sorted
    }

    @Test("Mock: Should compute available manufacturers")
    func testMockAvailableManufacturers() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .loaded)

        // Assert
        let mfgs = viewModel.availableManufacturers
        #expect(mfgs.count == 2)
        #expect(mfgs.contains("bullseye"))
        #expect(mfgs.contains("spectrum"))
        #expect(mfgs == mfgs.sorted())  // Should be sorted
    }

    @Test("Mock: Should compute available stores")
    func testMockAvailableStores() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .loaded)

        // Assert
        let stores = viewModel.availableStores
        #expect(stores.count == 2)
        #expect(stores.contains("Glass Supply Co"))
        #expect(stores.contains("Art Glass Store"))
        #expect(stores == stores.sorted())  // Should be sorted
    }

    @Test("Mock: Should track load and refresh operations")
    func testMockLoadAndRefresh() async throws {
        // Arrange
        let viewModel = MockShoppingListViewModel(scenario: .empty)

        // Act
        await viewModel.loadShoppingLists()
        await viewModel.refreshShoppingLists()

        // Assert
        #expect(viewModel.loadShoppingListsCalled)
        #expect(viewModel.refreshShoppingListsCalled)
    }

    // Note: Integration tests would go here testing with real ShoppingListService
    // Those would be more complex and require full service setup
}
