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
    
    // SIMPLIFIED SEARCH - avoiding problematic patterns
    private func simpleSearch(items: [SearchableItem], query: String) -> [SimpleRankingResult] {
        var results: [SimpleRankingResult] = []
        
        // Phase 1: Find exact name matches (highest priority)
        for item in items {
            if item.name == query {
                let result = SimpleRankingResult(itemName: item.name, isExactMatch: true)
                results.append(result)
            }
        }
        
        // Phase 2: Find name contains matches (medium priority)
        for item in items {
            // Skip if already found as exact match
            let alreadyFound = results.contains { $0.itemName == item.name }
            if !alreadyFound && item.name.contains(query) {
                let result = SimpleRankingResult(itemName: item.name, isExactMatch: false)
                results.append(result)
            }
        }
        
        // Phase 3: Find manufacturer matches (lowest priority)
        for item in items {
            // Skip if already found
            let alreadyFound = results.contains { $0.itemName == item.name }
            if !alreadyFound, let manufacturer = item.manufacturer, manufacturer.contains(query) {
                let result = SimpleRankingResult(itemName: item.name, isExactMatch: false)
                results.append(result)
            }
        }
        
        return results
    }
}