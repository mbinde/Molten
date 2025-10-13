//
//  InventoryViewModel.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import SwiftUI

/// SwiftUI ViewModel for inventory management using repository pattern
@MainActor
@Observable
class InventoryViewModel {
    private let inventoryService: InventoryService
    private let catalogService: CatalogService?
    
    // Published state
    var consolidatedItems: [ConsolidatedInventoryModel] = []
    var filteredItems: [InventoryItemModel] = []
    var isLoading = false
    var errorMessage: String?
    
    // Search and filter state
    var searchText = ""
    var selectedFilters: Set<InventoryItemType> = []
    
    init(inventoryService: InventoryService, catalogService: CatalogService? = nil) {
        self.inventoryService = inventoryService
        self.catalogService = catalogService
    }
    
    // MARK: - Service Access
    
    /// Access to inventory service for dependency injection
    var exposedInventoryService: InventoryService {
        inventoryService
    }
    
    /// Access to catalog service for dependency injection  
    var exposedCatalogService: CatalogService? {
        catalogService
    }
    
    // MARK: - Data Loading
    
    func loadInventoryItems() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load consolidated items
            consolidatedItems = try await inventoryService.getConsolidatedItems()
            
            // Load all items for filtering
            filteredItems = try await inventoryService.getAllItems()
            
        } catch {
            errorMessage = "Failed to load inventory: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Search Functionality
    
    func searchItems(searchText: String) async {
        self.searchText = searchText
        
        do {
            if searchText.isEmpty {
                filteredItems = try await inventoryService.getAllItems()
            } else {
                filteredItems = try await inventoryService.searchItems(searchText: searchText)
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Filter Functionality
    
    func filterItems(byType type: InventoryItemType) async {
        do {
            filteredItems = try await inventoryService.getItems(ofType: type)
        } catch {
            errorMessage = "Filter failed: \(error.localizedDescription)"
        }
    }
    
    func applyFilters() async {
        guard !selectedFilters.isEmpty else {
            await loadAllItems()
            return
        }
        
        do {
            var combinedResults: [InventoryItemModel] = []
            
            for filterType in selectedFilters {
                let typeResults = try await inventoryService.getItems(ofType: filterType)
                combinedResults.append(contentsOf: typeResults)
            }
            
            // Remove duplicates and update filtered items
            filteredItems = Array(Set(combinedResults.map(\.id)))
                .compactMap { id in combinedResults.first { $0.id == id } }
            
        } catch {
            errorMessage = "Filter application failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - CRUD Operations
    
    func addInventoryItem(_ item: InventoryItemModel) async {
        do {
            _ = try await inventoryService.createItem(item)
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to add item: \(error.localizedDescription)"
        }
    }
    
    func updateInventoryItem(_ item: InventoryItemModel) async {
        do {
            _ = try await inventoryService.updateItem(item)
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to update item: \(error.localizedDescription)"
        }
    }
    
    func deleteInventoryItem(id: String) async {
        do {
            try await inventoryService.deleteItem(id: id)
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
        }
    }
    
    func deleteInventoryItems(ids: [String]) async {
        do {
            try await inventoryService.deleteItems(ids: ids)
            await loadInventoryItems() // Refresh data
        } catch {
            errorMessage = "Failed to delete items: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAllItems() async {
        do {
            filteredItems = try await inventoryService.getAllItems()
        } catch {
            errorMessage = "Failed to load all items: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Computed Properties
    
    var hasData: Bool {
        !consolidatedItems.isEmpty || !filteredItems.isEmpty
    }
    
    var hasError: Bool {
        errorMessage != nil
    }
}
