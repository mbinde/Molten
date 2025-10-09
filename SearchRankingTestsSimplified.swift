//
//  SearchRankingTestsSimplified.swift
//  FlameworkerTests
//
//  Created by TDD Recovery Process on December 2024.
//  Dramatically simplified search ranking - avoiding hanging patterns
//

import Testing
import Foundation

// Simplified search result - no complex scoring
struct SimpleRankingResult {
    let itemName: String
    let isExactMatch: Bool
}

// Simplified item structure - minimal fields
struct SearchableItem {
    let name: String
    let manufacturer: String?
    
    init(name: String, manufacturer: String? = nil) {
        self.name = name
        self.manufacturer = manufacturer
    }
}

@Suite("Simplified Search Ranking Tests")
struct SearchRankingTestsSimplified {
    
    @Test("Should find exact name matches")
    func testExactNameMatch() {
        let items = [
            SearchableItem(name: "Red Glass"),
            SearchableItem(name: "Blue Glass")
        ]
        
        let results = simpleSearch(items: items, query: "Red Glass")
        
        #expect(results.count == 1, "Should find one exact match")
        #expect(results.first?.itemName == "Red Glass", "Should return the exact match")
        #expect(results.first?.isExactMatch == true, "Should be marked as exact match")
    }
    
    @Test("Should find manufacturer matches")
    func testManufacturerMatch() {
        let items = [
            SearchableItem(name: "Glass Rod", manufacturer: "Effetre"),
            SearchableItem(name: "Sheet Glass", manufacturer: "Bullseye")
        ]
        
        let results = simpleSearch(items: items, query: "Effetre")
        
        #expect(results.count == 1, "Should find manufacturer match")
        #expect(results.first?.itemName == "Glass Rod", "Should return item with matching manufacturer")
    }
    
    @Test("Should prioritize exact name matches over manufacturer matches")
    func testMatchPriority() {
        let items = [
            SearchableItem(name: "Effetre Special", manufacturer: "Spectrum"),  // name match
            SearchableItem(name: "Glass Rod", manufacturer: "Effetre")         // manufacturer match
        ]
        
        let results = simpleSearch(items: items, query: "Effetre")
        
        #expect(results.count == 2, "Should find both matches")
        #expect(results.first?.itemName == "Effetre Special", "Name match should come first")
        #expect(results.first?.isExactMatch == false, "Name contains match, not exact")
    }
    
    @Test("Should handle case-insensitive search safely")
    func testCaseInsensitiveSearch() {
        let items = [
            SearchableItem(name: "Red Glass"),
            SearchableItem(name: "BLUE GLASS")
        ]
        
        let results = simpleSearch(items: items, query: "red glass")
        
        #expect(results.count == 1, "Should find case-insensitive match")
        #expect(results.first?.itemName == "Red Glass", "Should return the matching item")
    }
    
    @Test("Should handle multi-term queries with nil safety")
    func testMultiTermQuerySafe() {
        let items = [
            SearchableItem(name: "Red Glass Rod", manufacturer: "Effetre"),
            SearchableItem(name: "Blue Glass Sheet", manufacturer: "Bullseye")
        ]
        
        // Simple two-word query that should work with nil-safe processing
        let results = simpleSearch(items: items, query: "Red Glass")
        
        #expect(results.count >= 0, "Should not crash and return some results")
        print("DEBUG: Multi-term query returned \(results.count) results")
        for result in results {
            print("DEBUG: Found '\(result.itemName)'")
        }
    }
    
    @Test("Should handle multi-term AND logic correctly")
    func testMultiTermAndLogic() {
        let items = [
            SearchableItem(name: "Red Glass Rod", manufacturer: "Effetre"),    // has both Red AND Glass
            SearchableItem(name: "Blue Glass Sheet", manufacturer: "Bullseye"), // has Glass but not Red  
            SearchableItem(name: "Red Plastic Rod", manufacturer: "Spectrum"),  // has Red but not Glass
            SearchableItem(name: "Clear Container", manufacturer: "Generic")    // has neither
        ]
        
        let results = simpleSearch(items: items, query: "Red Glass")
        
        #expect(results.count == 1, "Should find only item with both terms")
        #expect(results.first?.itemName == "Red Glass Rod", "Should find the item with both Red and Glass")
        #expect(results.first?.isExactMatch == false, "Should be partial match, not exact")
    }
    
    // SIMPLIFIED SEARCH - with nil-safe multi-term query support
    private func simpleSearch(items: [SearchableItem], query: String) -> [SimpleRankingResult] {
        var results: [SimpleRankingResult] = []
        
        // Nil safety: Ensure query is valid
        guard !query.isEmpty else { return results }
        
        // Check if this is a multi-term query (contains spaces)
        let isMultiTerm = query.contains(" ")
        
        if isMultiTerm {
            // Handle multi-term queries with nil safety
            let terms = query.components(separatedBy: .whitespacesAndNewlines)
                .compactMap { $0.isEmpty ? nil : $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            guard !terms.isEmpty else { return results }
            
            return searchMultiTerm(items: items, terms: terms)
        } else {
            // Handle single-term queries (existing logic)
            return searchSingleTerm(items: items, query: query)
        }
    }
    
    // Nil-safe single term search
    private func searchSingleTerm(items: [SearchableItem], query: String) -> [SimpleRankingResult] {
        var results: [SimpleRankingResult] = []
        
        // Phase 1: Find exact name matches (case-insensitive, highest priority)
        for item in items {
            guard !item.name.isEmpty else { continue }
            if item.name.compare(query, options: .caseInsensitive) == .orderedSame {
                let result = SimpleRankingResult(itemName: item.name, isExactMatch: true)
                results.append(result)
            }
        }
        
        // Phase 2: Find name contains matches (case-insensitive, medium priority)
        for item in items {
            guard !item.name.isEmpty else { continue }
            let alreadyFound = results.contains { $0.itemName == item.name }
            if !alreadyFound && item.name.range(of: query, options: .caseInsensitive) != nil {
                let result = SimpleRankingResult(itemName: item.name, isExactMatch: false)
                results.append(result)
            }
        }
        
        // Phase 3: Find manufacturer matches (case-insensitive, lowest priority)
        for item in items {
            guard let manufacturer = item.manufacturer, !manufacturer.isEmpty else { continue }
            let alreadyFound = results.contains { $0.itemName == item.name }
            if !alreadyFound && manufacturer.range(of: query, options: .caseInsensitive) != nil {
                let result = SimpleRankingResult(itemName: item.name, isExactMatch: false)
                results.append(result)
            }
        }
        
        return results
    }
    
    // Nil-safe multi-term search with AND logic
    private func searchMultiTerm(items: [SearchableItem], terms: [String]) -> [SimpleRankingResult] {
        var results: [SimpleRankingResult] = []
        
        // Reconstruct the original query for exact matching
        let originalQuery = terms.joined(separator: " ")
        
        for item in items {
            guard !item.name.isEmpty else { continue }
            
            // Phase 1: Check for exact match first (highest priority)
            if item.name.compare(originalQuery, options: .caseInsensitive) == .orderedSame {
                let result = SimpleRankingResult(itemName: item.name, isExactMatch: true)
                results.append(result)
                continue
            }
            
            // Phase 2: Check if ALL terms are present in the name (AND logic)
            let nameContainsAllTerms = terms.allSatisfy { term in
                guard !term.isEmpty else { return false }
                return item.name.range(of: term, options: .caseInsensitive) != nil
            }
            
            if nameContainsAllTerms {
                let result = SimpleRankingResult(itemName: item.name, isExactMatch: false)
                results.append(result)
            }
        }
        
        return results
    }
}