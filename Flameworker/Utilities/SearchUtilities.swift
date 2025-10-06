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

// MARK: - Enhanced Search Utilities

struct SearchUtilities {
    
    // MARK: - Search Configuration
    
    struct SearchConfig {
        let caseSensitive: Bool
        let exactMatch: Bool
        let fuzzyTolerance: Int?
        let highlightMatches: Bool
        
        static let `default` = SearchConfig(
            caseSensitive: false,
            exactMatch: false,
            fuzzyTolerance: nil,
            highlightMatches: false
        )
        
        static let fuzzy = SearchConfig(
            caseSensitive: false,
            exactMatch: false,
            fuzzyTolerance: 2,
            highlightMatches: false
        )
        
        static let exact = SearchConfig(
            caseSensitive: false,
            exactMatch: true,
            fuzzyTolerance: nil,
            highlightMatches: false
        )
    }
    
    // MARK: - Query Parsing
    /// Parse a user-entered query string into AND-terms, treating quoted phrases as single terms
    /// Examples:
    ///   - "red blue" => ["red", "blue"]
    ///   - "\"chocolate crayon\" red" => ["chocolate crayon", "red"]
    static func parseSearchTerms(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var terms: [String] = []
        var current = ""
        var inQuotes = false
        for char in trimmed {
            if char == "\"" { // toggle quotes
                if inQuotes {
                    // closing quote; finalize current if not empty
                    let term = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !term.isEmpty { terms.append(term.lowercased()) }
                    current.removeAll(keepingCapacity: true)
                }
                inQuotes.toggle()
            } else if char.isWhitespace && !inQuotes {
                // boundary between terms
                let term = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !term.isEmpty { terms.append(term.lowercased()) }
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(char)
            }
        }
        // Flush remaining
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { terms.append(tail.lowercased()) }
        return terms
    }
    
    // MARK: - Generic Search Functions
    
    /// Enhanced generic search function with configuration support
    static func filter<T: Searchable>(
        _ items: [T], 
        with searchText: String, 
        config: SearchConfig = .default
    ) -> [T] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return items }
        
        let searchText = config.caseSensitive ? trimmedSearchText : trimmedSearchText.lowercased()
        
        return items.filter { item in
            let searchableFields = item.searchableText.map { field in
                config.caseSensitive ? field : field.lowercased()
            }
            
            if config.exactMatch {
                return searchableFields.contains(searchText)
            }
            
            if let tolerance = config.fuzzyTolerance {
                return searchableFields.contains { field in
                    field.contains(searchText) || levenshteinDistance(searchText, field) <= tolerance
                }
            }
            
            return searchableFields.contains { field in
                field.contains(searchText)
            }
        }
    }
    
    /// Filter items by a query string using AND logic across terms (quoted phrases treated as single terms)
    static func filterWithQueryString<T: Searchable>(
        _ items: [T],
        queryString: String,
        config: SearchConfig = .default
    ) -> [T] {
        let terms = parseSearchTerms(queryString)
        guard !terms.isEmpty else { return items }
        return items.filter { item in
            let fields = item.searchableText.map { config.caseSensitive ? $0 : $0.lowercased() }
            // All terms must be found in at least one field
            return terms.allSatisfy { term in
                let t = config.caseSensitive ? term : term.lowercased()
                return fields.contains { $0.contains(t) }
            }
        }
    }
    
    /// Multi-field weighted search with relevance scoring
    static func weightedSearch<T: Searchable & Identifiable>(
        _ items: [T],
        with searchText: String,
        fieldWeights: [String: Double] = [:],
        config: SearchConfig = .default
    ) -> [(item: T, relevance: Double)] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else {
            return items.map { (item: $0, relevance: 0.0) }
        }
        
        let searchText = config.caseSensitive ? trimmedSearchText : trimmedSearchText.lowercased()
        
        let results = items.compactMap { item -> (item: T, relevance: Double)? in
            let searchableFields = item.searchableText.map { field in
                config.caseSensitive ? field : field.lowercased()
            }
            
            var totalRelevance: Double = 0.0
            
            for field in searchableFields {
                let weight = fieldWeights[field] ?? 1.0
                
                if config.exactMatch {
                    if field == searchText {
                        totalRelevance += weight * 10.0 // Exact match bonus
                    }
                } else if field.contains(searchText) {
                    let position = field.distance(from: field.startIndex, to: field.range(of: searchText)?.lowerBound ?? field.endIndex)
                    let positionScore = max(0, 5.0 - Double(position) * 0.1) // Earlier matches score higher
                    totalRelevance += weight * positionScore
                } else if let tolerance = config.fuzzyTolerance {
                    let distance = levenshteinDistance(searchText, field)
                    if distance <= tolerance {
                        let fuzzyScore = max(0, 2.0 - Double(distance) * 0.5)
                        totalRelevance += weight * fuzzyScore
                    }
                }
            }
            
            return totalRelevance > 0 ? (item: item, relevance: totalRelevance) : nil
        }
        
        return results.sorted { $0.relevance > $1.relevance }
    }
    
    /// Search inventory items with comprehensive field coverage
    static func searchInventoryItems(_ items: [InventoryItem], query: String) -> [InventoryItem] {
        return filterWithQueryString(items, queryString: query)
    }
    
    /// Search catalog items with comprehensive field coverage
    static func searchCatalogItems(_ items: [CatalogItem], query: String) -> [CatalogItem] {
        return filterWithQueryString(items, queryString: query)
    }
    
    /// Advanced search with multiple terms (AND logic)
    static func filterWithMultipleTerms<T: Searchable>(_ items: [T], searchTerms: [String]) -> [T] {
        guard !searchTerms.isEmpty else { return items }
        
        let lowerTerms = searchTerms.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
        guard !lowerTerms.isEmpty else { return items }
        
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
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return items }
        
        let searchLower = trimmedSearchText.lowercased()
        
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
    
    /// Filter catalog items by COE glass type
    static func filterCatalogByCOE<T: CatalogItemProtocol>(
        _ items: [T],
        selectedCOE: COEGlassType?
    ) -> [T] {
        guard let selectedCOE = selectedCOE else { return items }
        
        return items.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return GlassManufacturers.supports(code: manufacturer, coe: selectedCOE.rawValue)
        }
    }
    
    /// Filter catalog items by multiple COE glass types
    static func filterCatalogByMultipleCOE<T: CatalogItemProtocol>(
        _ items: [T],
        selectedCOETypes: Set<COEGlassType>
    ) -> [T] {
        guard !selectedCOETypes.isEmpty else { return items }
        
        // If all COE types are selected, return all items (optimization)
        if selectedCOETypes.count == COEGlassType.allCases.count {
            return items
        }
        
        return items.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            
            // Check if manufacturer supports any of the selected COE types
            return selectedCOETypes.contains { coeType in
                GlassManufacturers.supports(code: manufacturer, coe: coeType.rawValue)
            }
        }
    }
}

// MARK: - Protocol for Testable Catalog Items

protocol CatalogItemProtocol {
    var manufacturer: String? { get }
    var name: String? { get }  // Changed to optional to match CatalogItem
}

// MARK: - CatalogItem Protocol Conformance

extension CatalogItem: CatalogItemProtocol {
    // CatalogItem already has manufacturer: String? and name: String? properties
    // No additional implementation needed
}

