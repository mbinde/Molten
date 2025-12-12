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

        // Strategy 6: Search by exact full_name match (for long product names on receipts)
        if let item = searchByExactFullName(cleanCode, in: allItems) {
            return item
        }

        // Strategy 7: Search for items containing the code in full_name
        if let item = searchByFullNameContains(cleanCode, in: allItems) {
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
    
    /// Generate the preferred stable_id format for creating inventory items
    /// This ensures consistency between how codes are displayed and how they're stored
    /// - Parameters:
    ///   - sku: The SKU code
    ///   - manufacturer: The manufacturer name
    /// - Returns: The preferred stable_id (6-char hash)
    static func preferredNaturalKey(sku: String, manufacturer: String) -> String {
        // stable_id is a 6-char hash, not a constructed key
        return String(format: "%06d", abs("\(manufacturer)-\(sku)".hashValue % 1000000))
    }
    
    // DEAD CODE (2025-11-02): Legacy method never called. Safe to remove.
    /*
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
    */
    
    // MARK: - Search Strategies
    
    private static func searchByExactNaturalKey(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return items.first { $0.stable_id == code }
    }
    
    private static func searchByExactSKU(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return items.first { $0.sku == code }
    }
    
    private static func searchByManufacturerSKU(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        // If the code has a manufacturer prefix, try to parse it
        if code.contains("-") {
            // Split on dash and try manufacturer-sku matching
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
        return items.first { $0.stable_id.contains(code) }
    }
    
    private static func searchByNameContains(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        let lowercaseCode = code.lowercased()
        return items.first { $0.name.lowercased().contains(lowercaseCode) }
    }

    private static func searchByExactFullName(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        let lowercaseCode = code.lowercased()
        return items.first { $0.full_name?.lowercased() == lowercaseCode }
    }

    private static func searchByFullNameContains(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        let lowercaseCode = code.lowercased()
        return items.first { $0.full_name?.lowercased().contains(lowercaseCode) == true }
    }
    
    // DEAD CODE (2025-11-02): Legacy search methods never called, just wrappers. Safe to remove.
    /*
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
        return items.first { $0.stable_id.hasSuffix(code) || ($0.sku?.hasSuffix(code) ?? false) }
    }

    private static func searchByCodeContains(_ code: String, in items: [GlassItemModel]) -> GlassItemModel? {
        return searchByNaturalKeyContains(code, in: items)
    }
    */
}
