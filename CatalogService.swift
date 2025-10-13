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
    
    init(repository: CatalogItemRepository) {
        self.repository = repository
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
    
    /// Determine if an existing item should be updated with new data
    /// This extracts the change detection logic from CatalogItemManager.shouldUpdateExistingItem()
    func shouldUpdateItem(existing: CatalogItemModel, with new: CatalogItemModel) async throws -> Bool {
        // Extract the sophisticated change detection logic from CatalogItemManager
        return CatalogItemModel.hasChanges(existing: existing, new: new)
    }
}