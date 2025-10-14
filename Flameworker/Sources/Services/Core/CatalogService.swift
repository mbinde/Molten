//
//  CatalogService.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Service layer that handles catalog business logic using repository pattern
class CatalogService {
    private let repository: CatalogItemRepository
    private let inventoryService: InventoryService?
    
    init(repository: CatalogItemRepository, inventoryService: InventoryService? = nil) {
        self.repository = repository
        self.inventoryService = inventoryService
    }
    
    /// Get all catalog items
    func getAllItems() async throws -> [CatalogItemModel] {
        return try await repository.fetchItems(matching: nil)
    }
    
    /// Search catalog items by text
    func searchItems(searchText: String) async throws -> [CatalogItemModel] {
        return try await repository.searchItems(text: searchText)
    }
    
    /// Create a new catalog item
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        // Item already has processed code from constructor - just pass it through
        return try await repository.createItem(item)
    }
    
    /// Update an existing catalog item
    func updateItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        // Item already has processed code from constructor - just pass it through
        return try await repository.updateItem(item)
    }
    
    /// Delete a catalog item and cascade delete related inventory items
    func deleteItem(withId id: String) async throws {
        // First, get the item to find its code for inventory deletion
        let allItems = try await repository.fetchItems(matching: nil)
        guard let itemToDelete = allItems.first(where: { $0.id == id }) else {
            throw CatalogServiceError.itemNotFound
        }
        
        // Cascade delete: Remove all inventory items that reference this catalog code
        if let inventoryService = inventoryService {
            try await inventoryService.deleteItemsByCatalogCode(itemToDelete.code)
        }
        
        // Delete the catalog item
        try await repository.deleteItem(id: id)
    }
    
    /// Determine if an existing item should be updated with new data
    /// Uses the sophisticated change detection logic from CatalogItemModel
    func shouldUpdateItem(existing: CatalogItemModel, with new: CatalogItemModel) async throws -> Bool {
        // Use the sophisticated change detection logic from CatalogItemModel
        return CatalogItemModel.hasChanges(existing: existing, new: new)
    }
}

/// Errors that can occur in CatalogService
enum CatalogServiceError: Error {
    case itemNotFound
}