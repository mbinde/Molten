//
//  CatalogViewModel.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//

import Foundation
import SwiftUI

/// ViewModel for managing catalog display and operations
/// Provides search, filtering, and sorting functionality for catalog items
@MainActor
@Observable
class CatalogViewModel {
    
    // MARK: - Published Properties
    
    /// All catalog items from the repository
    private(set) var allCatalogItems: [CatalogItemModel] = []
    
    /// Filtered results based on search and filter criteria
    private(set) var filteredItems: [CatalogItemModel] = []
    
    /// Sorted and filtered items for display
    private(set) var sortedFilteredItems: [CatalogItemModel] = []
    
    /// Current loading state
    private(set) var isLoading: Bool = false
    
    /// Current error state
    private(set) var currentError: Error?
    
    /// Search text for filtering items
    var searchText: String = "" {
        didSet {
            Task {
                await applyFiltersAndSort()
            }
        }
    }
    
    /// Current sort option
    var sortOption: CatalogSortOption = .name {
        didSet {
            Task {
                await applySorting()
            }
        }
    }
    
    /// Selected tags for filtering
    var selectedTags: Set<String> = [] {
        didSet {
            Task {
                await applyFiltersAndSort()
            }
        }
    }
    
    /// Selected manufacturer for filtering
    var selectedManufacturer: String? = nil {
        didSet {
            Task {
                await applyFiltersAndSort()
            }
        }
    }
    
    /// Set of enabled manufacturers (from user preferences)
    var enabledManufacturers: Set<String> = [] {
        didSet {
            Task {
                await applyFiltersAndSort()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// All available tags from current catalog items
    var allAvailableTags: [String] {
        let tags = filteredItemsBeforeTags.flatMap { $0.tags }
        return Array(Set(tags)).sorted()
    }
    
    /// Available manufacturers from enabled manufacturers that have items
    var availableManufacturers: [String] {
        let manufacturers = catalogItemsFilteredByManufacturers
            .map { $0.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return Array(Set(manufacturers)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    /// Items filtered only by enabled manufacturers (before other filters)
    private var catalogItemsFilteredByManufacturers: [CatalogItemModel] {
        if enabledManufacturers.isEmpty {
            return allCatalogItems
        } else {
            return allCatalogItems.filter { enabledManufacturers.contains($0.manufacturer) }
        }
    }
    
    /// Items filtered by enabled manufacturers and specific manufacturer (before tag filter)
    private var filteredItemsBeforeTags: [CatalogItemModel] {
        var items = catalogItemsFilteredByManufacturers
        
        // Apply specific manufacturer filter if one is selected
        if let selectedManufacturer = selectedManufacturer {
            items = items.filter { $0.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) == selectedManufacturer }
        }
        
        // Apply text search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.code.localizedCaseInsensitiveContains(searchText) ||
                item.manufacturer.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    // MARK: - Dependencies
    
    private let catalogService: CatalogService
    
    // MARK: - Initialization
    
    init(catalogService: CatalogService) {
        self.catalogService = catalogService
    }
    
    // MARK: - Data Loading
    
    /// Load all catalog items from the repository
    func loadCatalogItems() async {
        isLoading = true
        currentError = nil
        
        do {
            allCatalogItems = try await catalogService.getAllItems()
            await applyFiltersAndSort()
        } catch {
            currentError = error
            allCatalogItems = []
            filteredItems = []
            sortedFilteredItems = []
        }
        
        isLoading = false
    }
    
    /// Refresh data from repository
    func refreshData() async {
        await loadCatalogItems()
    }
    
    // MARK: - Search and Filter Operations
    
    /// Search catalog items by text
    func searchItems(searchText: String) async {
        self.searchText = searchText
        await applyFiltersAndSort()
    }
    
    /// Filter by manufacturer
    func filterByManufacturer(_ manufacturer: String?) async {
        self.selectedManufacturer = manufacturer
        await applyFiltersAndSort()
    }
    
    /// Filter by tags
    func filterByTags(_ tags: Set<String>) async {
        self.selectedTags = tags
        await applyFiltersAndSort()
    }
    
    /// Toggle tag selection
    func toggleTag(_ tag: String) async {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        await applyFiltersAndSort()
    }
    
    /// Clear all filters
    func clearFilters() async {
        searchText = ""
        selectedTags = []
        selectedManufacturer = nil
        await applyFiltersAndSort()
    }
    
    /// Update enabled manufacturers
    func updateEnabledManufacturers(_ manufacturers: Set<String>) async {
        self.enabledManufacturers = manufacturers
        await applyFiltersAndSort()
    }
    
    // MARK: - Sorting Operations
    
    /// Change sort option
    func changeSortOption(_ option: CatalogSortOption) async {
        self.sortOption = option
        await applySorting()
    }
    
    // MARK: - Catalog Operations
    
    /// Create a new catalog item
    func createCatalogItem(_ item: CatalogItemModel) async throws {
        _ = try await catalogService.createItem(item)
        await loadCatalogItems() // Refresh data
    }
    
    /// Update an existing catalog item
    func updateCatalogItem(_ item: CatalogItemModel) async throws {
        _ = try await catalogService.updateItem(item)
        await loadCatalogItems() // Refresh data
    }
    
    /// Delete a catalog item
    func deleteCatalogItem(withId id: String) async throws {
        try await catalogService.deleteItem(withId: id)
        await loadCatalogItems() // Refresh data
    }
    
    /// Get catalog item by code
    func getCatalogItem(byCode code: String) async throws -> CatalogItemModel? {
        return try await catalogService.getItem(byCode: code)
    }
    
    // MARK: - Private Methods
    
    /// Apply all filters and sorting
    private func applyFiltersAndSort() async {
        await applyFilters()
        await applySorting()
    }
    
    /// Apply current filters to catalog items
    private func applyFilters() async {
        var filtered = catalogItemsFilteredByManufacturers
        
        // Apply specific manufacturer filter
        if let selectedManufacturer = selectedManufacturer {
            filtered = filtered.filter { $0.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) == selectedManufacturer }
        }
        
        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { item in
                !selectedTags.isDisjoint(with: Set(item.tags))
            }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.code.localizedCaseInsensitiveContains(searchText) ||
                item.manufacturer.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        filteredItems = filtered
    }
    
    /// Apply current sorting to filtered items
    private func applySorting() async {
        sortedFilteredItems = filteredItems.sorted { item1, item2 in
            switch sortOption {
            case .name:
                return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
            case .manufacturer:
                return item1.manufacturer.localizedCaseInsensitiveCompare(item2.manufacturer) == .orderedAscending
            case .code:
                return item1.code.localizedCaseInsensitiveCompare(item2.code) == .orderedAscending
            }
        }
    }
}

// MARK: - CatalogSortOption

/// Sorting options for catalog items
enum CatalogSortOption: String, CaseIterable, Identifiable {
    case name = "name"
    case manufacturer = "manufacturer"
    case code = "code"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .manufacturer: return "Manufacturer"
        case .code: return "Code"
        }
    }
}