//
//  InventoryService.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Service layer that handles inventory business logic using repository pattern
class InventoryService {
    private let repository: InventoryItemRepository
    
    init(repository: InventoryItemRepository) {
        self.repository = repository
    }
    
    // MARK: - Basic CRUD Operations
    
    /// Get all inventory items
    func getAllItems() async throws -> [InventoryItemModel] {
        return try await repository.fetchItems(matching: nil)
    }
    
    /// Create a new inventory item
    func createItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        return try await repository.createItem(item)
    }
    
    /// Update an existing inventory item
    func updateItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        return try await repository.updateItem(item)
    }
    
    /// Delete an inventory item
    func deleteItem(id: String) async throws {
        try await repository.deleteItem(id: id)
    }
    
    // MARK: - Search & Filter Operations
    
    /// Search inventory items by text
    func searchItems(searchText: String) async throws -> [InventoryItemModel] {
        return try await repository.searchItems(text: searchText)
    }
    
    /// Get items filtered by type
    func getItems(ofType type: InventoryItemType) async throws -> [InventoryItemModel] {
        return try await repository.fetchItems(byType: type)
    }
    
    /// Get items by catalog code
    func getItems(byCatalogCode catalogCode: String) async throws -> [InventoryItemModel] {
        return try await repository.fetchItems(byCatalogCode: catalogCode)
    }
    
    // MARK: - Business Logic Operations
    
    /// Get consolidated items grouped by catalog code
    func getConsolidatedItems() async throws -> [ConsolidatedInventoryModel] {
        return try await repository.consolidateItems(byCatalogCode: true)
    }
    
    /// Get total quantity for a catalog code and type
    func getTotalQuantity(catalogCode: String, type: InventoryItemType) async throws -> Double {
        return try await repository.getTotalQuantity(forCatalogCode: catalogCode, type: type)
    }
    
    /// Get distinct catalog codes in inventory
    func getDistinctCatalogCodes() async throws -> [String] {
        return try await repository.getDistinctCatalogCodes()
    }
    
    /// Determine if an existing item should be updated with new data
    func shouldUpdateItem(existing: InventoryItemModel, with new: InventoryItemModel) -> Bool {
        return InventoryItemModel.hasChanges(existing: existing, new: new)
    }
    
    // MARK: - Batch Operations
    
    /// Create multiple inventory items efficiently
    func createItems(_ items: [InventoryItemModel]) async throws -> [InventoryItemModel] {
        return try await repository.createItems(items)
    }
    
    /// Delete multiple inventory items by IDs efficiently
    func deleteItems(ids: [String]) async throws {
        try await repository.deleteItems(ids: ids)
    }
    
    /// Delete all inventory items that reference a specific catalog code
    func deleteItemsByCatalogCode(_ catalogCode: String) async throws {
        try await repository.deleteItems(byCatalogCode: catalogCode)
    }
}