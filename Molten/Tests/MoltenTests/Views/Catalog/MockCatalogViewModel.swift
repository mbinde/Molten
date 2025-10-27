//
//  MockCatalogViewModel.swift
//  MoltenTests
//
//  Created by Assistant on 10/27/25.
//  Mock implementation of CatalogViewModel for testing and previews
//

import Foundation
import SwiftUI
@testable import Molten

/// Mock implementation of CatalogViewModelProtocol for testing and previews
///
/// **Usage in tests:**
/// ```swift
/// let mockVM = MockCatalogViewModel(scenario: .loaded)
/// #expect(mockVM.hasData)
/// ```
///
/// **Usage in previews:**
/// ```swift
/// #Preview("Loaded State") {
///     CatalogView(viewModel: MockCatalogViewModel(scenario: .loaded))
/// }
/// ```
@MainActor
@Observable
class MockCatalogViewModel: CatalogViewModelProtocol {

    // MARK: - Scenario

    enum Scenario {
        case empty
        case loading
        case error
        case loaded
        case filtered
    }

    // MARK: - Published State

    var items: [CompleteInventoryItemModel]
    var filteredItems: [CompleteInventoryItemModel]
    var sortedFilteredItems: [CompleteInventoryItemModel]
    var isLoading: Bool
    var errorMessage: String?

    // MARK: - Search & Filter State

    var searchText: String = ""
    var searchTitlesOnly: Bool = true
    var selectedTags: Set<String> = []
    var selectedCOEs: Set<Int32> = []
    var selectedManufacturers: Set<String> = []
    var selectedManufacturer: String? = nil

    // MARK: - Sort State

    var sortOption: SortOption = .name

    // MARK: - UI State

    var searchClearedFeedback: Bool = false

    // MARK: - Test Tracking

    var loadDataCalled = false
    var refreshDataCalled = false
    var clearSearchCalled = false
    var updateSortingCalled = false
    var applyFiltersCalled = false

    // MARK: - Initialization

    init(scenario: Scenario = .loaded) {
        switch scenario {
        case .empty:
            self.items = []
            self.filteredItems = []
            self.sortedFilteredItems = []
            self.isLoading = false
            self.errorMessage = nil

        case .loading:
            self.items = []
            self.filteredItems = []
            self.sortedFilteredItems = []
            self.isLoading = true
            self.errorMessage = nil

        case .error:
            self.items = []
            self.filteredItems = []
            self.sortedFilteredItems = []
            self.isLoading = false
            self.errorMessage = "Failed to load catalog"

        case .loaded:
            let mockItems = Self.createMockItems()
            self.items = mockItems
            self.filteredItems = mockItems
            self.sortedFilteredItems = mockItems
            self.isLoading = false
            self.errorMessage = nil

        case .filtered:
            let mockItems = Self.createMockItems()
            self.items = mockItems
            // Only show first item after "filtering"
            self.filteredItems = Array(mockItems.prefix(1))
            self.sortedFilteredItems = Array(mockItems.prefix(1))
            self.isLoading = false
            self.errorMessage = nil
            self.searchText = "Clear"
        }
    }

    // MARK: - Computed Properties

    var allAvailableTags: [String] {
        let allTags = Set(items.flatMap { $0.allTags })
        return allTags.sorted()
    }

    var allUserTags: Set<String> {
        let userTags = Set(items.flatMap { $0.userTags })
        return userTags
    }

    var allAvailableCOEs: [Int32] {
        let allCOEs = Set(items.map { $0.glassItem.coe })
        return allCOEs.sorted()
    }

