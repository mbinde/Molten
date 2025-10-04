//
//  SearchUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("SearchUtilities Tests")
struct SearchUtilitiesTests {
    
    // MARK: - Mock Data Setup
    
    // MARK: - Mock Searchable Implementation
    
    struct MockSearchableItem: Searchable, Identifiable {
        let id: String
        let searchableText: [String]
        
        init(id: String, searchableText: [String]) {
            self.id = id
            self.searchableText = searchableText
        }
    }
    
    private func createMockItems() -> [MockSearchableItem] {
        return [
            MockSearchableItem(id: "1", searchableText: ["apple", "fruit", "red"]),
            MockSearchableItem(id: "2", searchableText: ["banana", "fruit", "yellow"]),
            MockSearchableItem(id: "3", searchableText: ["carrot", "vegetable", "orange"]),
            MockSearchableItem(id: "4", searchableText: ["Apple", "FRUIT", "Green"]), // Mixed case
            MockSearchableItem(id: "5", searchableText: ["  spaced  ", "  text  "]), // Whitespace
            MockSearchableItem(id: "6", searchableText: [""]), // Empty
            MockSearchableItem(id: "7", searchableText: ["special@chars#test", "unicode-ñ-test"]) // Special chars
        ]
    }
    
    // MARK: - Basic Search Query Matching Tests
    
