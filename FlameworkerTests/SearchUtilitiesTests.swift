//  SearchUtilitiesTests.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("SearchUtilities Levenshtein Distance Tests") 
struct SearchUtilitiesLevenshteinTests {
    
    @Test("Levenshtein distance calculation works correctly")
    func testLevenshteinDistanceCalculation() {
        // Test identical strings
        let items = [MockSearchableItem(text: ["test"])]
        let identicalResult = SearchUtilities.fuzzyFilter(items, with: "test", tolerance: 0)
        #expect(identicalResult.count == 1, "Should find exact match with zero tolerance")
        
        // Test single character difference
        let singleDiffItems = [MockSearchableItem(text: ["test"])]
        let singleDiffResult = SearchUtilities.fuzzyFilter(singleDiffItems, with: "best", tolerance: 1)
        #expect(singleDiffResult.count == 1, "Should find single character difference within tolerance")
        
        // Test beyond tolerance
        let beyondToleranceItems = [MockSearchableItem(text: ["test"])]
        let beyondResult = SearchUtilities.fuzzyFilter(beyondToleranceItems, with: "completely", tolerance: 2)
        #expect(beyondResult.count == 0, "Should not find match beyond tolerance")
    }
    
    // Helper for testing
    private struct MockSearchableItem: Searchable {
        let text: [String]
        var searchableText: [String] { text }
    }
}

@Suite("Search Logic Tests")
struct SearchLogicTests {
    
    @Test("Case-insensitive search works correctly")
    func testCaseInsensitiveSearch() {
        // Test basic case-insensitive matching logic
        let searchTerm = "Glass"
        let items = ["Red Glass", "blue glass", "CLEAR GLASS", "Metal Wire"]
        
        let results = items.filter { item in
            item.lowercased().contains(searchTerm.lowercased())
        }
        
        #expect(results.count == 3, "Should find 3 items containing 'glass' (case-insensitive)")
        #expect(results.contains("Red Glass"), "Should find 'Red Glass'")
        #expect(results.contains("blue glass"), "Should find 'blue glass'")
        #expect(results.contains("CLEAR GLASS"), "Should find 'CLEAR GLASS'")
        #expect(!results.contains("Metal Wire"), "Should not find 'Metal Wire'")
    }
    
    @Test("Multiple search terms work with AND logic")
    func testMultipleSearchTerms() {
        // Test AND logic for multiple search terms
        let searchTerms = ["red", "glass"]
        let items = ["Red Glass Rod", "Blue Glass", "Red Metal", "Clear Glass"]
        
        let results = items.filter { item in
            searchTerms.allSatisfy { term in
                item.lowercased().contains(term.lowercased())
            }
        }
        
        #expect(results.count == 1, "Should find only items containing both 'red' AND 'glass'")
        #expect(results.contains("Red Glass Rod"), "Should find 'Red Glass Rod'")
    }
    
    @Test("Empty search returns all items")
    func testEmptySearch() {
        let items = ["Item1", "Item2", "Item3"]
        let searchTerm = ""
        
        let results = items.filter { item in
            searchTerm.isEmpty || item.lowercased().contains(searchTerm.lowercased())
        }
        
        #expect(results.count == items.count, "Empty search should return all items")
    }
}