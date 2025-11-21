//
//  InventoryViewModel.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  Updated for GlassItem Architecture on 10/14/25.
//

import Foundation
import SwiftUI

/// SwiftUI ViewModel for inventory management using new GlassItem architecture
@MainActor
@Observable
class InventoryViewModel: InventoryViewModelProtocol {
    private let inventoryTrackingService: InventoryTrackingService
    private let catalogService: CatalogService?
    
    // Published state - updated for new architecture
    var completeItems: [CompleteInventoryItemModel] = []
    var filteredItems: [CompleteInventoryItemModel] = []
    var isLoading = false
    var errorMessage: String?
    
    // Search and filter state - updated for new architecture
    var searchText = ""
    var searchTitlesOnly = false
    var selectedTypes: Set<String> = [] // String types instead of enum
    var selectedProductTypes: Set<String> = [] // Product type filter (glass, coating, tool) - defaults to all
    var selectedTags: Set<String> = []
    var selectedCOEs: Set<Int32> = []
    var selectedManufacturers: Set<String> = []
    var sortOption: InventorySortOption = .name
    
    init(inventoryTrackingService: InventoryTrackingService, catalogService: CatalogService? = nil) {
        self.inventoryTrackingService = inventoryTrackingService
        self.catalogService = catalogService
    }
    
    // MARK: - Service Access
    
    /// Access to inventory tracking service for dependency injection
    var exposedInventoryTrackingService: InventoryTrackingService {
        inventoryTrackingService
    }
    
    /// Access to catalog service for dependency injection  
    var exposedCatalogService: CatalogService? {
        catalogService
    }
    
    // MARK: - Data Loading
    
    func loadInventoryItems() async {
        isLoading = true
        errorMessage = nil

        // Load complete items using new architecture with cache
        if let catalogService = catalogService {
            completeItems = await CatalogDataCache.loadItems(using: catalogService)
            filteredItems = completeItems
        } else {
            // Fallback: load through inventory tracking service
            // Since there's no getInventorySummaries method, we use an empty set for now
            // In practice, this path would rarely be used since catalogService is typically provided
            completeItems = []
            filteredItems = []

            // TODO: Could implement by getting all inventory items and converting them
            // but this would require knowing all glass item natural keys
            errorMessage = "Catalog service required for full inventory loading"
        }

        isLoading = false
    }
    
    // MARK: - Search Functionality
    
