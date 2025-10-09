//
//  SearchRankingTestsMinimal.swift
//  FlameworkerTests
//
//  Created by TDD Recovery Process on December 2024.
//  Minimal test to isolate build hanging issue
//

import Testing
import Foundation

// Minimal search result struct
struct MinimalSearchResult {
    let name: String
    let score: Double
}

// Simple item to search
struct SimpleItem {
    let id: String
    let name: String
}

@Suite("Minimal Search Tests")
struct MinimalSearchTests {
    
    @Test("Basic functionality test")
    func testBasicFunctionality() {
        let result = MinimalSearchResult(name: "Test", score: 1.0)
        #expect(result.name == "Test")
        #expect(result.score == 1.0)
    }
    
    @Test("Should find exact name match")
    func testExactNameMatch() {
        let items = [
            SimpleItem(id: "1", name: "Red Glass")
        ]
        
        let results = simpleSearch(items: items, query: "Red Glass")
        
        #expect(results.count == 1, "Should find one exact match")
        #expect(results.first?.name == "Red Glass", "Should return the matching item")
    }
    
    // Simple search implementation - case-insensitive partial matching
    private func simpleSearch(items: [SimpleItem], query: String) -> [MinimalSearchResult] {
        var results: [MinimalSearchResult] = []
        let lowercaseQuery = query.lowercased()
        
        for item in items {
            if item.name.lowercased().contains(lowercaseQuery) {
                let result = MinimalSearchResult(name: item.name, score: 1.0)
                results.append(result)
            }
        }
        
        return results
    }
}