//
//  SortUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/3/25.
//

import Foundation

/// Protocol for objects that can be sorted by catalog criteria
protocol CatalogSortable {
    var name: String { get }
    var code: String { get }
    var manufacturer: String { get }
}

// MARK: - Model Conformance

/// Make CatalogItemModel conform to CatalogSortable
extension CatalogItemModel: CatalogSortable {
    // Already has name, code, manufacturer properties - no additional implementation needed
}

/// Sorting criteria for catalog items - maps to existing SortOption enum
enum CatalogSortCriteria: CaseIterable {
    case name
    case code
    case manufacturer
    
    /// Convert to existing SortOption for consistency
    var sortOption: SortOption {
        switch self {
        case .name: return .name
        case .code: return .code
        case .manufacturer: return .manufacturer
        }
    }
    
    /// Raw value for display purposes
    var rawValue: String {
        switch self {
        case .name: return "Name"
        case .code: return "Code"
        case .manufacturer: return "Manufacturer"
        }
    }
}

/// Sorting criteria for inventory items
enum InventorySortCriteria: String, CaseIterable {
    case catalogCode = "Catalog Code"
    case count = "Count"
    case type = "Type"
}

/// Centralized sorting utilities for business models - repository pattern compatible
struct SortUtilities {
    
    /// Sort catalog items based on the specified criteria
    /// - Parameters:
    ///   - items: Array of CatalogSortable objects to sort
    ///   - criteria: CatalogSortCriteria specifying how to sort
    /// - Returns: Sorted array of CatalogSortable objects
    static func sortCatalog<T: CatalogSortable>(_ items: [T], by criteria: CatalogSortCriteria) -> [T] {
        switch criteria {
        case .name:
            return sortByName(items)
        case .code:
            return sortByCode(items)
        case .manufacturer:
            return sortByManufacturer(items)
        }
    }
    
    /// Sort inventory items based on the specified criteria
    /// - Parameters:
    ///   - items: Array of InventoryItemModel objects to sort
    ///   - criteria: InventorySortCriteria specifying how to sort
    /// - Returns: Sorted array of InventoryItemModel objects
    static func sortInventory(_ items: [InventoryItemModel], by criteria: InventorySortCriteria) -> [InventoryItemModel] {
        switch criteria {
        case .catalogCode:
            return items.sorted { $0.catalogCode.localizedCaseInsensitiveCompare($1.catalogCode) == .orderedAscending }
        case .count:
            return items.sorted { $0.quantity > $1.quantity } // Descending order for count
        case .type:
            return items.sorted { item1, item2 in
                // Sort by type first, then by catalog code
                if item1.type == item2.type {
                    return item1.catalogCode.localizedCaseInsensitiveCompare(item2.catalogCode) == .orderedAscending
                }
                return item1.type.rawValue < item2.type.rawValue
            }
        }
    }
    
    // MARK: - Private Sorting Methods
    
    private static func sortByName<T: CatalogSortable>(_ items: [T]) -> [T] {
        return items.sorted { item1, item2 in
            let name1 = item1.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let name2 = item2.name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle empty cases - sort to end
            if name1.isEmpty && !name2.isEmpty {
                return false
            }
            if !name1.isEmpty && name2.isEmpty {
                return true
            }
            
            // Case insensitive comparison
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    private static func sortByCode<T: CatalogSortable>(_ items: [T]) -> [T] {
        return items.sorted { item1, item2 in
            let code1 = item1.code.trimmingCharacters(in: .whitespacesAndNewlines)
            let code2 = item2.code.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle empty cases - sort to end
            if code1.isEmpty && !code2.isEmpty {
                return false
            }
            if !code1.isEmpty && code2.isEmpty {
                return true
            }
            
            // Lexicographic comparison
            return code1.localizedCaseInsensitiveCompare(code2) == .orderedAscending
        }
    }
    
    private static func sortByManufacturer<T: CatalogSortable>(_ items: [T]) -> [T] {
        return items.sorted { item1, item2 in
            let manufacturer1 = item1.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let manufacturer2 = item2.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle empty cases - sort to end
            if manufacturer1.isEmpty && !manufacturer2.isEmpty {
                return false
            }
            if !manufacturer1.isEmpty && manufacturer2.isEmpty {
                return true
            }
            if manufacturer1.isEmpty && manufacturer2.isEmpty {
                return false // Both empty, maintain order
            }
            
            // Get COE values for comparison
            let coe1 = getCOEForManufacturer(manufacturer1) ?? Int.max
            let coe2 = getCOEForManufacturer(manufacturer2) ?? Int.max
            
            // If COEs are different, sort by COE
            if coe1 != coe2 {
                return coe1 < coe2
            }
            
            // If COEs are the same, sort alphabetically by manufacturer name
            return manufacturer1.localizedCaseInsensitiveCompare(manufacturer2) == .orderedAscending
        }
    }
    
    // MARK: - COE Mapping
    
    /// Get COE (coefficient of expansion) for manufacturer - simplified mapping
    private static func getCOEForManufacturer(_ manufacturer: String) -> Int? {
        // COE mapping based on common glass manufacturers
        // This provides a fallback when GlassManufacturers utility is not available
        switch manufacturer.lowercased() {
        case "bullseye":
            return 90
        case "effetre", "kugler":
            return 104
        case "spectrum": 
            return 96
        case "gaffer":
            return 96
        case "uroboros":
            return 90
        case "oceanside":
            return 96
        default:
            return nil // Unknown manufacturers sort to end
        }
    }
}