    var availableManufacturers: [String] {
        let manufacturers = Set(items.map { $0.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) })
        return manufacturers.sorted()
    }

    var manufacturerCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for item in filteredItems {
            let mfr = item.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            counts[mfr, default: 0] += 1
        }
        return counts
    }

    var coeCounts: [Int32: Int] {
        var counts: [Int32: Int] = [:]
        for item in filteredItems {
            counts[item.glassItem.coe, default: 0] += 1
        }
        return counts
    }

    var tagCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for item in filteredItems {
            for tag in item.allTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No catalog items match '\(searchText)'"
        } else if !selectedTags.isEmpty {
            return "No catalog items match selected tags"
        } else if !selectedCOEs.isEmpty {
            return "No catalog items match selected COEs"
        } else if !selectedManufacturers.isEmpty {
            return "No catalog items match selected manufacturers"
        } else {
            return "No catalog items found"
        }
    }

    var hasData: Bool {
        !items.isEmpty
    }

    var hasActiveFilters: Bool {
        !searchText.isEmpty ||
        !selectedTags.isEmpty ||
        !selectedCOEs.isEmpty ||
        !selectedManufacturers.isEmpty ||
        selectedManufacturer != nil
    }

    // MARK: - Actions (Mock implementations)

    func loadData() async {
        loadDataCalled = true
        // Mock implementation - data already set in init
    }

    func refreshData() async {
        refreshDataCalled = true
        // Mock implementation - data already set in init
    }

    func clearSearch() {
        clearSearchCalled = true
        searchText = ""
        selectedTags.removeAll()
        selectedCOEs.removeAll()
        selectedManufacturers.removeAll()
        selectedManufacturer = nil
        searchClearedFeedback = true
    }

    func updateSorting(_ newSortOption: SortOption) {
        updateSortingCalled = true
        sortOption = newSortOption
        // Mock implementation - could sort if needed
    }

    func applyFilters() {
        applyFiltersCalled = true
        // Mock implementation - simple filtering
        var filtered = items

        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.glassItem.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        if !selectedTags.isEmpty {
            filtered = filtered.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        if !selectedCOEs.isEmpty {
            filtered = filtered.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        if !selectedManufacturers.isEmpty {
            filtered = filtered.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer)
            }
        }

        filteredItems = filtered
        sortedFilteredItems = filtered
    }

    // MARK: - Mock Data Helpers

    private static func createMockItems() -> [CompleteInventoryItemModel] {
        return [
            CompleteInventoryItemModel.mock(
                name: "Clear Rod",
                manufacturer: "bullseye",
                sku: "001",
                coe: 90,
                tags: ["transparent", "coe90"],
                userTags: []
            ),
            CompleteInventoryItemModel.mock(
                name: "Red Rod",
                manufacturer: "bullseye",
                sku: "254",
                coe: 90,
                tags: ["opaque", "coe90"],
                userTags: []
            ),
            CompleteInventoryItemModel.mock(
                name: "Blue Sheet",
                manufacturer: "spectrum",
                sku: "100",
                coe: 96,
                tags: ["transparent", "coe96"],
                userTags: []
            )
        ]
    }
}

// MARK: - Mock Data Extension

extension CompleteInventoryItemModel {
    /// Create a mock CompleteInventoryItemModel for testing and previews
    static func mock(
        name: String,
        manufacturer: String,
        sku: String = "mock",
        coe: Int32 = 96,
        inventory: [InventoryModel] = [],
        tags: [String] = [],
        userTags: [String] = []
    ) -> CompleteInventoryItemModel {
        // Generate a simple stable_id for mocking (format: first 3 of manufacturer + first 3 of sku)
        let mfrPrefix = String(manufacturer.prefix(3))
        let skuPrefix = String(sku.prefix(3))
        let stableId = "\(mfrPrefix)\(skuPrefix)".lowercased()

        let glassItem = GlassItemModel(
            stable_id: stableId,
            name: name,
            sku: sku,
            manufacturer: manufacturer,
            mfr_notes: "Mock item for testing",
            coe: coe,
            url: nil,
            mfr_status: "available"
        )
        return CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: inventory,
            tags: tags,
            userTags: userTags
        )
    }
}
