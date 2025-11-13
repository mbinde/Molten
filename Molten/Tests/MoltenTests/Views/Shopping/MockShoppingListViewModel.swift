//
//  MockShoppingListViewModel.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Mock implementation of ShoppingListViewModel for testing and previews
//

import Foundation
import SwiftUI
@testable import Molten

/// Mock implementation of ShoppingListViewModelProtocol for testing and previews
@MainActor
@Observable
class MockShoppingListViewModel: ShoppingListViewModelProtocol {

    // MARK: - Scenario

    enum Scenario {
        case empty
        case loading
        case error
        case loaded
        case shoppingMode
        case filtered
    }

    // MARK: - Data State

    var shoppingLists: [String: DetailedShoppingListModel]
    var filteredItems: [DetailedShoppingListItemModel]

    // MARK: - Loading State

    var isLoading: Bool
    var errorMessage: String?

    // MARK: - Search & Filter State

    var searchText: String = ""
    var searchTitlesOnly: Bool = false
    var selectedTags: Set<String> = []
    var selectedCOEs: Set<Int32> = []
    var selectedManufacturers: Set<String> = []
    var selectedStore: String? = nil

    // MARK: - Sort State

    var sortOption: ShoppingListSortOption = .neededQuantity

    // MARK: - Shopping Mode State

    var isShoppingModeActive: Bool
    var checkedItems: Set<String> = []

    // MARK: - Test Tracking

    var loadShoppingListsCalled = false
    var refreshShoppingListsCalled = false
    var searchItemsCalled = false
    var clearFiltersCalled = false
    var startShoppingModeCalled = false
    var cancelShoppingModeCalled = false
    var toggleItemCheckedCalled = false
    var performCheckoutCalled = false

    // MARK: - Initialization

    init(scenario: Scenario = .loaded) {
        switch scenario {
        case .empty:
            self.shoppingLists = [:]
            self.filteredItems = []
            self.isLoading = false
            self.errorMessage = nil
            self.isShoppingModeActive = false

        case .loading:
            self.shoppingLists = [:]
            self.filteredItems = []
            self.isLoading = true
            self.errorMessage = nil
            self.isShoppingModeActive = false

        case .error:
            self.shoppingLists = [:]
            self.filteredItems = []
            self.isLoading = false
            self.errorMessage = "Failed to load shopping lists"
            self.isShoppingModeActive = false

        case .loaded:
            let mockLists = Self.createMockShoppingLists()
            self.shoppingLists = mockLists
            self.filteredItems = mockLists.values.flatMap { $0.items }
            self.isLoading = false
            self.errorMessage = nil
            self.isShoppingModeActive = false

        case .shoppingMode:
            let mockLists = Self.createMockShoppingLists()
            self.shoppingLists = mockLists
            self.filteredItems = mockLists.values.flatMap { $0.items }
            self.isLoading = false
            self.errorMessage = nil
            self.isShoppingModeActive = true
            // Pre-check first item
            if let firstItem = self.filteredItems.first {
                self.checkedItems = [firstItem.shoppingListItem.id]
            }

        case .filtered:
            let mockLists = Self.createMockShoppingLists()
            self.shoppingLists = mockLists
            // Only show first item after "filtering"
            let allItems = mockLists.values.flatMap { $0.items }
            self.filteredItems = Array(allItems.prefix(1))
            self.isLoading = false
            self.errorMessage = nil
            self.isShoppingModeActive = false
            self.searchText = "Clear"
        }
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !shoppingLists.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var totalItemsCount: Int {
        shoppingLists.values.reduce(0) { $0 + $1.items.count }
    }

    var itemsNeedingRestockCount: Int {
        shoppingLists.values.flatMap { $0.items }.filter { $0.shoppingListItem.neededQuantity > 0 }.count
    }

    var availableTags: [String] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let tagsSet = Set(allItems.flatMap { $0.tags })
        return Array(tagsSet).sorted()
    }

