//
//  SearchUtilities.swift
//  Flameworker
//
//  Created by Assistant on 9/29/25.
//

import Foundation
import CoreData

/// Centralized search and filtering utilities to eliminate duplication

// MARK: - Search Protocol

/// Protocol for searchable entities
protocol Searchable {
    var searchableText: [String] { get }
}

/// Extension for InventoryItem to make it searchable
extension InventoryItem: Searchable {
    var searchableText: [String] {
        var searchableFields: [String] = []
        
        // Add catalog code and ID, filtering out empty strings
        [catalog_code, id].forEach { field in
            if let field = field, !field.isEmpty {
                searchableFields.append(field)
            }
        }
        
        // Add notes, filtering out empty strings
        if let notes = notes, !notes.isEmpty {
            searchableFields.append(notes)
        }
        
        // Add numeric values as strings for searchability
        searchableFields.append(String(count))
        searchableFields.append(String(units))
        searchableFields.append(String(type))
        
        return searchableFields
    }
}

/// Extension for CatalogItem to make it searchable
extension CatalogItem: Searchable {
    var searchableText: [String] {
        var searchableFields: [String] = []
        
        // Add basic fields that are guaranteed to exist
        [name, code, manufacturer].forEach { field in
            if let field = field, !field.isEmpty {
                searchableFields.append(field)
            }
        }
        
        // Safely add helper-extracted fields only if they exist and are not empty
        let tags = CatalogItemHelpers.tagsForItem(self)
        if !tags.isEmpty {
            searchableFields.append(tags)
        }
        
        let synonyms = CatalogItemHelpers.synonymsForItem(self)
        if !synonyms.isEmpty {
            searchableFields.append(synonyms)
        }
        
        let coe = CatalogItemHelpers.coeForItem(self)
        if !coe.isEmpty {
            searchableFields.append(coe)
        }
        
        return searchableFields
    }
}

// MARK: - Search Utilities

struct SearchUtilities {
    
    /// Generic search function that works with any Searchable entity
    static func filter<T: Searchable>(_ items: [T], with searchText: String) -> [T] {
        guard !searchText.isEmpty else { return items }
        
        let searchLower = searchText.lowercased()
        
        return items.filter { item in
            return item.searchableText.contains { field in
                field.lowercased().contains(searchLower)
            }
        }
    }
    
    /// Search inventory items with comprehensive field coverage
    static func searchInventoryItems(_ items: [InventoryItem], query: String) -> [InventoryItem] {
        return filter(items, with: query)
    }
    
    /// Search catalog items with comprehensive field coverage
    static func searchCatalogItems(_ items: [CatalogItem], query: String) -> [CatalogItem] {
        return filter(items, with: query)
    }
    
    /// Advanced search with multiple terms (AND logic)
    static func filterWithMultipleTerms<T: Searchable>(_ items: [T], searchTerms: [String]) -> [T] {
        guard !searchTerms.isEmpty else { return items }
        
        let lowerTerms = searchTerms.map { $0.lowercased() }
        
        return items.filter { item in
            let allText = item.searchableText.joined(separator: " ").lowercased()
            
            // All search terms must be found (AND logic)
            return lowerTerms.allSatisfy { term in
                allText.contains(term)
            }
        }
    }
    
    /// Fuzzy search with typo tolerance
    static func fuzzyFilter<T: Searchable>(_ items: [T], with searchText: String, tolerance: Int = 2) -> [T] {
        guard !searchText.isEmpty else { return items }
        
        let searchLower = searchText.lowercased()
        
        return items.filter { item in
            return item.searchableText.contains { field in
                let fieldLower = field.lowercased()
                
                // Exact match
                if fieldLower.contains(searchLower) {
                    return true
                }
                
                // Fuzzy match with edit distance
                return levenshteinDistance(searchLower, fieldLower) <= tolerance
            }
        }
    }
    
    /// Calculate Levenshtein distance for fuzzy matching
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let m = a.count
        let n = b.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
}

// MARK: - Filter Utilities

struct FilterUtilities {
    
    /// Filter inventory items by status
    static func filterInventoryByStatus(
        _ items: [InventoryItem],
        showInStock: Bool = true,
        showLowStock: Bool = true,
        showOutOfStock: Bool = true
    ) -> [InventoryItem] {
        return items.filter { item in
            if showInStock && item.count > 10 { return true }
            if showLowStock && item.isLowStock { return true }
            if showOutOfStock && item.count == 0 { return true }
            return false
        }
    }
    
    /// Filter inventory items by type
    static func filterInventoryByType(_ items: [InventoryItem], selectedTypes: Set<Int16>) -> [InventoryItem] {
        guard !selectedTypes.isEmpty else { return items }
        return items.filter { selectedTypes.contains($0.type) }
    }
    
    /// Filter catalog items by manufacturer
    static func filterCatalogByManufacturers(
        _ items: [CatalogItem],
        enabledManufacturers: Set<String>
    ) -> [CatalogItem] {
        return items.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
    }
    
    /// Filter catalog items by tags
    static func filterCatalogByTags(
        _ items: [CatalogItem],
        selectedTags: Set<String>
    ) -> [CatalogItem] {
        guard !selectedTags.isEmpty else { return items }
        
        return items.filter { item in
            let itemTags = Set(CatalogItemHelpers.tagsArrayForItem(item))
            return !selectedTags.isDisjoint(with: itemTags)
        }
    }
}

// MARK: - Sort Utilities

struct SortUtilities {
    
    /// Generic sorting for any collection
    static func sort<T>(_ items: [T], by keyPath: KeyPath<T, String?>, ascending: Bool = true) -> [T] {
        return items.sorted { lhs, rhs in
            let lhsValue = lhs[keyPath: keyPath] ?? ""
            let rhsValue = rhs[keyPath: keyPath] ?? ""
            return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
        }
    }
    
    /// Sort inventory items by various criteria
    static func sortInventory(_ items: [InventoryItem], by criteria: InventorySortCriteria) -> [InventoryItem] {
        switch criteria {
        case .catalogCode:
            return sort(items, by: \.catalog_code)
        case .count:
            return items.sorted { $0.count > $1.count } // Descending order for count
        case .type:
            return items.sorted { lhs, rhs in
                if lhs.type == rhs.type {
                    return (lhs.catalog_code ?? "") < (rhs.catalog_code ?? "")
                }
                return lhs.type < rhs.type
            }
        }
    }
    
    /// Sort catalog items by various criteria  
    static func sortCatalog(_ items: [CatalogItem], by criteria: CatalogSortCriteria) -> [CatalogItem] {
        switch criteria {
        case .name:
            return sort(items, by: \.name)
        case .manufacturer:
            return items.sorted { lhs, rhs in
                let lhsMfg = lhs.manufacturer ?? ""
                let rhsMfg = rhs.manufacturer ?? ""
                if lhsMfg == rhsMfg {
                    return (lhs.name ?? "") < (rhs.name ?? "")
                }
                return lhsMfg < rhsMfg
            }
        case .code:
            return sort(items, by: \.code)
        case .startDate:
            return items.sorted { lhs, rhs in
                (lhs.start_date ?? Date.distantPast) > (rhs.start_date ?? Date.distantPast)
            }
        }
    }
}

// MARK: - Sort Criteria Enums

enum InventorySortCriteria: String, CaseIterable {
    case catalogCode = "Catalog Code"
    case count = "Count"
    case type = "Type"
}

enum CatalogSortCriteria: String, CaseIterable {
    case name = "Name"
    case manufacturer = "Manufacturer" 
    case code = "Code"
    case startDate = "Start Date"
}