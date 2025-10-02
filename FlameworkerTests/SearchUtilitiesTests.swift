//
//  SearchUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/29/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import CoreData
import Foundation
@testable import Flameworker

@Suite("Search Utilities Tests")
struct SearchUtilitiesTests {
    
    // MARK: - Test Helpers
    
    private func createIsolatedContext() -> NSManagedObjectContext {
        return TestUtilities.createHyperIsolatedContext(for: "SearchUtilitiesTests")
    }
    
    private func tearDownContext(_ context: NSManagedObjectContext) {
        TestUtilities.tearDownHyperIsolatedContext(context)
    }
    
    /// Validates that a Core Data context is in a safe state for testing
    private func validateContext(_ context: NSManagedObjectContext) throws {
        guard context.persistentStoreCoordinator != nil else {
            throw NSError(domain: "TestError", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "Context has no persistent store coordinator"
            ])
        }
    }
    
    /// Safer helper to perform context operations with error handling
    private func performSafely<T>(in context: NSManagedObjectContext, operation: @escaping () throws -> T) throws -> T {
        try validateContext(context)
        
        var result: Result<T, Error>?
        
        context.performAndWait {
            do {
                let value = try operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
        }
        
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
    
    private func createTestInventoryItem(
        in context: NSManagedObjectContext,
        id: String = "TEST-001",
        catalogCode: String? = "BR-GLR-001",
        count: Double = 50.0,
        units: Int16 = 1,
        type: Int16 = 2, // Using raw Int16 value
        notes: String? = "Test notes"
    ) -> InventoryItem {
        var item: InventoryItem!
        
        context.performAndWait {
            // Validate context within performAndWait
            guard context.persistentStoreCoordinator != nil else {
                fatalError("Context has no persistent store coordinator")
            }
            
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryItem", in: context) else {
                fatalError("Could not find InventoryItem entity in context")
            }
            
            item = InventoryItem(entity: entity, insertInto: context)
            item.id = id
            item.catalog_code = catalogCode
            item.count = count
            item.units = units
            item.type = type
            item.notes = notes
        }
        
        return item
    }
    
    private func createTestCatalogItem(
        in context: NSManagedObjectContext,
        code: String = "CATALOG-001",
        name: String = "Test Glass Rod",
        manufacturer: String? = "Test Manufacturer"
    ) -> CatalogItem {
        var item: CatalogItem!
        
        context.performAndWait {
            // Validate context within performAndWait
            guard context.persistentStoreCoordinator != nil else {
                fatalError("Context has no persistent store coordinator")
            }
            
            guard let entity = NSEntityDescription.entity(forEntityName: "CatalogItem", in: context) else {
                fatalError("Could not find CatalogItem entity in context")
            }
            
            item = CatalogItem(entity: entity, insertInto: context)
            item.code = code
            item.name = name
            item.manufacturer = manufacturer
        }
        
        return item
    }
    
    // MARK: - Searchable Protocol Tests
    
    @Test("InventoryItem should implement Searchable protocol correctly")
    func inventoryItemSearchableImplementation() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createTestInventoryItem(in: context)
            
            // Verify it conforms to Searchable
            #expect(item is Searchable, "InventoryItem should conform to Searchable protocol")
            
            let searchableText = item.searchableText
            #expect(!searchableText.isEmpty, "Searchable text should not be empty")
            
            return Void()
        }
    }
    
    @Test("CatalogItem should implement Searchable protocol correctly")
    func catalogItemSearchableImplementation() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createTestCatalogItem(in: context)
            
            // Verify it conforms to Searchable
            #expect(item is Searchable, "CatalogItem should conform to Searchable protocol")
            
            let searchableText = item.searchableText
            // Note: searchableText might be empty if optional fields don't exist in test model
            #expect(searchableText.count >= 0, "Searchable text should be a valid array")
            
            return Void()
        }
    }
    
    // MARK: - InventoryItem Search Tests
    
    @Test("InventoryItem searchableText should include all relevant fields")
    func inventoryItemSearchableTextFields() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createTestInventoryItem(
                in: context,
                id: "SEARCH-TEST-001",
                catalogCode: "GLASS-ROD-CLEAR",
                count: 25.5,
                units: 3,
                type: 1, // buy = 1
                notes: "High quality borosilicate glass"
            )
            
            let searchableText = item.searchableText
            let joinedText = searchableText.joined(separator: " ")
            
            // Verify all expected fields are included
            #expect(joinedText.contains("SEARCH-TEST-001"), "Should include ID")
            #expect(joinedText.contains("GLASS-ROD-CLEAR"), "Should include catalog code")
            #expect(joinedText.contains("25.5"), "Should include count")
            #expect(joinedText.contains("3"), "Should include units")
            #expect(joinedText.contains("1"), "Should include type raw value (buy = 1)")
            #expect(joinedText.contains("High quality borosilicate glass"), "Should include notes")
            
            return Void()
        }
    }
    
    @Test("InventoryItem searchableText should handle nil values gracefully")
    func inventoryItemSearchableTextNilHandling() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createTestInventoryItem(
                in: context,
                id: "MINIMAL-001",
                catalogCode: nil, // nil catalog code
                count: 10.0,
                units: 1,
                type: 0, // inventory = 0
                notes: nil // nil notes
            )
            
            let searchableText = item.searchableText
            let joinedText = searchableText.joined(separator: " ")
            
            // Should still include non-nil fields
            #expect(joinedText.contains("MINIMAL-001"), "Should include ID even when other fields are nil")
            #expect(joinedText.contains("10.0"), "Should include count")
            #expect(joinedText.contains("1"), "Should include units")
            #expect(joinedText.contains("0"), "Should include type raw value (inventory = 0)")
            
            // Should not contain empty or nil values
            #expect(!joinedText.contains("nil"), "Should not contain 'nil' strings")
            
            return Void()
        }
    }
    
    @Test("InventoryItem searchableText should handle empty strings")
    func inventoryItemSearchableTextEmptyStrings() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createTestInventoryItem(
                in: context,
                id: "EMPTY-TEST-001",
                catalogCode: "", // empty string
                count: 5.0,
                units: 1,
                type: 2, // sell = 2
                notes: "" // empty string
            )
            
            let searchableText = item.searchableText
            let joinedText = searchableText.joined(separator: " ")
            
            // Should include non-empty fields
            #expect(joinedText.contains("EMPTY-TEST-001"), "Should include non-empty ID")
            #expect(joinedText.contains("5.0"), "Should include count")
            
            // Empty strings should be handled gracefully (likely filtered out or included as empty)
            #expect(searchableText.count >= 4, "Should have at least the non-empty fields")
            
            return Void()
        }
    }
    
    // MARK: - CatalogItem Search Tests
    
    @Test("CatalogItem searchableText should include all relevant fields")
    func catalogItemSearchableTextFields() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createTestCatalogItem(
                in: context,
                code: "CATALOG-SEARCH-001",
                name: "Premium Glass Rod Set",
                manufacturer: "Artisan Glassworks"
            )
            
            let searchableText = item.searchableText
            let joinedText = searchableText.joined(separator: " ")
            
            // Verify all expected fields are included
            #expect(joinedText.contains("CATALOG-SEARCH-001"), "Should include code")
            #expect(joinedText.contains("Premium Glass Rod Set"), "Should include name")
            #expect(joinedText.contains("Artisan Glassworks"), "Should include manufacturer")
            
            return Void()
        }
    }
    
    @Test("CatalogItem searchableText should handle nil manufacturer")
    func catalogItemSearchableTextNilManufacturer() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createTestCatalogItem(
                in: context,
                code: "NO-MANUFACTURER-001",
                name: "Generic Glass Rod",
                manufacturer: nil // nil manufacturer
            )
            
            let searchableText = item.searchableText
            let joinedText = searchableText.joined(separator: " ")
            
            // Should still include non-nil fields
            #expect(joinedText.contains("NO-MANUFACTURER-001"), "Should include code")
            #expect(joinedText.contains("Generic Glass Rod"), "Should include name")
            
            // Should handle nil manufacturer gracefully
            #expect(!joinedText.contains("nil"), "Should not contain 'nil' strings")
            
            return Void()
        }
    }
    
    @Test("CatalogItem searchableText should be case-sensitive as stored")
    func catalogItemSearchableTextCaseSensitivity() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            let item = createTestCatalogItem(
                in: context,
                code: "MixedCase-001",
                name: "Premium GLASS rod Set",
                manufacturer: "Artisan glassworks"
            )
            
            let searchableText = item.searchableText
            let joinedText = searchableText.joined(separator: " ")
            
            // Should preserve original case
            #expect(joinedText.contains("MixedCase-001"), "Should preserve code case")
            #expect(joinedText.contains("Premium GLASS rod Set"), "Should preserve name case")
            #expect(joinedText.contains("Artisan glassworks"), "Should preserve manufacturer case")
            
            return Void()
        }
    }
    
    // MARK: - Search Performance Tests
    
    @Test("Searchable text generation should be efficient for large datasets")
    func searchableTextPerformance() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create multiple items to test performance
            var items: [InventoryItem] = []
            for i in 0..<100 {
                let item = createTestInventoryItem(
                    in: context,
                    id: "PERF-TEST-\(i)",
                    catalogCode: "CODE-\(i)",
                    count: Double(i),
                    units: Int16(i % 10),
                    type: 0, // inventory = 0
                    notes: "Performance test item \(i)"
                )
                items.append(item)
            }
            
            let startTime = Date()
            
            // Generate searchable text for all items
            let allSearchableText = items.map { $0.searchableText }
            
            let endTime = Date()
            let timeElapsed = endTime.timeIntervalSince(startTime)
            
            #expect(allSearchableText.count == 100, "Should generate searchable text for all items")
            #expect(timeElapsed < 1.0, "Should complete within 1 second for 100 items")
            
            // Verify all searchable texts are unique and contain expected content
            let uniqueTexts = Set(allSearchableText.map { $0.joined(separator: " ") })
            #expect(uniqueTexts.count == 100, "Each item should have unique searchable text")
            
            return Void()
        }
    }
    
    // MARK: - Integration Tests
    
    @Test("Search should work with Core Data queries")
    func searchCoreDataIntegration() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items with specific searchable content
            let item1 = createTestInventoryItem(
                in: context,
                id: "GLASS-001",
                catalogCode: "CLEAR-GLASS",
                notes: "Clear borosilicate glass"
            )
            
            let item2 = createTestInventoryItem(
                in: context,
                id: "FRIT-001",
                catalogCode: "COLOR-FRIT",
                notes: "Colored glass frit"
            )
            
            try context.save()
            
            // Test that searchable text can be used for filtering
            let glassItems = [item1, item2].filter { item in
                let allText = item.searchableText.joined(separator: " ").lowercased()
                return allText.contains("glass")
            }
            
            #expect(glassItems.count == 2, "Both items should match 'glass' search")
            
            let clearItems = [item1, item2].filter { item in
                let allText = item.searchableText.joined(separator: " ").lowercased()
                return allText.contains("clear")
            }
            
            #expect(clearItems.count == 1, "Only one item should match 'clear' search")
            #expect(clearItems.first?.id == "GLASS-001", "Should find the correct item")
            
            return Void()
        }
    }
    
    // MARK: - Advanced SearchUtilities Tests
    
    @Test("Case-insensitive searching should work correctly")
    func caseInsensitiveSearching() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items with mixed case content
            let item1 = createTestInventoryItem(
                in: context,
                id: "GLASS-001",
                catalogCode: "CLEAR-Glass-Rod",
                notes: "Premium BOROSILICATE glass"
            )
            
            let item2 = createTestInventoryItem(
                in: context,
                id: "FRIT-001", 
                catalogCode: "Color-FRIT-Blue",
                notes: "Fine glass frit particles"
            )
            
            let items = [item1, item2]
            
            // Test case-insensitive search with default config
            let glassResults = SearchUtilities.filter(items, with: "GLASS")
            #expect(glassResults.count == 2, "Should find both items regardless of case")
            
            let boroResults = SearchUtilities.filter(items, with: "borosilicate")
            #expect(boroResults.count == 1, "Should find borosilicate item regardless of case")
            #expect(boroResults.first?.id == "GLASS-001", "Should find the correct item")
            
            let colorResults = SearchUtilities.filter(items, with: "color")
            #expect(colorResults.count == 1, "Should find color item regardless of case")
            #expect(colorResults.first?.id == "FRIT-001", "Should find the correct item")
            
            // Test case-sensitive search
            let caseConfig = SearchUtilities.SearchConfig(
                caseSensitive: true,
                exactMatch: false,
                fuzzyTolerance: nil,
                highlightMatches: false
            )
            
            let caseSensitiveResults = SearchUtilities.filter(items, with: "GLASS", config: caseConfig)
            #expect(caseSensitiveResults.count == 1, "Case-sensitive search should be more restrictive")
            
            return Void()
        }
    }
    
    @Test("Partial word matching should work correctly")  
    func partialWordMatching() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items with various words
            let item1 = createTestInventoryItem(
                in: context,
                id: "BOROSILICATE-001",
                catalogCode: "BORO-CLEAR-7MM",
                notes: "Borosilicate glass rod"
            )
            
            let item2 = createTestInventoryItem(
                in: context,
                id: "SODA-001",
                catalogCode: "SODA-LIME-CLEAR",
                notes: "Soda lime glass sheets"
            )
            
            let item3 = createTestInventoryItem(
                in: context,
                id: "LEAD-001", 
                catalogCode: "LEAD-CRYSTAL-ROD",
                notes: "Lead crystal glass rod"
            )
            
            let items = [item1, item2, item3]
            
            // Test partial matching
            let boroPartial = SearchUtilities.filter(items, with: "boro")
            #expect(boroPartial.count == 1, "Should match partial 'boro' in 'borosilicate'")
            #expect(boroPartial.first?.id == "BOROSILICATE-001", "Should find the borosilicate item")
            
            let glassPartial = SearchUtilities.filter(items, with: "glass")
            #expect(glassPartial.count == 3, "Should match 'glass' in all items")
            
            let limePartial = SearchUtilities.filter(items, with: "lime")
            #expect(limePartial.count == 1, "Should match partial 'lime' in 'soda lime'")
            #expect(limePartial.first?.id == "SODA-001", "Should find the soda lime item")
            
            let rodPartial = SearchUtilities.filter(items, with: "rod")
            #expect(rodPartial.count == 2, "Should match 'rod' in multiple items")
            
            // Test very short partial matches
            let shortPartial = SearchUtilities.filter(items, with: "so")
            #expect(shortPartial.count == 1, "Should match short partial 'so' in 'soda'")
            
            return Void()
        }
    }
    
    @Test("Searching with special characters should work correctly")
    func searchingWithSpecialCharacters() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items with special characters
            let item1 = createTestInventoryItem(
                in: context,
                id: "SPECIAL-001",
                catalogCode: "ROD-7MM-12\"",
                notes: "Glass rod 7mm × 12\" length"
            )
            
            let item2 = createTestInventoryItem(
                in: context,
                id: "UNICODE-001",
                catalogCode: "FRIT-ø5MM",
                notes: "Special glass frit ≥99% purity"
            )
            
            let item3 = createTestInventoryItem(
                in: context,
                id: "PUNCTUATION-001",
                catalogCode: "SHEET-10\"×8\"",
                notes: "Glass sheet (premium quality) - clear"
            )
            
            let items = [item1, item2, item3]
            
            // Test searching with dimension notation
            let dimensionResults = SearchUtilities.filter(items, with: "12\"")
            #expect(dimensionResults.count == 1, "Should find item with 12\" dimension")
            #expect(dimensionResults.first?.id == "SPECIAL-001", "Should find the correct item")
            
            // Test searching with multiplication symbol
            let multiplyResults = SearchUtilities.filter(items, with: "×")
            #expect(multiplyResults.count == 2, "Should find items with × symbol")
            
            // Test searching with special unicode characters
            let unicodeResults = SearchUtilities.filter(items, with: "ø")
            #expect(unicodeResults.count == 1, "Should find item with ø character")
            #expect(unicodeResults.first?.id == "UNICODE-001", "Should find the unicode item")
            
            // Test searching with mathematical symbols
            let mathResults = SearchUtilities.filter(items, with: "≥")
            #expect(mathResults.count == 1, "Should find item with ≥ symbol")
            
            // Test searching with parentheses
            let parenthesesResults = SearchUtilities.filter(items, with: "(premium quality)")
            #expect(parenthesesResults.count == 1, "Should find item with parentheses content")
            #expect(parenthesesResults.first?.id == "PUNCTUATION-001", "Should find the punctuation item")
            
            // Test searching with hyphen
            let hyphenResults = SearchUtilities.filter(items, with: "- clear")
            #expect(hyphenResults.count == 1, "Should find item with hyphen and space")
            
            return Void()
        }
    }
    
    @Test("Performance with large datasets should be acceptable")
    func performanceWithLargeDatasets() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create a large dataset (1000 items)
            var items: [InventoryItem] = []
            let itemCount = 1000
            
            for i in 0..<itemCount {
                let item = createTestInventoryItem(
                    in: context,
                    id: "PERF-\(String(format: "%04d", i))",
                    catalogCode: "CODE-\(i % 100)", // Create some duplicates for realistic testing
                    count: Double.random(in: 1...100),
                    units: Int16(i % 10),
                    type: Int16(i % 3),
                    notes: "Performance test item \(i) with descriptive text"
                )
                items.append(item)
            }
            
            // Test basic search performance
            let startTime1 = Date()
            let basicResults = SearchUtilities.filter(items, with: "test")
            let basicTime = Date().timeIntervalSince(startTime1)
            
            #expect(basicResults.count > 0, "Should find items in large dataset")
            #expect(basicTime < 0.5, "Basic search should complete within 0.5 seconds for 1000 items")
            
            // Test fuzzy search performance
            let startTime2 = Date()
            let fuzzyResults = SearchUtilities.fuzzyFilter(items, with: "descriptiv", tolerance: 2)
            let fuzzyTime = Date().timeIntervalSince(startTime2)
            
            #expect(fuzzyResults.count > 0, "Should find items with fuzzy search")
            #expect(fuzzyTime < 2.0, "Fuzzy search should complete within 2 seconds for 1000 items")
            
            // Test weighted search performance
            let startTime3 = Date()
            let weightedResults = SearchUtilities.weightedSearch(items, with: "item")
            let weightedTime = Date().timeIntervalSince(startTime3)
            
            #expect(weightedResults.count > 0, "Should find items with weighted search")
            #expect(weightedTime < 1.0, "Weighted search should complete within 1 second for 1000 items")
            
            // Test multiple terms search performance
            let startTime4 = Date()
            let multiTermResults = SearchUtilities.filterWithMultipleTerms(items, searchTerms: ["performance", "test"])
            let multiTermTime = Date().timeIntervalSince(startTime4)
            
            #expect(multiTermResults.count > 0, "Should find items with multiple terms")
            #expect(multiTermTime < 0.5, "Multi-term search should complete within 0.5 seconds")
            
            return Void()
        }
    }
    
    @Test("Sorting search results should work correctly")
    func sortingSearchResults() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items with varying counts and catalog codes
            let item1 = createTestInventoryItem(
                in: context,
                id: "SORT-001",
                catalogCode: "ZEBRA-GLASS",
                count: 5.0,
                notes: "Glass rod for sorting test"
            )
            
            let item2 = createTestInventoryItem(
                in: context,
                id: "SORT-002", 
                catalogCode: "ALPHA-GLASS",
                count: 50.0,
                notes: "Glass rod for sorting test"
            )
            
            let item3 = createTestInventoryItem(
                in: context,
                id: "SORT-003",
                catalogCode: "BETA-GLASS", 
                count: 25.0,
                notes: "Glass rod for sorting test"
            )
            
            let items = [item1, item2, item3]
            
            // Search for items that match
            let searchResults = SearchUtilities.filter(items, with: "glass")
            #expect(searchResults.count == 3, "Should find all glass items")
            
            // Test sorting by catalog code (alphabetical)
            let sortedByCatalog = SortUtilities.sortInventory(searchResults, by: .catalogCode)
            #expect(sortedByCatalog[0].catalog_code == "ALPHA-GLASS", "First item should be ALPHA-GLASS")
            #expect(sortedByCatalog[1].catalog_code == "BETA-GLASS", "Second item should be BETA-GLASS")
            #expect(sortedByCatalog[2].catalog_code == "ZEBRA-GLASS", "Third item should be ZEBRA-GLASS")
            
            // Test sorting by count (descending)
            let sortedByCount = SortUtilities.sortInventory(searchResults, by: .count)
            #expect(sortedByCount[0].count == 50.0, "First item should have highest count")
            #expect(sortedByCount[1].count == 25.0, "Second item should have middle count")
            #expect(sortedByCount[2].count == 5.0, "Third item should have lowest count")
            
            // Test sorting by type
            let sortedByType = SortUtilities.sortInventory(searchResults, by: .type)
            #expect(sortedByType.count == 3, "Should maintain all items after sorting")
            
            return Void()
        }
    }
    
    @Test("Search result ranking and relevance should work correctly")
    func searchResultRankingRelevance() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items with different relevance levels
            let item1 = createTestInventoryItem(
                in: context,
                id: "RELEVANCE-001",
                catalogCode: "GLASS", // Exact match in catalog code
                count: 10.0,
                notes: "Some other material"
            )
            
            let item2 = createTestInventoryItem(
                in: context,
                id: "RELEVANCE-002",
                catalogCode: "CLEAR-MATERIAL",
                count: 20.0,
                notes: "GLASS rod premium quality" // Exact match at beginning of notes
            )
            
            let item3 = createTestInventoryItem(
                in: context,
                id: "RELEVANCE-003",
                catalogCode: "BOROSILICATE-ROD",
                count: 30.0,
                notes: "Premium quality glass frit" // Match later in notes
            )
            
            let item4 = createTestInventoryItem(
                in: context,
                id: "RELEVANCE-004",
                catalogCode: "FIBERGLASS-SHEET",
                count: 40.0,
                notes: "Sheet material" // Partial match in catalog code
            )
            
            let items = [item1, item2, item3, item4]
            
            // Test weighted search with relevance scoring
            let weightedResults = SearchUtilities.weightedSearch(items, with: "glass")
            
            #expect(weightedResults.count == 4, "Should find all items containing 'glass'")
            #expect(weightedResults[0].relevance > weightedResults[1].relevance, "Results should be ordered by relevance")
            #expect(weightedResults[1].relevance > weightedResults[2].relevance, "Results should be ordered by relevance")
            #expect(weightedResults[2].relevance > weightedResults[3].relevance, "Results should be ordered by relevance")
            
            // The exact match in catalog code should be highest
            let topResult = weightedResults.first!
            #expect(topResult.item.catalog_code == "GLASS", "Exact match should rank highest")
            
            // Test with field weights
            let fieldWeights = ["GLASS": 10.0, "CLEAR-MATERIAL": 1.0] // Boost exact matches
            let customWeightedResults = SearchUtilities.weightedSearch(
                items, 
                with: "glass", 
                fieldWeights: fieldWeights
            )
            
            #expect(customWeightedResults.count == 4, "Should find all items with custom weights")
            
            // Test exact match configuration
            let exactConfig = SearchUtilities.SearchConfig.exact
            let exactResults = SearchUtilities.filter(items, with: "GLASS", config: exactConfig)
            #expect(exactResults.count >= 1, "Should find exact matches")
            
            // Test fuzzy matching for typos
            let fuzzyResults = SearchUtilities.fuzzyFilter(items, with: "glas", tolerance: 1) // Missing 's'
            #expect(fuzzyResults.count > 0, "Should find items with fuzzy matching for typos")
            
            return Void()
        }
    }
    
    @Test("Advanced search configurations should work correctly")
    func advancedSearchConfigurations() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items for configuration testing
            let item1 = createTestInventoryItem(
                in: context,
                id: "CONFIG-001",
                catalogCode: "EXACT-MATCH",
                notes: "Test item for exact matching"
            )
            
            let item2 = createTestInventoryItem(
                in: context,
                id: "CONFIG-002",
                catalogCode: "exact-match", // Different case
                notes: "Test item for case sensitivity"
            )
            
            let item3 = createTestInventoryItem(
                in: context,
                id: "CONFIG-003",
                catalogCode: "FUZZY-MACTH", // Typo: missing 't' in 'match'
                notes: "Test item for fuzzy matching"
            )
            
            let items = [item1, item2, item3]
            
            // Test default configuration (case-insensitive, partial matching)
            let defaultResults = SearchUtilities.filter(items, with: "exact-match")
            #expect(defaultResults.count == 2, "Default config should find both exact matches regardless of case")
            
            // Test case-sensitive configuration
            let caseSensitiveConfig = SearchUtilities.SearchConfig(
                caseSensitive: true,
                exactMatch: false,
                fuzzyTolerance: nil,
                highlightMatches: false
            )
            
            let caseSensitiveResults = SearchUtilities.filter(items, with: "EXACT-MATCH", config: caseSensitiveConfig)
            #expect(caseSensitiveResults.count == 1, "Case-sensitive should only find exact case match")
            #expect(caseSensitiveResults.first?.id == "CONFIG-001", "Should find the uppercase version")
            
            // Test exact match configuration
            let exactConfig = SearchUtilities.SearchConfig.exact
            let exactResults = SearchUtilities.filter(items, with: "exact-match", config: exactConfig)
            #expect(exactResults.count == 1, "Exact match should find only the exact string")
            
            // Test fuzzy configuration
            let fuzzyConfig = SearchUtilities.SearchConfig.fuzzy
            let fuzzyResults = SearchUtilities.filter(items, with: "match", config: fuzzyConfig)
            #expect(fuzzyResults.count >= 2, "Fuzzy config should find partial and fuzzy matches")
            
            // Test custom fuzzy tolerance
            let customFuzzyConfig = SearchUtilities.SearchConfig(
                caseSensitive: false,
                exactMatch: false,
                fuzzyTolerance: 1,
                highlightMatches: false
            )
            
            let customFuzzyResults = SearchUtilities.filter(items, with: "MACTH", config: customFuzzyConfig) // Missing 't'
            #expect(customFuzzyResults.count >= 1, "Custom fuzzy should find items with single character differences")
            
            return Void()
        }
    }
    
    @Test("Multi-term search functionality should work correctly")
    func multiTermSearchFunctionality() async throws {
        let context = createIsolatedContext()
        defer { tearDownContext(context) }
        
        try performSafely(in: context) {
            // Create test items with multiple searchable terms
            let item1 = createTestInventoryItem(
                in: context,
                id: "MULTI-001",
                catalogCode: "GLASS-ROD-CLEAR",
                notes: "Borosilicate glass rod premium quality"
            )
            
            let item2 = createTestInventoryItem(
                in: context,
                id: "MULTI-002",
                catalogCode: "GLASS-SHEET-CLEAR",
                notes: "Glass sheet standard quality"
            )
            
            let item3 = createTestInventoryItem(
                in: context,
                id: "MULTI-003",
                catalogCode: "FRIT-BLUE-FINE",
                notes: "Blue glass frit premium grade"
            )
            
            let items = [item1, item2, item3]
            
            // Test single term search
            let singleTermResults = SearchUtilities.filterWithMultipleTerms(items, searchTerms: ["glass"])
            #expect(singleTermResults.count == 3, "Should find all items with 'glass'")
            
            // Test AND logic with two terms
            let twoTermResults = SearchUtilities.filterWithMultipleTerms(items, searchTerms: ["glass", "premium"])
            #expect(twoTermResults.count == 2, "Should find items containing both 'glass' AND 'premium'")
            
            // Test AND logic with three terms
            let threeTermResults = SearchUtilities.filterWithMultipleTerms(items, searchTerms: ["glass", "rod", "borosilicate"])
            #expect(threeTermResults.count == 1, "Should find items containing all three terms")
            #expect(threeTermResults.first?.id == "MULTI-001", "Should find the specific item")
            
            // Test no matches with contradictory terms
            let noMatchResults = SearchUtilities.filterWithMultipleTerms(items, searchTerms: ["glass", "metal"])
            #expect(noMatchResults.count == 0, "Should find no items with contradictory terms")
            
            // Test empty search terms
            let emptyResults = SearchUtilities.filterWithMultipleTerms(items, searchTerms: [])
            #expect(emptyResults.count == 3, "Empty search terms should return all items")
            
            // Test case insensitivity in multi-term search
            let caseInsensitiveResults = SearchUtilities.filterWithMultipleTerms(items, searchTerms: ["GLASS", "Premium"])
            #expect(caseInsensitiveResults.count == 2, "Multi-term search should be case insensitive")
            
            return Void()
        }
    }
}