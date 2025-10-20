//
//  InventoryViewModel.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
//

import Foundation
import SwiftUI

/// ViewModel for managing inventory display and operations
/// Consolidates inventory items by catalog code and provides search/filter functionality
@MainActor
@Observable
class InventoryViewModel {
    
    // MARK: - Published Properties
    
    /// All inventory items from the repository
    private(set) var allInventoryItems: [InventoryItemModel] = []
    
    /// Catalog items for display names and details
    private(set) var catalogItems: [CatalogItemModel] = []
    
    /// Consolidated inventory items (grouped by catalog code)
    private(set) var consolidatedItems: [ConsolidatedInventoryModel] = []
    
    /// Filtered results based on search and filter criteria
    private(set) var filteredItems: [ConsolidatedInventoryModel] = []
    
    /// Current loading state
    private(set) var isLoading: Bool = false
    
    /// Current error state
    private(set) var currentError: Error?
    
    /// Search text for filtering items
    var searchText: String = "" {
        didSet {
            Task {
                await applyCurrentFilters()
            }
        }
    }
    
    /// Filter by inventory type
    var typeFilter: InventoryItemType?{
        didSet {
            Task {
                await applyCurrentFilters()
            }
        }
    }
    
    /// Filter by quantity threshold (show items below this quantity)
    var lowQuantityThreshold: Int?{
        didSet {
            Task {
                await applyCurrentFilters()
            }
        }
    }
    
    // MARK: - Dependencies
    
    private let inventoryService: InventoryService
    private let catalogService: CatalogService
    
    /// Exposed inventory service for view interactions
    var exposedInventoryService: InventoryService {
        inventoryService
    }
    
    /// Exposed catalog service for view interactions
    var exposedCatalogService: CatalogService {
        catalogService
    }
    
    /// Selected filters for UI state management
    var selectedFilters: Set<InventoryItemType> = []
    
    // MARK: - Initialization
    
    init(inventoryService: InventoryService, catalogService: CatalogService? = nil) {
        self.inventoryService = inventoryService
        self.catalogService = catalogService ?? CatalogService(repository: MockCatalogRepository())
    }
    
    /// Convenience initializer for testing with inventory service only
    init(inventoryService: InventoryService) {
        self.inventoryService = inventoryService
        self.catalogService = CatalogService(repository: MockCatalogRepository())
    }
    
    // MARK: - Data Loading
    
    /// Load all inventory items and catalog data
    func loadInventoryItems() async {
        isLoading = true
        currentError = nil
        
        do {
            async let inventoryItems = inventoryService.getAllItems()
            async let catalogItems = catalogService.getAllItems()
            
            (allInventoryItems, self.catalogItems) = try await (inventoryItems, catalogItems)
            
            await consolidateInventoryItems()
            await applyCurrentFilters()
            
        } catch {
            currentError = error
            allInventoryItems = []
            catalogItems = []
            consolidatedItems = []
            filteredItems = []
        }
        
        isLoading = false
    }
    
    /// Refresh data from repositories
    func refreshData() async {
        await loadInventoryItems()
    }
    
    // MARK: - Search and Filter
    
    /// Search inventory items by catalog code or name
    func searchItems(searchText: String) async {
        self.searchText = searchText
        await applyCurrentFilters()
    }
    
    /// Filter inventory items by type
    func filterItems(byType type: InventoryItemType?) async {
        self.typeFilter = type
        await applyCurrentFilters()
    }
    
    /// Filter items below quantity threshold
    func filterByLowQuantity(threshold: Int?) async {
        self.lowQuantityThreshold = threshold
        await applyCurrentFilters()
    }
    
    /// Clear all filters
    func clearFilters() async {
        searchText = ""
        typeFilter = nil
        lowQuantityThreshold = nil
        selectedFilters = []
        await applyCurrentFilters()
    }
    
    /// Apply filters without changing the filter criteria (used by UI)
    func applyFilters() async {
        await applyCurrentFilters()
    }
    
    // MARK: - Inventory Operations
    
    /// Create a new inventory item
    func createInventoryItem(_ item: InventoryItemModel) async throws {
        _ = try await inventoryService.createItem(item)
        await loadInventoryItems() // Refresh data
    }
    
    /// Update an existing inventory item
    func updateInventoryItem(_ item: InventoryItemModel) async throws {
        _ = try await inventoryService.updateItem(item)
        await loadInventoryItems() // Refresh data
    }
    
    /// Delete an inventory item
    func deleteInventoryItem(withId id: String) async throws {
        try await inventoryService.deleteItem(withId: id)
        await loadInventoryItems() // Refresh data
    }
    
    /// Bulk delete inventory items
    func deleteInventoryItems(withIds ids: [String]) async throws {
        for id in ids {
            try await inventoryService.deleteItem(withId: id)
        }
        await loadInventoryItems() // Refresh data
    }
    
    /// Bulk delete inventory items with array of IDs
    func deleteInventoryItems(ids: [String]) async {
        do {
            try await deleteInventoryItems(withIds: ids)
        } catch {
            await MainActor.run {
                currentError = error
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Consolidate inventory items by catalog code
    private func consolidateInventoryItems() async {
        let grouped = Dictionary(grouping: allInventoryItems, by: { $0.catalogCode })
        
        consolidatedItems = grouped.compactMap { catalogCode, items in
            // Find matching catalog item for display information
            let catalogItem = catalogItems.first { $0.code == catalogCode }
            
            // Create consolidated model with catalog information if available
            let consolidatedItem = ConsolidatedInventoryModel(catalogCode: catalogCode, items: items)
            
            return consolidatedItem
        }.sorted { $0.catalogCode < $1.catalogCode }
    }
    
    /// Apply current filters to consolidated items
    private func applyCurrentFilters() async {
        var filtered = consolidatedItems
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.catalogCode.localizedCaseInsensitiveContains(searchText) ||
                item.displayName.localizedCaseInsensitiveContains(searchText) ||
                item.manufacturer.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply type filter
        if let typeFilter = typeFilter {
            filtered = filtered.filter { item in
                item.items.contains { $0.type == typeFilter }
            }
        }
        
        // Apply low quantity filter
        if let threshold = lowQuantityThreshold {
            filtered = filtered.filter { item in
                item.totalInventoryCount < Double(threshold)
            }
        }
        
        filteredItems = filtered
    }
}

