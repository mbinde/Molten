//
//  MockInventoryViewModel.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Mock implementation of InventoryViewModel for testing and previews
//

import Foundation
import SwiftUI
@testable import Molten

/// Mock implementation of InventoryViewModelProtocol for testing and previews
///
/// **Usage in tests:**
/// ```swift
/// let mockVM = MockInventoryViewModel(scenario: .loaded)
/// #expect(mockVM.hasData)
/// ```
///
/// **Usage in previews:**
/// ```swift
/// #Preview("Loaded State") {
///     InventoryView(viewModel: MockInventoryViewModel(scenario: .loaded))
/// }
/// ```
@MainActor
@Observable
class MockInventoryViewModel: InventoryViewModelProtocol {

    // MARK: - Scenario

    enum Scenario {
        case empty
        case loading
        case error
        case loaded
        case lowStock
        case filtered
    }

    // MARK: - Data State

    var completeItems: [CompleteInventoryItemModel]
    var filteredItems: [CompleteInventoryItemModel]

    // MARK: - Loading State

    var isLoading: Bool
    var errorMessage: String?

    // MARK: - Search & Filter State

    var searchText: String = ""
    var searchTitlesOnly: Bool = false
    var selectedTypes: Set<String> = []
    var selectedTags: Set<String> = []
    var selectedCOEs: Set<Int32> = []
    var selectedManufacturers: Set<String> = []
    var sortOption: InventorySortOption = .name

    // MARK: - Test Tracking

    var loadInventoryItemsCalled = false
    var searchItemsCalled = false
    var filterItemsCalled = false
    var applyFiltersCalled = false
    var addInventoryCalled = false
    var updateInventoryCalled = false
    var deleteInventoryCalled = false
    var deleteInventoriesCalled = false
    var getDetailedInventorySummaryCalled = false
    var getLowStockItemsCalled = false

    // MARK: - Initialization

    init(scenario: Scenario = .loaded) {
        switch scenario {
        case .empty:
            self.completeItems = []
            self.filteredItems = []
            self.isLoading = false
            self.errorMessage = nil

        case .loading:
            self.completeItems = []
            self.filteredItems = []
            self.isLoading = true
            self.errorMessage = nil

        case .error:
            self.completeItems = []
            self.filteredItems = []
            self.isLoading = false
            self.errorMessage = "Failed to load inventory"

        case .loaded:
            let mockItems = Self.createMockItems()
            self.completeItems = mockItems
            self.filteredItems = mockItems
            self.isLoading = false
            self.errorMessage = nil

        case .lowStock:
            let mockItems = Self.createMockLowStockItems()
            self.completeItems = mockItems
            self.filteredItems = mockItems
            self.isLoading = false
            self.errorMessage = nil

        case .filtered:
            let mockItems = Self.createMockItems()
            self.completeItems = mockItems
            // Only show rod types after "filtering"
            self.filteredItems = mockItems.filter { item in
                item.inventory.contains { $0.type == "rod" }
            }
            self.isLoading = false
            self.errorMessage = nil
            self.selectedTypes = ["rod"]
        }
    }

    // MARK: - Computed Properties

    var hasData: Bool {
        !completeItems.isEmpty || !filteredItems.isEmpty
    }

    var hasError: Bool {
        errorMessage != nil
    }

    var availableInventoryTypes: [String] {
        let allTypes = Set(completeItems.flatMap { item in
            item.inventory.compactMap { $0.type }
        })
        return Array(allTypes).sorted()
    }

    var availableTags: [String] {
        let allTags = Set(completeItems.flatMap { $0.allTags })
        return Array(allTags).sorted()
    }

    var availableCOEs: [Int32] {
        let allCOEs = Set(completeItems.map { $0.glassItem.coe })
        return Array(allCOEs).sorted()
    }

    var availableManufacturers: [String] {
        let allManufacturers = Set(completeItems.map { $0.glassItem.manufacturer })
        return Array(allManufacturers).sorted()
    }

    var totalItemsCount: Int {
        completeItems.count
    }

    var filteredItemsCount: Int {
        filteredItems.count
    }

    // MARK: - Data Loading

    func loadInventoryItems() async {
        loadInventoryItemsCalled = true
        // Mock implementation - data already set in init
    }