    func searchItems(searchText: String) async {
        self.searchText = searchText
        
        do {
            if searchText.isEmpty {
                await loadInventoryItems()
            } else {
                // Use inventory tracking service search
                filteredItems = try await inventoryTrackingService.searchItems(
                    text: searchText,
                    withTags: [],
                    hasInventory: true,
                    inventoryTypes: []
                )
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Filter Functionality
    
    func filterItems(byType type: String) async {
        do {
            // Filter using inventory tracking service
            filteredItems = try await inventoryTrackingService.searchItems(
                text: "",
                withTags: [],
                hasInventory: true,
                inventoryTypes: [type]
            )
        } catch {
            errorMessage = "Filter failed: \(error.localizedDescription)"
        }
    }
    
    func applyFilters() {
        var filtered = completeItems

        // Apply product type filter
        if !selectedProductTypes.isEmpty {
            filtered = filtered.filter { item in
                selectedProductTypes.contains(item.catalogItem.itemType.rawValue)
            }
        }

        // Apply manufacturer filter
        if !selectedManufacturers.isEmpty {
            filtered = filtered.filter { item in
                selectedManufacturers.contains(item.catalogItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        // Apply COE filter
        if !selectedCOEs.isEmpty {
            filtered = filtered.filter { item in
                if let coe = item.catalogItem.coe {
                    return selectedCOEs.contains(coe)
                }
                return false
            }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        // Apply inventory type filter (rod, tube, frit, etc.)
        if !selectedTypes.isEmpty {
            filtered = filtered.filter { item in
                item.inventory.contains { inventory in
                    selectedTypes.contains(inventory.type)
                }
            }
        }

        // Apply search text filter
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                let name = item.catalogItem.name
                let manufacturer = item.catalogItem.manufacturer
                let sku = item.catalogItem.sku ?? ""
                let stableId = item.catalogItem.stable_id

                return name.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       sku.localizedCaseInsensitiveContains(searchText) ||
                       stableId.localizedCaseInsensitiveContains(searchText)
            }
        }

        filteredItems = filtered
    }
    
    // MARK: - CRUD Operations - Updated for new architecture
    
    func addInventory(quantity: Double, type: String, toItemNaturalKey stableId: String) async {
        do {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: type,
                toItem: stableId,
                atLocation: nil
            )
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to add inventory: \(error.localizedDescription)"
        }
    }
    
    func updateInventory(_ inventory: InventoryModel) async {
        do {
            _ = try await inventoryTrackingService.updateInventory(inventory)
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to update inventory: \(error.localizedDescription)"
        }
    }
    
    func deleteInventory(id: UUID) async {
        do {
            try await inventoryTrackingService.deleteInventory(id: id)
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to delete inventory: \(error.localizedDescription)"
        }
    }
    
    func deleteInventories(ids: [UUID]) async {
        do {
            for id in ids {
                try await inventoryTrackingService.deleteInventory(id: id)
            }
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to delete inventories: \(error.localizedDescription)"
        }
    }
    
    // MARK: - New Architecture Methods
    
    /// Get detailed inventory summary for an item
    func getDetailedInventorySummary(for stableId: String) async -> DetailedInventorySummaryModel? {
        do {
            return try await inventoryTrackingService.getInventorySummary(for: stableId)
        } catch {
            errorMessage = "Failed to get inventory summary: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Get low stock items
    func getLowStockItems(threshold: Double = 5.0) async {
        do {
            let lowStockItems = try await inventoryTrackingService.getLowStockItems(threshold: threshold)
            
            // Convert low stock items to complete inventory items for display
            var lowStockCompleteItems: [CompleteInventoryItemModel] = []
            
            for lowStockItem in lowStockItems {
                if let completeItem = try await inventoryTrackingService.getCompleteItem(stableId: lowStockItem.glassItem.stable_id) {
                    lowStockCompleteItems.append(completeItem)
                }
            }
            
            filteredItems = lowStockCompleteItems
            
        } catch {
            errorMessage = "Failed to get low stock items: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAllItems() async {
        await loadInventoryItems()
    }
    
    // MARK: - Computed Properties
    
    var hasData: Bool {
        !completeItems.isEmpty || !filteredItems.isEmpty
    }
    
    var hasError: Bool {
        errorMessage != nil
    }
    
    /// Available inventory types for filtering
    var availableInventoryTypes: [String] {
        let allTypes = Set(completeItems.flatMap { item in
            item.inventory.compactMap { $0.type }
        })
        return Array(allTypes).sorted()
    }

    /// Available tags for filtering
    var availableTags: [String] {
        let allTags = Set(completeItems.flatMap { $0.allTags })
        return allTags.sorted()
    }

    /// Available COEs for filtering
    var availableCOEs: [Int32] {
        let allCOEs = Set(completeItems.map { $0.glassItem.coe })
        return allCOEs.sorted()
    }

    /// Available manufacturers for filtering
    var availableManufacturers: [String] {
        let manufacturers = Set(completeItems.map { $0.glassItem.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines) })
        return manufacturers.sorted()
    }

    /// Total items count
    var totalItemsCount: Int {
        completeItems.count
    }

    /// Filtered items count
    var filteredItemsCount: Int {
        filteredItems.count
    }

    // MARK: - Filter Counts

    var manufacturerCounts: [String: Int] {
        computeManufacturerCounts()
    }

    var coeCounts: [Int32: Int] {
        computeCOECounts()
    }

    var tagCounts: [String: Int] {
        computeTagCounts()
    }

    // MARK: - Filter Count Computation

    /// Count items per manufacturer based on current filters (excluding manufacturer filter itself)
    private func computeManufacturerCounts() -> [String: Int] {
        var items = completeItems.filter { $0.totalQuantity > 0 }

        // Apply all filters EXCEPT manufacturer
        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        if !selectedTypes.isEmpty {
            items = items.filter { item in
                item.inventory.contains { inventory in
                    selectedTypes.contains(inventory.type)
                }
            }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.glassItem.name
                let manufacturer = item.glassItem.manufacturer
                let sku = item.glassItem.sku ?? ""
                let stableId = item.glassItem.stable_id

                return name.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       sku.localizedCaseInsensitiveContains(searchText) ||
                       stableId.localizedCaseInsensitiveContains(searchText)
            }
        }

        var counts: [String: Int] = [:]
        for item in items {
            counts[item.glassItem.manufacturer, default: 0] += 1
        }
        return counts
    }

    /// Count items per COE based on current filters (excluding COE filter itself)
    private func computeCOECounts() -> [Int32: Int] {
        var items = completeItems.filter { $0.totalQuantity > 0 }

        // Apply all filters EXCEPT COE
        if !selectedManufacturers.isEmpty {
            items = items.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer)
            }
        }

        if !selectedTags.isEmpty {
            items = items.filter { item in
                !selectedTags.isDisjoint(with: Set(item.allTags))
            }
        }

        if !selectedTypes.isEmpty {
            items = items.filter { item in
                item.inventory.contains { inventory in
                    selectedTypes.contains(inventory.type)
                }
            }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.glassItem.name
                let manufacturer = item.glassItem.manufacturer
                let sku = item.glassItem.sku ?? ""
                let stableId = item.glassItem.stable_id

                return name.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       sku.localizedCaseInsensitiveContains(searchText) ||
                       stableId.localizedCaseInsensitiveContains(searchText)
            }
        }

        var counts: [Int32: Int] = [:]
        for item in items {
            counts[item.glassItem.coe, default: 0] += 1
        }
        return counts
    }

    /// Count items per tag based on current filters (excluding tag filter itself)
    private func computeTagCounts() -> [String: Int] {
        var items = completeItems.filter { $0.totalQuantity > 0 }

        // Apply all filters EXCEPT tags
        if !selectedManufacturers.isEmpty {
            items = items.filter { item in
                selectedManufacturers.contains(item.glassItem.manufacturer)
            }
        }

        if !selectedCOEs.isEmpty {
            items = items.filter { item in
                selectedCOEs.contains(item.glassItem.coe)
            }
        }

        if !selectedTypes.isEmpty {
            items = items.filter { item in
                item.inventory.contains { inventory in
                    selectedTypes.contains(inventory.type)
                }
            }
        }

        if !searchText.isEmpty {
            items = items.filter { item in
                let name = item.glassItem.name
                let manufacturer = item.glassItem.manufacturer
                let sku = item.glassItem.sku ?? ""
                let stableId = item.glassItem.stable_id

                return name.localizedCaseInsensitiveContains(searchText) ||
                       manufacturer.localizedCaseInsensitiveContains(searchText) ||
                       sku.localizedCaseInsensitiveContains(searchText) ||
                       stableId.localizedCaseInsensitiveContains(searchText)
            }
        }

        var counts: [String: Int] = [:]
        for item in items {
            for tag in item.allTags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }
}

// MARK: - Factory Methods

extension InventoryViewModel {
    /// Create ViewModel with custom services
    static func create(
        inventoryTrackingService: InventoryTrackingService,
        catalogService: CatalogService?
    ) -> InventoryViewModel {
        return InventoryViewModel(
            inventoryTrackingService: inventoryTrackingService,
            catalogService: catalogService
        )
    }
}