    var availableCOEs: [Int32] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let coeSet = Set(allItems.map { $0.glassItem.coe })
        return Array(coeSet).sorted()
    }

    var availableManufacturers: [String] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let mfgSet = Set(allItems.map { $0.glassItem.manufacturer })
        return Array(mfgSet).sorted()
    }

    var availableStores: [String] {
        let allItems = shoppingLists.values.flatMap { $0.items }
        let storesSet = Set(allItems.map { $0.shoppingListItem.store })
        return Array(storesSet).sorted()
    }

    // MARK: - Data Loading

    func loadShoppingLists() async {
        loadShoppingListsCalled = true
        // Mock implementation - data already set in init
    }

    func refreshShoppingLists() async {
        refreshShoppingListsCalled = true
        // Mock implementation - data already set in init
    }

    // MARK: - Search & Filter

    func searchItems(text: String) {
        searchItemsCalled = true
        searchText = text

        // Mock implementation - simple filtering
        let allItems = shoppingLists.values.flatMap { $0.items }
        if text.isEmpty {
            filteredItems = allItems
        } else {
            let searchLower = text.lowercased()
            filteredItems = allItems.filter { item in
                if searchTitlesOnly {
                    return item.glassItem.name.lowercased().contains(searchLower)
                } else {
                    return item.glassItem.name.lowercased().contains(searchLower) ||
                           item.glassItem.manufacturer.lowercased().contains(searchLower)
                }
            }
        }
    }

    func clearFilters() {
        clearFiltersCalled = true
        searchText = ""
        searchTitlesOnly = false
        selectedTags = []
        selectedCOEs = []
        selectedManufacturers = []
        selectedStore = nil
        filteredItems = shoppingLists.values.flatMap { $0.items }
    }

    // MARK: - Shopping Mode

    func startShoppingMode() {
        startShoppingModeCalled = true
        isShoppingModeActive = true
        checkedItems = []
    }

    func cancelShoppingMode() {
        cancelShoppingModeCalled = true
        isShoppingModeActive = false
        checkedItems = []
    }

    func toggleItemChecked(_ itemId: String) {
        toggleItemCheckedCalled = true
        if checkedItems.contains(itemId) {
            checkedItems.remove(itemId)
        } else {
            checkedItems.insert(itemId)
        }
    }

    func performCheckout() async throws {
        performCheckoutCalled = true
        // Mock implementation - just exit shopping mode
        cancelShoppingMode()
    }

    // MARK: - Mock Data Helpers

    private static func createMockShoppingLists() -> [String: DetailedShoppingListModel] {
        // Create mock glass items
        let clearRodGlassItem = GlassItemModel(
            stable_id: "bul001",
            name: "Clear Rod",
            sku: "001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let redSheetGlassItem = GlassItemModel(
            stable_id: "bul254",
            name: "Red Sheet",
            sku: "254",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        let blueFritGlassItem = GlassItemModel(
            stable_id: "spe100",
            name: "Blue Frit",
            sku: "100",
            manufacturer: "spectrum",
            coe: 96,
            mfr_status: "available"
        )

        // Create shopping list items (quantities + store info)
        let clearRodShoppingItem = ShoppingListItemModel(
            item_stable_id: "bul001",
            type: "rod",
            currentQuantity: 2.0,
            minimumQuantity: 5.0,
            store: "Glass Supply Co"
        )

        let redSheetShoppingItem = ShoppingListItemModel(
            item_stable_id: "bul254",
            type: "sheet",
            currentQuantity: 1.0,
            minimumQuantity: 3.0,
            store: "Glass Supply Co"
        )

        let blueFritShoppingItem = ShoppingListItemModel(
            item_stable_id: "spe100",
            type: "frit",
            currentQuantity: 0.5,
            minimumQuantity: 2.0,
            store: "Art Glass Store"
        )

        // Combine into detailed shopping list items
        let items = [
            DetailedShoppingListItemModel(
                shoppingListItem: clearRodShoppingItem,
                glassItem: clearRodGlassItem,
                tags: ["transparent", "coe90"],
                userTags: []
            ),
            DetailedShoppingListItemModel(
                shoppingListItem: redSheetShoppingItem,
                glassItem: redSheetGlassItem,
                tags: ["opaque", "coe90"],
                userTags: []
            ),
            DetailedShoppingListItemModel(
                shoppingListItem: blueFritShoppingItem,
                glassItem: blueFritGlassItem,
                tags: ["transparent", "coe96"],
                userTags: []
            )
        ]

        // Create list for "Glass Supply Co"
        let glassSupplyItems = items.filter { $0.shoppingListItem.store == "Glass Supply Co" }
        let glassSupplyList = DetailedShoppingListModel(
            store: "Glass Supply Co",
            items: glassSupplyItems,
            totalItems: glassSupplyItems.count
        )

        // Create list for "Art Glass Store"
        let artGlassItems = items.filter { $0.shoppingListItem.store == "Art Glass Store" }
        let artGlassList = DetailedShoppingListModel(
            store: "Art Glass Store",
            items: artGlassItems,
            totalItems: artGlassItems.count
        )

        return [
            "Glass Supply Co": glassSupplyList,
            "Art Glass Store": artGlassList
        ]
    }
}
