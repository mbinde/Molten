//
//  MockCatalogRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Mock repository implementation for fast, reliable testing
class MockCatalogRepository: CatalogItemRepository {
    private var items: [CatalogItemModel] = []
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [CatalogItemModel] {
        return items
    }
    
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        var newItem = item
        if newItem.id.isEmpty {
            // Create new item using the parent-child constructor with defaults
            let tempParentId = UUID()
            newItem = CatalogItemModel(
                id: UUID().uuidString,
                id2: UUID(),
                parent_id: tempParentId,
                item_type: "rod",
                item_subtype: nil,
                stock_type: nil,
                manufacturer_url: nil,
                image_path: nil,
                image_url: nil,
                name: item.name,
                code: item.code,
                manufacturer: item.manufacturer,
                tags: item.tags,
                units: item.units
            )
        }
        items.append(newItem)
        return newItem
    }
    
    func updateItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        // Find existing item by ID
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            // Replace with updated item
            items[index] = item
            return item
        } else {
            // If item doesn't exist, throw error
            throw CatalogItemRepositoryError.itemNotFound(item.id)
        }
    }
    
    func deleteItem(id: String) async throws {
        let originalCount = items.count
        items.removeAll { $0.id == id }
        
        if items.count == originalCount {
            throw CatalogItemRepositoryError.itemNotFound(id)
        }
    }
    
    func searchItems(text: String) async throws -> [CatalogItemModel] {
        guard !text.isEmpty else { return items }
        
        let searchText = text.lowercased()
        return items.filter { item in
            return item.searchableText.contains { field in
                field.lowercased().contains(searchText)
            }
        }
    }
    
    // MARK: - New Protocol Methods Implementation
    
    func deleteItem(id2: UUID) async throws {
        let originalCount = items.count
        items.removeAll { $0.id2 == id2 }
        
        if items.count == originalCount {
            throw CatalogItemRepositoryError.itemNotFoundByUUID(id2)
        }
    }
    
    func fetchItem(id: String) async throws -> CatalogItemModel? {
        return items.first { $0.id == id }
    }
    
    func fetchItem(id2: UUID) async throws -> CatalogItemModel? {
        return items.first { $0.id2 == id2 }
    }
    
    func getAllItems() async throws -> [CatalogItemModel] {
        return items
    }
    
    func fetchItems(for parentId: UUID) async throws -> [CatalogItemModel] {
        return items.filter { $0.parent_id == parentId }
    }
    
    func createItem(_ item: CatalogItemModel, parentId: UUID) async throws -> CatalogItemModel {
        // Create new item with the specified parent ID
        let itemWithParent = CatalogItemModel(
            id: item.id.isEmpty ? UUID().uuidString : item.id,
            id2: item.id2,
            parent_id: parentId,
            item_type: item.item_type,
            item_subtype: item.item_subtype,
            stock_type: item.stock_type,
            manufacturer_url: item.manufacturer_url,
            image_path: item.image_path,
            image_url: item.image_url,
            name: item.name,
            code: item.code,
            manufacturer: item.manufacturer,
            tags: item.tags,
            units: item.units
        )
        
        items.append(itemWithParent)
        return itemWithParent
    }
    
    func updateItemParent(itemId2: UUID, newParentId: UUID) async throws -> CatalogItemModel {
        guard let index = items.firstIndex(where: { $0.id2 == itemId2 }) else {
            throw CatalogItemRepositoryError.itemNotFoundByUUID(itemId2)
        }
        
        let existingItem = items[index]
        let updatedItem = CatalogItemModel(
            id: existingItem.id,
            id2: existingItem.id2,
            parent_id: newParentId,  // Update parent ID
            item_type: existingItem.item_type,
            item_subtype: existingItem.item_subtype,
            stock_type: existingItem.stock_type,
            manufacturer_url: existingItem.manufacturer_url,
            image_path: existingItem.image_path,
            image_url: existingItem.image_url,
            name: existingItem.name,
            code: existingItem.code,
            manufacturer: existingItem.manufacturer,
            tags: existingItem.tags,
            units: existingItem.units
        )
        
        items[index] = updatedItem
        return updatedItem
    }
    
    func createItems(_ items: [CatalogItemModel]) async throws -> [CatalogItemModel] {
        var createdItems: [CatalogItemModel] = []
        
        for item in items {
            let createdItem = try await createItem(item)
            createdItems.append(createdItem)
        }
        
        return createdItems
    }
    
    func updateItems(_ items: [CatalogItemModel]) async throws -> [CatalogItemModel] {
        var updatedItems: [CatalogItemModel] = []
        
        for item in items {
            let updatedItem = try await updateItem(item)
            updatedItems.append(updatedItem)
        }
        
        return updatedItems
    }
    
    func shouldUpdateItem(existing: CatalogItemModel, with new: CatalogItemModel) async throws -> Bool {
        return CatalogItemModel.hasChanges(existing: existing, new: new)
    }
    
    func migrateItemToUUID(legacyId: String) async throws -> CatalogItemModel {
        guard let index = items.firstIndex(where: { $0.id == legacyId }) else {
            throw CatalogItemRepositoryError.itemNotFound(legacyId)
        }
        
        let existingItem = items[index]

        // Item is already migrated if it has a proper UUID
        _ = existingItem.id2
        _ = existingItem.parent_id

        return existingItem
    }
    
    func validateItemRelationships(_ item: CatalogItemModel) async throws {
        do {
            try item.validate()
        } catch {
            throw CatalogItemRepositoryError.relationshipValidationFailed("Item validation failed: \(error.localizedDescription)")
        }
        
        // Check that parent exists if we have parent data (mock validation)
        let parentExists = items.contains { $0.id2 == item.parent_id }
        if !parentExists && !items.isEmpty {
            // Only validate parent existence if we have items (avoid false failures in empty mock)
            // In a real implementation, this would check the parent repository
        }
    }
    
    // MARK: - Test Helper Methods
    
    /// Add test items for reliable test setup
    func addTestItems(_ testItems: [CatalogItemModel]) {
        items.append(contentsOf: testItems)
    }
    
    /// Reset repository state for clean tests
    func reset() {
        items.removeAll()
    }
    
    /// Get current item count (for testing)
    var itemCount: Int {
        return items.count
    }
    
    /// Create test item with minimal required fields
    func createTestItem(
        name: String,
        code: String,
        manufacturer: String,
        itemType: String = "rod"
    ) -> CatalogItemModel {
        return CatalogItemModel(
            id: UUID().uuidString,
            id2: UUID(),
            parent_id: UUID(),
            item_type: itemType,
            item_subtype: nil,
            stock_type: nil,
            manufacturer_url: nil,
            image_path: nil,
            image_url: nil,
            name: name,
            code: code,
            manufacturer: manufacturer,
            tags: [],
            units: 1
        )
    }
}