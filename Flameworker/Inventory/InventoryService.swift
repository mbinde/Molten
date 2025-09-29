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
        customTags: String? = nil,
        isFavorite: Bool = false,
        inventoryAmount: String? = nil,
        inventoryUnits: String? = nil,
        inventoryNotes: String? = nil,
        shoppingAmount: String? = nil,
        shoppingUnits: String? = nil,
        shoppingNotes: String? = nil,
        forsaleAmount: String? = nil,
        forsaleUnits: String? = nil,
        forsaleNotes: String? = nil,
        in context: NSManagedObjectContext
    ) throws -> InventoryItem {
        
        let newItem = InventoryItem(context: context)
        
        // Set the ID - generate UUID if not provided
        newItem.id = id ?? UUID().uuidString
        
        // Set all the properties
        newItem.custom_tags = customTags
        newItem.favorite = isFavorite ? Data([1]) : Data([0]) // Convert Bool to Binary
        
        newItem.inventory_amount = inventoryAmount
        newItem.inventory_units = inventoryUnits
        newItem.inventory_notes = inventoryNotes
        
        newItem.shopping_amount = shoppingAmount
        newItem.shopping_units = shoppingUnits
        newItem.shopping_notes = shoppingNotes
        
        newItem.forsale_amount = forsaleAmount
        newItem.forsale_units = forsaleUnits
        newItem.forsale_notes = forsaleNotes
        
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
        
        // Search in custom_tags, inventory_notes, shopping_notes, and forsale_notes
        let predicate = NSPredicate(format: "custom_tags CONTAINS[cd] %@ OR inventory_notes CONTAINS[cd] %@ OR shopping_notes CONTAINS[cd] %@ OR forsale_notes CONTAINS[cd] %@", 
                                  query, query, query, query)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.id, ascending: true)]
        
        return try context.fetch(fetchRequest)
    }
    
    /// Fetches favorite inventory items
    func fetchFavoriteInventoryItems(from context: NSManagedObjectContext) throws -> [InventoryItem] {
        let fetchRequest: NSFetchRequest<InventoryItem> = InventoryItem.fetchRequest()
        let predicate = NSPredicate(format: "favorite != nil")
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InventoryItem.id, ascending: true)]
        
        return try context.fetch(fetchRequest)
    }
    
    // MARK: - Update Operations
    
    /// Updates an existing InventoryItem
    func updateInventoryItem(
        _ item: InventoryItem,
        customTags: String? = nil,
        isFavorite: Bool? = nil,
        inventoryAmount: String? = nil,
        inventoryUnits: String? = nil,
        inventoryNotes: String? = nil,
        shoppingAmount: String? = nil,
        shoppingUnits: String? = nil,
        shoppingNotes: String? = nil,
        forsaleAmount: String? = nil,
        forsaleUnits: String? = nil,
        forsaleNotes: String? = nil,
        in context: NSManagedObjectContext
    ) throws {
        
        // Update only the properties that are provided (not nil)
        if let customTags = customTags { item.custom_tags = customTags }
        if let isFavorite = isFavorite { item.favorite = isFavorite ? Data([1]) : Data([0]) }
        
        if let inventoryAmount = inventoryAmount { item.inventory_amount = inventoryAmount }
        if let inventoryUnits = inventoryUnits { item.inventory_units = inventoryUnits }
        if let inventoryNotes = inventoryNotes { item.inventory_notes = inventoryNotes }
        
        if let shoppingAmount = shoppingAmount { item.shopping_amount = shoppingAmount }
        if let shoppingUnits = shoppingUnits { item.shopping_units = shoppingUnits }
        if let shoppingNotes = shoppingNotes { item.shopping_notes = shoppingNotes }
        
        if let forsaleAmount = forsaleAmount { item.forsale_amount = forsaleAmount }
        if let forsaleUnits = forsaleUnits { item.forsale_units = forsaleUnits }
        if let forsaleNotes = forsaleNotes { item.forsale_notes = forsaleNotes }
        
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
    
    /// Converts the Binary favorite field to a Bool
    func isFavorite(_ item: InventoryItem) -> Bool {
        guard let favoriteData = item.favorite,
              let firstByte = favoriteData.first else {
            return false
        }
        return firstByte == 1
    }
    
    /// Toggles the favorite status of an item
    func toggleFavorite(_ item: InventoryItem, in context: NSManagedObjectContext) throws {
        let currentFavorite = isFavorite(item)
        item.favorite = currentFavorite ? Data([0]) : Data([1])
        try CoreDataHelpers.safeSave(context: context, description: "toggled favorite for InventoryItem with ID: \(item.id ?? "unknown") to \(!currentFavorite)")
        print("⭐ Toggled favorite for InventoryItem with ID: \(item.id ?? "unknown") to \(!currentFavorite)")
    }
}