    // MARK: - Search & Filter

    func searchItems(searchText: String) async {
        searchItemsCalled = true
        self.searchText = searchText

        // Mock implementation - simple filtering
        if searchText.isEmpty {
            filteredItems = completeItems
        } else {
            filteredItems = completeItems.filter { item in
                item.glassItem.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    func filterItems(byType type: String) async {
        filterItemsCalled = true

        // Mock implementation
        filteredItems = completeItems.filter { item in
            item.inventory.contains { $0.type == type }
        }
    }

    func applyFilters() async {
        applyFiltersCalled = true

        // Mock implementation
        var filtered = completeItems

        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.glassItem.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        if !selectedTypes.isEmpty {
            filtered = filtered.filter { item in
                item.inventory.contains { inv in
                    selectedTypes.contains(inv.type)
                }
            }
        }

        filteredItems = filtered
    }

    // MARK: - CRUD Operations

    func addInventory(quantity: Double, type: String, toItemNaturalKey stableId: String) async {
        addInventoryCalled = true
        // Mock implementation - no actual operation
    }

    func updateInventory(_ inventory: InventoryModel) async {
        updateInventoryCalled = true
        // Mock implementation - no actual operation
    }

    func deleteInventory(id: UUID) async {
        deleteInventoryCalled = true
        // Mock implementation - no actual operation
    }

    func deleteInventories(ids: [UUID]) async {
        deleteInventoriesCalled = true
        // Mock implementation - no actual operation
    }

    // MARK: - New Architecture Methods

    func getDetailedInventorySummary(for stableId: String) async -> DetailedInventorySummaryModel? {
        getDetailedInventorySummaryCalled = true

        // Mock implementation - return a simple summary
        guard let item = completeItems.first(where: { $0.glassItem.stable_id == stableId }) else {
            return nil
        }

        let summary = InventorySummaryModel(
            item_stable_id: stableId,
            inventories: item.inventory
        )

        return DetailedInventorySummaryModel(
            summary: summary,
            locationDetails: [:],  // Empty location details for mock
            inventoryByType: [:]   // Empty inventory by type for mock
        )
    }

    func getLowStockItems(threshold: Double = 5.0) async {
        getLowStockItemsCalled = true

        // Mock implementation - filter by low stock
        filteredItems = completeItems.filter { item in
            item.totalQuantity < threshold
        }
    }

    // MARK: - Mock Data Helpers

    private static func createMockItems() -> [CompleteInventoryItemModel] {
        return [
            CompleteInventoryItemModel.mock(
                name: "Clear Rod",
                manufacturer: "bullseye",
                sku: "001",
                coe: 90,
                inventory: [
                    InventoryModel(item_stable_id: "bul001", type: "rod", quantity: 10.0)
                ],
                tags: ["transparent", "coe90"]
            ),
            CompleteInventoryItemModel.mock(
                name: "Red Sheet",
                manufacturer: "bullseye",
                sku: "254",
                coe: 90,
                inventory: [
                    InventoryModel(item_stable_id: "bul254", type: "sheet", quantity: 5.0)
                ],
                tags: ["opaque", "coe90"]
            ),
            CompleteInventoryItemModel.mock(
                name: "Blue Frit",
                manufacturer: "spectrum",
                sku: "100",
                coe: 96,
                inventory: [
                    InventoryModel(item_stable_id: "spe100", type: "frit", quantity: 8.0)
                ],
                tags: ["transparent", "coe96"]
            )
        ]
    }

    private static func createMockLowStockItems() -> [CompleteInventoryItemModel] {
        return [
            CompleteInventoryItemModel.mock(
                name: "Clear Rod",
                manufacturer: "bullseye",
                sku: "001",
                coe: 90,
                inventory: [
                    InventoryModel(item_stable_id: "bul001", type: "rod", quantity: 2.0)  // Low stock
                ],
                tags: ["transparent", "coe90"]
            ),
            CompleteInventoryItemModel.mock(
                name: "Red Sheet",
                manufacturer: "bullseye",
                sku: "254",
                coe: 90,
                inventory: [
                    InventoryModel(item_stable_id: "bul254", type: "sheet", quantity: 1.0)  // Low stock
                ],
                tags: ["opaque", "coe90"]
            )
        ]
    }
}
