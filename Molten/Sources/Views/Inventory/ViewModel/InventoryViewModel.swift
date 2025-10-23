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
class InventoryViewModel {
    private let inventoryTrackingService: InventoryTrackingService
    private let catalogService: CatalogService?
    
    // Published state - updated for new architecture
    var completeItems: [CompleteInventoryItemModel] = []
    var filteredItems: [CompleteInventoryItemModel] = []
    var isLoading = false
    var errorMessage: String?
    
    // Search and filter state - updated for new architecture
    var searchText = ""
    var selectedTypes: Set<String> = [] // String types instead of enum
    
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
    
    func applyFilters() async {
        guard !selectedTypes.isEmpty else {
            await loadInventoryItems()
            return
        }
        
        do {
            // Apply multiple type filters
            filteredItems = try await inventoryTrackingService.searchItems(
                text: searchText,
                withTags: [],
                hasInventory: true,
                inventoryTypes: Array(selectedTypes)
            )
            
        } catch {
            errorMessage = "Filter application failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - CRUD Operations - Updated for new architecture
    
    func addInventory(quantity: Double, type: String, toItemNaturalKey stableId: String) async {
        do {
            _ = try await inventoryTrackingService.addInventory(
                quantity: quantity,
                type: type,
                toItem: naturalKey,
                distributedTo: []
            )
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to add inventory: \(error.localizedDescription)"
        }
    }
    
    func updateInventory(_ inventory: InventoryModel) async {
        do {
            _ = try await inventoryTrackingService.inventoryRepository.updateInventory(inventory)
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to update inventory: \(error.localizedDescription)"
        }
    }
    
    func deleteInventory(id: UUID) async {
        do {
            try await inventoryTrackingService.inventoryRepository.deleteInventory(id: id)
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to delete inventory: \(error.localizedDescription)"
        }
    }
    
    func deleteInventories(ids: [UUID]) async {
        do {
            for id in ids {
                try await inventoryTrackingService.inventoryRepository.deleteInventory(id: id)
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
            return try await inventoryTrackingService.getInventorySummary(for: naturalKey)
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
                if let completeItem = try await inventoryTrackingService.getCompleteItem(stableId: lowStockItem.glassItem.natural_key) {
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
            item.inventory.map { $0.type }
        })
        return Array(allTypes).sorted()
    }
    
    /// Total items count
    var totalItemsCount: Int {
        completeItems.count
    }
    
    /// Filtered items count
    var filteredItemsCount: Int {
        filteredItems.count
    }
}

// MARK: - Factory Methods

extension InventoryViewModel {
    /// Create ViewModel using RepositoryFactory
    static func createWithRepositoryFactory() -> InventoryViewModel {
        RepositoryFactory.configureForTesting()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        let catalogService = RepositoryFactory.createCatalogService()
        
        return InventoryViewModel(
            inventoryTrackingService: inventoryTrackingService,
            catalogService: catalogService
        )
    }
    
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
