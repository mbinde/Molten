//
//  CoreDataInventoryRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import CoreData

/// Core Data implementation of InventoryItemRepository for production use
class CoreDataInventoryRepository: InventoryItemRepository {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Basic CRUD Operations
    
    func fetchItems(matching predicate: NSPredicate?) async throws -> [InventoryItemModel] {
        let context = persistenceController.container.viewContext
        
        return try await context.perform {
            let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            fetchRequest.predicate = predicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.id, ascending: true)]
            
            let coreDataItems = try context.fetch(fetchRequest)
            return coreDataItems.map { $0.toModel() }
        }
    }
    
    func fetchItem(byId id: String) async throws -> InventoryItemModel? {
        let predicate = NSPredicate(format: "id == %@", id)
        let items = try await fetchItems(matching: predicate)
        return items.first
    }
    
    func createItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let coreDataItem = InventoryItem(context: context)
            coreDataItem.id = item.id
            coreDataItem.catalog_code = item.catalogCode
            coreDataItem.count = Double(item.quantity)
            coreDataItem.type = item.type.rawValue
            coreDataItem.notes = item.notes
            
            try context.save()
            
            return coreDataItem.toModel()
        }
    }
    
    func updateItem(_ item: InventoryItemModel) async throws -> InventoryItemModel {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", item.id)
            fetchRequest.fetchLimit = 1
            
            guard let coreDataItem = try context.fetch(fetchRequest).first else {
                throw NSError(domain: "CoreDataRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found"])
            }
            
            coreDataItem.catalog_code = item.catalogCode
            coreDataItem.count = Double(item.quantity)
            coreDataItem.type = item.type.rawValue
            coreDataItem.notes = item.notes
            
            try context.save()
            
            return coreDataItem.toModel()
        }
    }
    
    func deleteItem(id: String) async throws {
        let context = persistenceController.container.newBackgroundContext()
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            
            let items = try context.fetch(fetchRequest)
            for item in items {
                context.delete(item)
            }
            
            try context.save()
        }
    }
    
    // MARK: - Search & Filter Operations
    
    func searchItems(text: String) async throws -> [InventoryItemModel] {
        guard !text.isEmpty else {
            return try await fetchItems(matching: nil)
        }
        
        let predicate = NSPredicate(format: "catalog_code CONTAINS[cd] %@ OR notes CONTAINS[cd] %@", text, text)
        return try await fetchItems(matching: predicate)
    }
    
    func fetchItems(byType type: InventoryItemType) async throws -> [InventoryItemModel] {
        let predicate = NSPredicate(format: "type == %d", type.rawValue)
        return try await fetchItems(matching: predicate)
    }
    
    func fetchItems(byCatalogCode catalogCode: String) async throws -> [InventoryItemModel] {
        let predicate = NSPredicate(format: "catalog_code == %@", catalogCode)
        return try await fetchItems(matching: predicate)
    }
    
    // MARK: - Business Logic Operations
    
    func getTotalQuantity(forCatalogCode catalogCode: String, type: InventoryItemType) async throws -> Double {
        let items = try await fetchItems(byCatalogCode: catalogCode)
        return items
            .filter { $0.type == type }
            .reduce(0.0) { $0 + $1.quantity }
    }
    
    func getDistinctCatalogCodes() async throws -> [String] {
        let items = try await fetchItems(matching: nil)
        return Array(Set(items.map { $0.catalogCode })).sorted()
    }
    
    func consolidateItems(byCatalogCode: Bool) async throws -> [ConsolidatedInventoryModel] {
        guard byCatalogCode else { return [] }
        
        let items = try await fetchItems(matching: nil)
        let grouped = Dictionary(grouping: items) { $0.catalogCode }
        
        return grouped.map { (catalogCode, items) in
            ConsolidatedInventoryModel(catalogCode: catalogCode, items: items)
        }.sorted { $0.catalogCode < $1.catalogCode }
    }
}

// MARK: - InventoryItem Core Data Extension

extension InventoryItem {
    /// Convert Core Data InventoryItem to InventoryItemModel
    func toModel() -> InventoryItemModel {
        return InventoryItemModel(
            id: self.id ?? UUID().uuidString,
            catalogCode: self.catalog_code ?? "",
            quantity: Double(self.count),
            type: InventoryItemType(rawValue: self.type) ?? .inventory,
            notes: self.notes,
            dateAdded: Date() // Core Data doesn't store dateAdded in current model
        )
    }
}