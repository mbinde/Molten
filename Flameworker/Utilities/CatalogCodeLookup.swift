//
//
//  CatalogCodeLookup.swift
//  Flameworker
//
//  Shared utility for consistent catalog code lookup across the app
//

import Foundation

/// Utility for consistent catalog item lookup by code across different formats and search strategies
struct CatalogCodeLookup {
    
    /// Find a catalog item by code, handling multiple code formats and search strategies
    /// - Parameters:
    ///   - code: The catalog code to search for
    ///   - catalogService: The catalog service to use for searching
    /// - Returns: The matching CatalogItemModel or nil if not found
    static func findCatalogItem(byCode code: String, using catalogService: CatalogService) async throws -> CatalogItemModel? {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCode.isEmpty else { return nil }
        
        // Get all catalog items and search through them
        let allItems = try await catalogService.getAllItems()
        
        // Strategy 1: Direct exact match on code field
        if let item = searchByExactCode(cleanCode, in: allItems) {
            return item
        }
        
        // Strategy 2: Direct exact match on id field
        if let item = searchByExactId(cleanCode, in: allItems) {
            return item
        }
        
        // Strategy 3: Search by base code (remove manufacturer prefix)
        if let item = searchByBaseCode(cleanCode, in: allItems) {
            return item
        }
        
        // Strategy 4: Search for items ending with the provided code
        if let item = searchByCodeSuffix(cleanCode, in: allItems) {
            return item
        }
        
        // Strategy 5: Search for items containing the code anywhere
        if let item = searchByCodeContains(cleanCode, in: allItems) {
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
    
    private static func searchByExactCode(_ code: String, in items: [CatalogItemModel]) -> CatalogItemModel? {
        return items.first { $0.code == code }
    }
    
    private static func searchByExactId(_ code: String, in items: [CatalogItemModel]) -> CatalogItemModel? {
        return items.first { $0.id == code }
    }
    
    private static func searchByBaseCode(_ code: String, in items: [CatalogItemModel]) -> CatalogItemModel? {
        // If the code has a manufacturer prefix, try searching for items with that base code
        if code.contains("-"), let dashIndex = code.firstIndex(of: "-") {
            let baseCode = String(code[code.index(after: dashIndex)...])
            return searchByExactCode(baseCode, in: items)
        }
        
        // If no prefix, try to find items that have this as their base code
        return items.first { $0.code.hasSuffix("-\(code)") }
    }
    
    private static func searchByCodeSuffix(_ code: String, in items: [CatalogItemModel]) -> CatalogItemModel? {
        return items.first { $0.code.hasSuffix(code) }
    }
    
    private static func searchByCodeContains(_ code: String, in items: [CatalogItemModel]) -> CatalogItemModel? {
        let lowercaseCode = code.lowercased()
        return items.first { 
            $0.code.lowercased().contains(lowercaseCode) || $0.id.lowercased().contains(lowercaseCode)
        }
    }
}
