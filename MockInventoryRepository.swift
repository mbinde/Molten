//
//  MockInventoryRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Mock implementation of InventoryItemRepository for testing
class MockInventoryRepository: InventoryItemRepository {
    private var items: [InventoryItemModel] = []
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [InventoryItemModel] {
        // Simple implementation - return all items (predicate parsing can be added later)
        return items
    }
    
    func fetchItem(byId id: String) async throws -> InventoryItemModel? {
        return items.first { $0.id == id }
    }
    
    func createItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        var newItem = item
        if newItem.id.isEmpty {
            newItem = InventoryItemModel(
                id: UUID().uuidString,
                catalogCode: item.catalogCode,
                quantity: item.quantity,
                type: item.type,
                notes: item.notes,
                dateAdded: item.dateAdded
            )
        }
        items.append(newItem)
        return newItem
    }
    
    func updateItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            return item
        } else {
            throw NSError(domain: "MockRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
        }
    }
    
    func deleteItem(id: String) async throws {
        items.removeAll { $0.id == id }
    }
    
    // MARK: - Search & Filter Operations
    
    func searchItems(text: String) async throws -> [InventoryItemModel] {
        guard !text.isEmpty else { return items }
        return items.filter { $0.matchesSearchText(text) }
    }
    
    func fetchItems(byType type: InventoryItemType) async throws -> [InventoryItemModel] {
        return items.filter { $0.type == type }
    }
    
    func fetchItems(byCatalogCode catalogCode: String) async throws -> [InventoryItemModel] {
        return items.filter { $0.catalogCode == catalogCode }
    }
    
    // MARK: - Business Logic Operations
    
    func getTotalQuantity(forCatalogCode catalogCode: String, type: InventoryItemType) async throws -> Int {
        return items
            .filter { $0.catalogCode == catalogCode && $0.type == type }
            .reduce(0) { $0 + $1.quantity }
    }
    
    func getDistinctCatalogCodes() async throws -> [String] {
        return Array(Set(items.map { $0.catalogCode })).sorted()
    }
    
    func consolidateItems(byCatalogCode: Bool) async throws -> [ConsolidatedInventoryModel] {
        guard byCatalogCode else { return [] } // Simplified implementation
        
        let grouped = Dictionary(grouping: items) { $0.catalogCode }
        return grouped.map { (catalogCode, items) in
            ConsolidatedInventoryModel(catalogCode: catalogCode, items: items)
        }.sorted { $0.catalogCode < $1.catalogCode }
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        items.removeAll()
    }
    
    func addTestItems(_ testItems: [InventoryItemModel]) {
        items.append(contentsOf: testItems)
    }
}