    @Test("Basic search query matching finds correct results")
    func basicSearchQueryMatching() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "fruit")
        
        #expect(results.count == 3) // Items 1, 2, 4 (case insensitive by default)
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "2" })
        #expect(results.contains { $0.id == "4" })
    }
    
    @Test("Empty search query returns all items")
    func emptySearchQueryReturnsAll() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "")
        
        #expect(results.count == items.count)
    }
    
    @Test("Whitespace-only search query returns all items")
    func whitespaceSearchQueryReturnsAll() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "   ")
        
        #expect(results.count == items.count)
    }
    
    @Test("No matching results returns empty array")
    func noMatchingResultsReturnsEmpty() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "nonexistent")
        
        #expect(results.isEmpty)
    }
    
    // MARK: - Search Term Normalization Tests
    
    @Test("Search normalizes whitespace in search terms")
    func searchNormalizesWhitespaceInSearchTerms() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "  fruit  ") // Extra whitespace
        
        #expect(results.count == 3) // Should still find fruit items
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "2" })
        #expect(results.contains { $0.id == "4" })
    }
    
    // MARK: - Search Performance Tests
    
    @Test("Search performance with large datasets")
    func searchPerformanceWithLargeDatasets() {
        // Create a large dataset (1000 items) with unique naming to avoid partial matches
        let largeItems = (1...1000).map { i in
            MockSearchableItem(id: "\(i)", searchableText: ["unique_item_\(i)_only", "cat_\(i)_unique", "type_\(i)_specific"])
        }
        
        let startTime = Date()
        let results = SearchUtilities.filter(largeItems, with: "unique_item_5_only")
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(results.count == 1) // Should find exactly one match
        #expect(results.first?.id == "5")
        #expect(duration < 0.1, "Search should complete within 100ms for 1000 items") // Performance assertion
    }
    
    // MARK: - Fuzzy vs Exact Search Behavior Tests
    
    @Test("Fuzzy search finds approximate matches")
    func fuzzySearchFindsApproximateMatches() {
        let items = createMockItems()
        let results = SearchUtilities.fuzzyFilter(items, with: "aple", tolerance: 2) // Missing 'p'
        
        #expect(!results.isEmpty)
        #expect(results.contains { $0.id == "1" || $0.id == "4" }) // Should find 'apple'/'Apple'
    }
    
    @Test("Exact search configuration requires exact matches")
    func exactSearchRequiresExactMatches() {
        let items = createMockItems()
        let config = SearchUtilities.SearchConfig.exact
        let results = SearchUtilities.filter(items, with: "fruit", config: config)
        
        #expect(results.count == 3) // Should find exact "fruit" in items 1, 2, 4
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "2" })
        #expect(results.contains { $0.id == "4" })
    }
    
    @Test("Fuzzy search configuration with tolerance")
    func fuzzySearchConfigurationWithTolerance() {
        let items = createMockItems()
        let config = SearchUtilities.SearchConfig.fuzzy
        let results = SearchUtilities.filter(items, with: "banan", config: config) // Missing 'a'
        
        #expect(!results.isEmpty)
        #expect(results.contains { $0.id == "2" }) // Should find 'banana' with fuzzy matching
    }
    
    // MARK: - Case Sensitivity Handling Tests
    
    @Test("Case insensitive search by default")
    func caseInsensitiveSearchByDefault() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "APPLE")
        
        #expect(results.count == 2) // Should find both 'apple' and 'Apple'
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "4" })
    }
    
    @Test("Case sensitive search configuration")
    func caseSensitiveSearchConfiguration() {
        let items = createMockItems()
        let config = SearchUtilities.SearchConfig(
            caseSensitive: true,
            exactMatch: false,
            fuzzyTolerance: nil,
            highlightMatches: false
        )
        let results = SearchUtilities.filter(items, with: "Apple", config: config)
        
        #expect(results.count == 1) // Should only find exact 'Apple', not 'apple'
        #expect(results.contains { $0.id == "4" })
    }
    
    // MARK: - Multiple Search Terms Tests
    
    @Test("Multiple search terms with AND logic")
    func multipleSearchTermsWithANDLogic() {
        let items = createMockItems()
        let searchTerms = ["fruit", "red"]
        let results = SearchUtilities.filterWithMultipleTerms(items, searchTerms: searchTerms)
        
        #expect(results.count == 1) // Only item 1 has both 'fruit' AND 'red'
        #expect(results.first?.id == "1")
    }
    
    @Test("Multiple search terms with no common results")
    func multipleSearchTermsWithNoCommonResults() {
        let items = createMockItems()
        let searchTerms = ["fruit", "vegetable"] // Contradictory terms
        let results = SearchUtilities.filterWithMultipleTerms(items, searchTerms: searchTerms)
        
        #expect(results.isEmpty) // No item should have both
    }
    
    @Test("Empty search terms array returns all items")
    func emptySearchTermsReturnsAll() {
        let items = createMockItems()
        let results = SearchUtilities.filterWithMultipleTerms(items, searchTerms: [])
        
        #expect(results.count == items.count)
    }
    
    // MARK: - Empty/Whitespace Search Queries Tests
    
    @Test("Search handles items with empty searchable text")
    func searchHandlesItemsWithEmptySearchableText() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "test")
        
        // Should not crash and should handle item 6 with empty searchableText gracefully
        #expect(!results.contains { $0.id == "6" })
    }
    
    @Test("Search handles items with whitespace-only text")
    func searchHandlesItemsWithWhitespaceOnlyText() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "spaced")
        
        #expect(results.contains { $0.id == "5" }) // Should find in trimmed content
    }
    
    // MARK: - Special Characters Tests
    
    @Test("Search handles special characters correctly")
    func searchHandlesSpecialCharacters() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "special@chars")
        
        #expect(results.contains { $0.id == "7" })
    }
    
    @Test("Search handles Unicode characters correctly")
    func searchHandlesUnicodeCharacters() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "ñ")
        
        #expect(results.contains { $0.id == "7" })
    }
    
    // MARK: - Unicode and International Character Support Tests
    
    @Test("Search supports international characters")
    func searchSupportsInternationalCharacters() {
        let internationalItems = [
            MockSearchableItem(id: "1", searchableText: ["café", "français"]),
            MockSearchableItem(id: "2", searchableText: ["über", "deutsch"]),
            MockSearchableItem(id: "3", searchableText: ["москва", "русский"]),
            MockSearchableItem(id: "4", searchableText: ["東京", "日本語"])
        ]
        
        let results1 = SearchUtilities.filter(internationalItems, with: "café")
        let results2 = SearchUtilities.filter(internationalItems, with: "über")
        let results3 = SearchUtilities.filter(internationalItems, with: "москва")
        let results4 = SearchUtilities.filter(internationalItems, with: "東京")
        
        #expect(results1.count == 1)
        #expect(results2.count == 1)
        #expect(results3.count == 1)
        #expect(results4.count == 1)
    }
    
    // MARK: - Partial Word Matching Tests
    
    @Test("Search supports partial word matching")
    func searchSupportsPartialWordMatching() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "app") // Partial match for 'apple'
        
        #expect(results.count == 2) // Should find both 'apple' and 'Apple'
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "4" })
    }
    
    @Test("Search with single character matching")
    func searchWithSingleCharacterMatching() {
        let items = createMockItems()
        let results = SearchUtilities.filter(items, with: "a")
        
        #expect(!results.isEmpty) // Should find items containing 'a'
    }
    
    // MARK: - Weighted Search Tests
    
    @Test("Weighted search returns results with relevance scores")
    func weightedSearchReturnsResultsWithRelevanceScores() {
        let items = createMockItems()
        let results = SearchUtilities.weightedSearch(items, with: "fruit")
        
        #expect(results.count == 3) // Should find 3 items with 'fruit'
        #expect(results.allSatisfy { $0.relevance > 0 }) // All results should have positive relevance
        
        // Results should be sorted by relevance (highest first)
        let relevanceScores = results.map { $0.relevance }
        let sortedScores = relevanceScores.sorted(by: >)
        #expect(relevanceScores == sortedScores, "Results should be sorted by relevance")
    }
    
    @Test("Weighted search with field weights prioritizes correctly")
    func weightedSearchWithFieldWeightsPrioritizesCorrectly() {
        let items = createMockItems()
        let fieldWeights = ["fruit": 10.0, "red": 1.0] // Higher weight for 'fruit'
        let results = SearchUtilities.weightedSearch(items, with: "fruit", fieldWeights: fieldWeights)
        
        #expect(results.count == 3)
        #expect(results.first?.relevance ?? 0 > 0, "Highest relevance item should have positive score")
    }
    
    // MARK: - SearchConfig Tests
    
    @Test("SearchConfig default values are correct")
    func searchConfigDefaultValuesAreCorrect() {
        let config = SearchUtilities.SearchConfig.default
        
        #expect(config.caseSensitive == false)
        #expect(config.exactMatch == false)
        #expect(config.fuzzyTolerance == nil)
        #expect(config.highlightMatches == false)
    }
    
    @Test("SearchConfig fuzzy preset has correct values")
    func searchConfigFuzzyPresetHasCorrectValues() {
        let config = SearchUtilities.SearchConfig.fuzzy
        
        #expect(config.caseSensitive == false)
        #expect(config.exactMatch == false)
        #expect(config.fuzzyTolerance == 2)
        #expect(config.highlightMatches == false)
    }
    
    @Test("SearchConfig exact preset has correct values")
    func searchConfigExactPresetHasCorrectValues() {
        let config = SearchUtilities.SearchConfig.exact
        
        #expect(config.caseSensitive == false)
        #expect(config.exactMatch == true)
        #expect(config.fuzzyTolerance == nil)
        #expect(config.highlightMatches == false)
    }
    
    // MARK: - Levenshtein Distance Tests
    
    @Test("Fuzzy search uses Levenshtein distance correctly")
    func fuzzySearchUsesLevenshteinDistanceCorrectly() {
        let items = [
            MockSearchableItem(id: "1", searchableText: ["hello"]),
            MockSearchableItem(id: "2", searchableText: ["helo"]), // 1 char diff
            MockSearchableItem(id: "3", searchableText: ["hllo"]), // 1 char diff
            MockSearchableItem(id: "4", searchableText: ["world"]) // Completely different
        ]
        
        let results = SearchUtilities.fuzzyFilter(items, with: "hello", tolerance: 1)
        
        #expect(results.count == 3) // Should find items 1, 2, 3 but not 4
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "2" })
        #expect(results.contains { $0.id == "3" })
        #expect(!results.contains { $0.id == "4" })
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Search handles nil and empty arrays gracefully")
    func searchHandlesNilAndEmptyArraysGracefully() {
        let emptyItems: [MockSearchableItem] = []
        let results = SearchUtilities.filter(emptyItems, with: "test")
        
        #expect(results.isEmpty)
    }
    
    @Test("Search with very long search terms")
    func searchWithVeryLongSearchTerms() {
        let items = createMockItems()
        let longSearchTerm = String(repeating: "a", count: 1000)
        let results = SearchUtilities.filter(items, with: longSearchTerm)
        
        #expect(results.isEmpty) // Should not crash and return empty results
    }
    
    @Test("Search with mixed empty and valid searchable text")
    func searchWithMixedEmptyAndValidSearchableText() {
        let mixedItems = [
            MockSearchableItem(id: "1", searchableText: ["valid", "", "text"]),
            MockSearchableItem(id: "2", searchableText: ["", "", ""]),
            MockSearchableItem(id: "3", searchableText: ["another", "valid"])
        ]
        
        let results = SearchUtilities.filter(mixedItems, with: "valid")
        
        #expect(results.count == 2) // Should find items 1 and 3
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "3" })
    }
}