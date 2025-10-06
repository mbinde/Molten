//
//  CatalogCodeLookup.swift
//  Flameworker
//
//  Shared utility for consistent catalog code lookup across the app
//

import Foundation
import CoreData

/// Utility for consistent catalog item lookup by code across different formats
struct CatalogCodeLookup {
    
    /// Find a catalog item by code, handling multiple code formats and search strategies
    /// - Parameters:
    ///   - code: The catalog code to search for
    ///   - context: Core Data managed object context
    /// - Returns: The matching CatalogItem or nil if not found
    static func findCatalogItem(byCode code: String, in context: NSManagedObjectContext) -> CatalogItem? {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCode.isEmpty else { return nil }
        
        // Strategy 1: Direct exact match on code field
        if let item = searchByExactCode(cleanCode, in: context) {
            return item
        }
        
        // Strategy 2: Direct exact match on id field
        if let item = searchByExactId(cleanCode, in: context) {
            return item
        }
        
        // Strategy 3: Search by base code (remove manufacturer prefix)
        if let item = searchByBaseCode(cleanCode, in: context) {
            return item
        }
        
        // Strategy 4: Search for items ending with the provided code
        if let item = searchByCodeSuffix(cleanCode, in: context) {
            return item
        }
        
        // Strategy 5: Search for items containing the code anywhere
        if let item = searchByCodeContains(cleanCode, in: context) {
            return item
        }
        
        return nil
    }
    
    /// Generate the preferred catalog code format for creating inventory items
    /// This ensures consistency between how codes are displayed and how they're stored
    /// - Parameters:
    ///   - catalogCode: The base catalog code
    ///   - manufacturer: The manufacturer name (optional)
    /// - Returns: The preferred catalog code format for inventory creation
    static func preferredCatalogCode(from catalogCode: String, manufacturer: String?) -> String {
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            return "\(manufacturer)-\(catalogCode)"
        }
        return catalogCode
    }
    
    // MARK: - Search Strategies
    
    private static func searchByExactCode(_ code: String, in context: NSManagedObjectContext) -> CatalogItem? {
        let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        request.predicate = NSPredicate(format: "code == %@", code)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    private static func searchByExactId(_ code: String, in context: NSManagedObjectContext) -> CatalogItem? {
        let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", code)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    private static func searchByBaseCode(_ code: String, in context: NSManagedObjectContext) -> CatalogItem? {
        // If the code has a manufacturer prefix, try searching for items with that base code
        if code.contains("-"), let dashIndex = code.firstIndex(of: "-") {
            let baseCode = String(code[code.index(after: dashIndex)...])
            return searchByExactCode(baseCode, in: context)
        }
        
        // If no prefix, try to find items that have this as their base code
        let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        request.predicate = NSPredicate(format: "code ENDSWITH %@", "-\(code)")
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    private static func searchByCodeSuffix(_ code: String, in context: NSManagedObjectContext) -> CatalogItem? {
        let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        request.predicate = NSPredicate(format: "code ENDSWITH %@", code)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    private static func searchByCodeContains(_ code: String, in context: NSManagedObjectContext) -> CatalogItem? {
        let request: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        request.predicate = NSPredicate(format: "code CONTAINS[c] %@ OR id CONTAINS[c] %@", code, code)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
}