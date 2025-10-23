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
    
    /// Find a glass item by code, handling multiple code formats and search strategies
    /// - Parameters:
    ///   - code: The catalog code to search for
    ///   - catalogService: The catalog service to use for searching
    /// - Returns: The matching GlassItemModel or nil if not found
    static func findGlassItem(byCode code: String, using catalogService: CatalogService) async throws -> GlassItemModel? {
        let cleanCode = code.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !cleanCode.isEmpty else { return nil }
        
        // Get all glass items and search through them
        let allCompleteItems = try await catalogService.getAllGlassItems()
        let allItems = allCompleteItems.map { $0.glassItem }
        
        // Strategy 1: Direct exact match on natural key
        if let item = searchByExactNaturalKey(cleanCode, in: allItems) {
            return item
        }
        
        // Strategy 2: Search by SKU
        if let item = searchByExactSKU(cleanCode, in: allItems) {
            return item
        }
        
        // Strategy 3: Search by manufacturer-sku pattern
        if let item = searchByManufacturerSKU(cleanCode, in: allItems) {
            return item
        }
        
        // Strategy 4: Search for items containing the code in natural key
        if let item = searchByNaturalKeyContains(cleanCode, in: allItems) {
            return item
        }
        
        // Strategy 5: Search for items containing the code in name
        if let item = searchByNameContains(cleanCode, in: allItems) {
            return item
        }
        
        return nil
    }
    
    /// Legacy method name for backward compatibility
    /// - Parameters:
    ///   - code: The catalog code to search for
    ///   - catalogService: The catalog service to use for searching
    /// - Returns: The matching GlassItemModel or nil if not found
    static func findCatalogItem(byCode code: String, using catalogService: CatalogService) async throws -> GlassItemModel? {
        return try await findGlassItem(byCode: code, using: catalogService)
    }
    
    /// Generate the preferred natural key format for creating inventory items
    /// This ensures consistency between how codes are displayed and how they're stored
    /// - Parameters:
    ///   - sku: The SKU code
    ///   - manufacturer: The manufacturer name
    /// - Returns: The preferred natural key format for inventory creation
    static func preferredNaturalKey(sku: String, manufacturer: String) -> String {
        return GlassItemModel.createNaturalKey(manufacturer: manufacturer, sku: sku, sequence: 0)
    }
    
    /// Legacy method for backward compatibility
    /// - Parameters:
    ///   - catalogCode: The base catalog code (treated as SKU)
    ///   - manufacturer: The manufacturer name (optional)
    /// - Returns: The preferred catalog code format for inventory creation
    static func preferredCatalogCode(from catalogCode: String, manufacturer: String?) -> String {
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            return preferredNaturalKey(sku: catalogCode, manufacturer: manufacturer)
        }
        return catalogCode
    }
    
    // MARK: - Search Strategies
    
    private static func searchByExactNaturalKey(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return items.first { $0.natural_key == code }
    }
    
    private static func searchByExactSKU(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return items.first { $0.sku == code }
    }
    
    private static func searchByManufacturerSKU(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        // If the code has a manufacturer prefix, try to parse it
        if code.contains("-") {
            if let parsed = GlassItemModel.parseNaturalKey(code) {
                return items.first { $0.manufacturer.lowercased() == parsed.manufacturer.lowercased() && $0.sku == parsed.sku }
            }
            
            // Fallback: split on dash and try manufacturer-sku matching
            let components = code.components(separatedBy: "-")
            if components.count >= 2 {
                let manufacturer = components[0].lowercased()
                let sku = components[1]
                return items.first { $0.manufacturer.lowercased() == manufacturer && $0.sku == sku }
            }
        }
        
        return nil
    }
    
    private static func searchByNaturalKeyContains(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        let lowercaseCode = code.lowercased()
        return items.first { $0.natural_key?.lowercased().contains(lowercaseCode) == true }
    }
    
    private static func searchByNameContains(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        let lowercaseCode = code.lowercased()
        return items.first { $0.name.lowercased().contains(lowercaseCode) }
    }
    
    // MARK: - Legacy Search Methods (for backward compatibility)
    
    private static func searchByExactCode(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return searchByExactNaturalKey(code, in: items)
    }
    
    private static func searchByExactId(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return searchByExactNaturalKey(code, in: items)
    }
    
    private static func searchByBaseCode(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return searchByManufacturerSKU(code, in: items)
    }
    
    private static func searchByCodeSuffix(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return items.first { $0.natural_key?.hasSuffix(code) == true || $0.sku.hasSuffix(code) }
    }
    
    private static func searchByCodeContains(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return searchByNaturalKeyContains(code, in: items)
    }
}
