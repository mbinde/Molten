//
//  InventoryService.swift
//  Flameworker
//
//  Created by Melissa Binde on 9/28/25.
//

import Foundation
import CoreData

class InventoryService {
    static let shared = InventoryService()
    
    private init() {}
    
    // MARK: - Create Operations
    
    /// Creates a new InventoryItem with the provided data
    func createInventoryItem(
        id: String? = nil,
        catalogCode: String? = nil,
        count: Double = 0.0,
        units: Int16 = 0,
        type: Int16 = 0,
        notes: String? = nil,
        in context: NSManagedObjectContext
    ) throws -> InventoryItem {
        
        let newItem = InventoryItem(context: context)
        
        // Set the ID - generate UUID if not provided
        newItem.id = id ?? UUID().uuidString
        
        // Set all the properties
        newItem.catalog_code = catalogCode
        newItem.count = count
        newItem.units = units
        newItem.type = type
        newItem.notes = notes
        
        // Save the context using centralized helper
        try CoreDataHelpers.safeSave(context: context, description: "new InventoryItem with ID: \(newItem.id ?? "unknown")")
        
        return newItem
    }
    
    // MARK: - Read Operations
    
    /// Fetches all inventory items
    func fetchAllInventoryItems(from context: NSManagedObjectContext) throws -> [InventoryItem] {
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.id, ascending: true)]
        
        return try context.fetch(fetchRequest)
    }
    
    /// Fetches inventory items matching a search query
    func searchInventoryItems(query: String, in context: NSManagedObjectContext) throws -> [InventoryItem] {
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        
        // Search in catalog_code and notes
        let predicate = NSPredicate(format: "catalog_code CONTAINS[cd] %@ OR notes CONTAINS[cd] %@", 
                                  query, query)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.id, ascending: true)]
        
        return try context.fetch(fetchRequest)
    }
    
    /// Fetches inventory items with low stock (count <= 10)
    func fetchLowStockInventoryItems(from context: NSManagedObjectContext) throws -> [InventoryItem] {
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        let predicate = NSPredicate(format: "count > 0 AND count <= 10")
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.count, ascending: true)]
        
        return try context.fetch(fetchRequest)
    }
    
    // MARK: - Update Operations
    
    /// Updates an existing InventoryItem
    func updateInventoryItem(
        _ item: InventoryItem,
        catalogCode: String? = nil,
        count: Double? = nil,
        units: Int16? = nil,
        type: Int16? = nil,
        notes: String? = nil,
        in context: NSManagedObjectContext
    ) throws {
        
        // Update only the properties that are provided (not nil)
        if let catalogCode = catalogCode { item.catalog_code = catalogCode }
        if let count = count { item.count = count }
        if let units = units { item.units = units }
        if let type = type { item.type = type }
        if let notes = notes { item.notes = notes }
        
        try CoreDataHelpers.safeSave(context: context, description: "updated InventoryItem with ID: \(item.id ?? "unknown")")
    }
    
    // MARK: - Delete Operations
    
    /// Deletes an InventoryItem
    func deleteInventoryItem(_ item: InventoryItem, from context: NSManagedObjectContext) throws {
        context.delete(item)
        try CoreDataHelpers.safeSave(context: context, description: "deleted InventoryItem with ID: \(item.id ?? "unknown")")
        print("🗑️ Deleted InventoryItem with ID: \(item.id ?? "unknown")")
    }
    
    // MARK: - Utility Methods
    
    /// Checks if an item has low stock (count > 0 but <= 10)
    func isLowStock(_ item: InventoryItem) -> Bool {
        return item.count > 0 && item.count <= 10.0
    }
    
    /// Increments the count of an item
    func incrementCount(_ item: InventoryItem, by amount: Double = 1.0, in context: NSManagedObjectContext) throws {
        item.count += amount
        try CoreDataHelpers.safeSave(context: context, description: "incremented count for InventoryItem with ID: \(item.id ?? "unknown") by \(amount)")
        print("📈 Incremented count for InventoryItem with ID: \(item.id ?? "unknown") by \(amount)")
    }
    
    /// Decrements the count of an item (won't go below 0)
    func decrementCount(_ item: InventoryItem, by amount: Double = 1.0, in context: NSManagedObjectContext) throws {
        item.count = max(0, item.count - amount)
        try CoreDataHelpers.safeSave(context: context, description: "decremented count for InventoryItem with ID: \(item.id ?? "unknown") by \(amount)")
        print("📉 Decremented count for InventoryItem with ID: \(item.id ?? "unknown") by \(amount)")
    }
}
