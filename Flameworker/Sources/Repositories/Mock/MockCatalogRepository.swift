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
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [CatalogItemModel] {
        return items
    }
    
    func createItem(_ item: CatalogItemModel) async throws -> CatalogItemModel {
        var newItem = item
        if newItem.id.isEmpty {
            newItem = CatalogItemModel(
                id: UUID().uuidString,
                name: item.name,
                code: item.code,
                manufacturer: item.manufacturer,
                tags: item.tags
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
            throw NSError(domain: "MockCatalogRepository", code: 404, 
                         userInfo: [NSLocalizedDescriptionKey: "Item with ID \(item.id) not found"])
        }
    }
    
    func deleteItem(id: String) async throws {
        items.removeAll { $0.id == id }
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
    
    // MARK: - Test Helper Methods
    
    /// Add test items for reliable test setup
    func addTestItems(_ testItems: [CatalogItemModel]) {
        items.append(contentsOf: testItems)
    }
    
    /// Reset repository state for clean tests
    func reset() {
        items.removeAll()
    }
}