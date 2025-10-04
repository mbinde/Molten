//
//  SortUtilities.swift
//  Flameworker
//
//  Created by Assistant on 10/3/25.
//

import Foundation
import CoreData

/// Protocol for objects that can be sorted by catalog criteria
protocol CatalogSortable {
    var name: String? { get }
    var code: String? { get }
    var manufacturer: String? { get }
}

// MARK: - Core Data Entity Protocol Conformance Helper

/// Helper class to make any Core Data entity sortable without property conflicts
struct CatalogSortableWrapper<T>: CatalogSortable where T: NSManagedObject {
    private let entity: T
    
    init(_ entity: T) {
        self.entity = entity
    }
    
    var name: String? {
        return entity.value(forKey: "name") as? String
    }
    
    var code: String? {
        return entity.value(forKey: "code") as? String
    }
    
    var manufacturer: String? {
        return entity.value(forKey: "manufacturer") as? String
    }
    
    var wrappedEntity: T {
        return entity
    }
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

/// Centralized sorting utilities for catalog items - bridges SortOption with in-memory sorting
struct SortUtilities {
    
    /// Sort catalog items based on the specified criteria
    /// - Parameters:
    ///   - items: Array of CatalogSortable objects to sort
    ///   - criteria: CatalogSortCriteria specifying how to sort
    /// - Returns: Sorted array of CatalogSortable objects
    static func sortCatalog<T: CatalogSortable>(_ items: [T], by criteria: CatalogSortCriteria) -> [T] {
        // Direct sorting without SortOption dependency for testing compatibility
        switch criteria {
        case .name:
            return sortByName(items)
        case .code:
            return sortByCode(items)
        case .manufacturer:
            return sortByManufacturer(items)
        }
    }
    
    /// Sort Core Data entities (convenience method for NSManagedObject subclasses)
    /// - Parameters:
    ///   - items: Array of NSManagedObject entities to sort
    ///   - criteria: CatalogSortCriteria specifying how to sort
    /// - Returns: Sorted array of NSManagedObject entities
    static func sortCatalogEntities<T: NSManagedObject>(_ items: [T], by criteria: CatalogSortCriteria) -> [T] {
        // Wrap entities, sort, then unwrap
        let wrapped = items.map { CatalogSortableWrapper($0) }
        let sorted = sortCatalog(wrapped, by: criteria)
        return sorted.map { $0.wrappedEntity }
    }
    
    /// Sort inventory items based on the specified criteria
    /// - Parameters:
    ///   - items: Array of InventoryItem objects to sort
    ///   - criteria: InventorySortCriteria specifying how to sort
    /// - Returns: Sorted array of InventoryItem objects
    static func sortInventory(_ items: [InventoryItem], by criteria: InventorySortCriteria) -> [InventoryItem] {
        switch criteria {
        case .catalogCode:
            return sortInventoryByCode(items)
        case .count:
            return items.sorted { $0.count > $1.count } // Descending order for count
        case .type:
            return sortInventoryByType(items)
        }
    }
    
    // MARK: - Core Sorting Implementation
    
    /// Sort using existing SortOption enum for consistency with Core Data approach
    private static func sortCatalogWithOption<T: CatalogSortable>(_ items: [T], by option: SortOption) -> [T] {
        switch option {
        case .name:
            return sortByName(items)
        case .code:
            return sortByCode(items)
        case .manufacturer:
            return sortByManufacturer(items)
        }
    }
    
    // MARK: - Private Sorting Methods
    
    private static func sortByName<T: CatalogSortable>(_ items: [T]) -> [T] {
        return items.sorted { item1, item2 in
            let name1 = item1.name ?? ""
            let name2 = item2.name ?? ""
            
            // Handle empty/nil cases - sort to end
            if name1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
               !name2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return false
            }
            if !name1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
               name2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            
            // Case insensitive comparison
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }
    
    private static func sortByCode<T: CatalogSortable>(_ items: [T]) -> [T] {
        return items.sorted { item1, item2 in
            let code1 = item1.code ?? ""
            let code2 = item2.code ?? ""
            
            // Handle nil cases - sort to end
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
            let manufacturer1 = item1.manufacturer
            let manufacturer2 = item2.manufacturer
            
            // Handle nil cases - sort to end
            if manufacturer1 == nil && manufacturer2 != nil {
                return false
            }
            if manufacturer1 != nil && manufacturer2 == nil {
                return true
            }
            if manufacturer1 == nil && manufacturer2 == nil {
                return false // Both nil, maintain order
            }
            
            guard let mfg1 = manufacturer1, let mfg2 = manufacturer2 else {
                return false
            }
            
            // Get COE values for comparison
            let coe1 = getCOEForManufacturer(mfg1) ?? Int.max
            let coe2 = getCOEForManufacturer(mfg2) ?? Int.max
            
            // If COEs are different, sort by COE
            if coe1 != coe2 {
                return coe1 < coe2
            }
            
            // If COEs are the same, sort alphabetically by manufacturer name
            return mfg1.localizedCaseInsensitiveCompare(mfg2) == .orderedAscending
        }
    }
    
    // MARK: - Private Inventory Sorting Methods
    
    private static func sortInventoryByCode(_ items: [InventoryItem]) -> [InventoryItem] {
        return items.sorted { item1, item2 in
            let code1 = item1.catalog_code ?? ""
            let code2 = item2.catalog_code ?? ""
            return code1.localizedCaseInsensitiveCompare(code2) == .orderedAscending
        }
    }
    
    private static func sortInventoryByType(_ items: [InventoryItem]) -> [InventoryItem] {
        return items.sorted { (lhs: InventoryItem, rhs: InventoryItem) in
            if lhs.type == rhs.type {
                return (lhs.catalog_code ?? "") < (rhs.catalog_code ?? "")
            }
            return lhs.type < rhs.type
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
