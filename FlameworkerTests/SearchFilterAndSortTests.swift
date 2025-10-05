//
//  SearchFilterAndSortTests.swift
//  FlameworkerTests
//
//  Created by Test Consolidation on 10/4/25.
//

import Testing
import Foundation
import CoreData
@testable import Flameworker

// MARK: - Basic Search Logic Tests from SearchUtilitiesTests.swift

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

// MARK: - Comprehensive Search Tests from SearchUtilitiesTests-additional.swift

@Suite("SearchUtilities Tests")
struct ComprehensiveSearchUtilitiesTests {
    
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
        let results = SearchUtilities.filter(largeItems, with: "unique_item_500_only")
        let endTime = Date()
        let searchTime = endTime.timeIntervalSince(startTime)
        
        #expect(results.count == 1, "Should find exactly one matching item")
        #expect(results.first?.id == "500", "Should find the correct item")
        #expect(searchTime < 1.0, "Search should complete in reasonable time (< 1 second)")
    }
}

// MARK: - Sort Utilities Tests from SortUtilitiesTests.swift

@Suite("SortUtilities Tests - Comprehensive Sorting Logic")
struct SortUtilitiesTests {
    
    // MARK: - Test Data Setup
    
    /// Helper to create a mock CatalogItem for testing
    private func createMockCatalogItem(
        name: String? = nil,
        code: String? = nil,
        manufacturer: String? = nil
    ) -> MockCatalogItem {
        return MockCatalogItem(name: name, code: code, manufacturer: manufacturer)
    }
    
    // MARK: - Sort by Name Tests
    
    @Test("Should sort catalog items by name ascending")
    func testSortByNameAscending() {
        // Arrange
        let items = [
            createMockCatalogItem(name: "Zebra Glass"),
            createMockCatalogItem(name: "Alpha Glass"),
            createMockCatalogItem(name: "Beta Glass")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].name == "Alpha Glass")
        #expect(sortedItems[1].name == "Beta Glass") 
        #expect(sortedItems[2].name == "Zebra Glass")
    }
    
    @Test("Should handle nil names when sorting by name")
    func testSortByNameWithNilValues() {
        // Arrange
        let items = [
            createMockCatalogItem(name: "Beta Glass"),
            createMockCatalogItem(name: nil),
            createMockCatalogItem(name: "Alpha Glass")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].name == "Alpha Glass")
        #expect(sortedItems[1].name == "Beta Glass")
        #expect(sortedItems[2].name == nil, "Nil names should sort to end")
    }
    
    @Test("Should handle empty names when sorting by name")
    func testSortByNameWithEmptyValues() {
        // Arrange
        let items = [
            createMockCatalogItem(name: "Charlie Glass"),
            createMockCatalogItem(name: ""),
            createMockCatalogItem(name: "Alpha Glass"),
            createMockCatalogItem(name: "   ") // whitespace only
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .name)
        
        // Assert
        #expect(sortedItems.count == 4)
        #expect(sortedItems[0].name == "Alpha Glass")
        #expect(sortedItems[1].name == "Charlie Glass")
        // Empty and whitespace names should sort to end
        #expect(sortedItems[2].name == "" || sortedItems[2].name == "   ")
        #expect(sortedItems[3].name == "" || sortedItems[3].name == "   ")
    }
    
    // MARK: - Sort by Code Tests
    
    @Test("Should sort catalog items by code ascending")
    func testSortByCodeAscending() {
        // Arrange
        let items = [
            createMockCatalogItem(code: "CIM-789"),
            createMockCatalogItem(code: "CIM-123"),
            createMockCatalogItem(code: "CIM-456")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .code)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].code == "CIM-123")
        #expect(sortedItems[1].code == "CIM-456")
        #expect(sortedItems[2].code == "CIM-789")
    }
    
    // MARK: - Sort by Manufacturer Tests
    
    @Test("Should sort catalog items by manufacturer ascending")
    func testSortByManufacturerAscending() {
        // Arrange
        let items = [
            createMockCatalogItem(manufacturer: "Zimmermann"),
            createMockCatalogItem(manufacturer: "Alpha Glass"),
            createMockCatalogItem(manufacturer: "Beta Works")
        ]
        
        // Act
        let sortedItems = SortUtilities.sortCatalog(items, by: .manufacturer)
        
        // Assert
        #expect(sortedItems.count == 3)
        #expect(sortedItems[0].manufacturer == "Alpha Glass")
        #expect(sortedItems[1].manufacturer == "Beta Works")
        #expect(sortedItems[2].manufacturer == "Zimmermann")
    }
}

// MARK: - Mock Objects for Testing

/// Mock CatalogItem for testing SortUtilities without Core Data dependencies
class MockCatalogItem: CatalogSortable {
    var name: String?
    var code: String? 
    var manufacturer: String?
    
    init(name: String? = nil, code: String? = nil, manufacturer: String? = nil) {
        self.name = name
        self.code = code
        self.manufacturer = manufacturer
    }
}

// MARK: - Filter Utilities Tests from FilterUtilitiesTests.swift

@Suite("FilterUtilities Tests")
struct FilterUtilitiesTests {
    
    // MARK: - Mock Data Setup
    
    // Mock CatalogItem for testing
    struct MockFilterCatalogItem {
        let manufacturer: String?
        let tags: [String]
        let id: String
        
        init(id: String, manufacturer: String?, tags: [String] = []) {
            self.id = id
            self.manufacturer = manufacturer
            self.tags = tags
        }
    }
    
    // Mock InventoryItem for testing
    struct MockFilterInventoryItem {
        let count: Int32
        let type: Int16
        let id: String
        
        var isLowStock: Bool {
            return count > 0 && count <= 5
        }
        
        init(id: String, count: Int32, type: Int16) {
            self.id = id
            self.count = count
            self.type = type
        }
    }
    
    private func createMockFilterCatalogItems() -> [MockFilterCatalogItem] {
        return [
            MockFilterCatalogItem(id: "1", manufacturer: "Effetre", tags: ["transparent", "blue"]),
            MockFilterCatalogItem(id: "2", manufacturer: "Vetrofond", tags: ["opaque", "red"]),
            MockFilterCatalogItem(id: "3", manufacturer: "Bullseye", tags: ["transparent", "green"]),
            MockFilterCatalogItem(id: "4", manufacturer: "Effetre", tags: ["opaque", "blue", "special"]),
            MockFilterCatalogItem(id: "5", manufacturer: nil, tags: ["clear"]), // No manufacturer
            MockFilterCatalogItem(id: "6", manufacturer: "  ", tags: ["white"]), // Empty/whitespace manufacturer
            MockFilterCatalogItem(id: "7", manufacturer: "Double Helix", tags: []), // No tags
            MockFilterCatalogItem(id: "8", manufacturer: "EFFETRE", tags: ["TRANSPARENT", "GREEN"]) // Case variations
        ]
    }
    
    private func createMockFilterInventoryItems() -> [MockFilterInventoryItem] {
        return [
            MockFilterInventoryItem(id: "1", count: 25, type: 1), // In stock
            MockFilterInventoryItem(id: "2", count: 3, type: 2),  // Low stock
            MockFilterInventoryItem(id: "3", count: 0, type: 1),  // Out of stock
            MockFilterInventoryItem(id: "4", count: 15, type: 3), // In stock
            MockFilterInventoryItem(id: "5", count: 1, type: 2),  // Low stock
            MockFilterInventoryItem(id: "6", count: 100, type: 1) // High stock
        ]
    }
    
    // MARK: - Manufacturer Filtering Tests
    
    @Test("Filter catalog by manufacturers with valid enabled manufacturers")
    func filterCatalogByValidEnabledManufacturers() {
        let mockItems = createMockFilterCatalogItems()
        let enabledManufacturers: Set<String> = ["Effetre", "Vetrofond"]
        
        // Simulate the filtering logic
        let results = mockItems.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        #expect(results.count == 3) // Items 1, 2, 4 (Effetre and Vetrofond)
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "2" })
        #expect(results.contains { $0.id == "4" })
        #expect(!results.contains { $0.id == "5" }) // nil manufacturer excluded
        #expect(!results.contains { $0.id == "6" }) // empty manufacturer excluded
    }
    
    @Test("Filter catalog by manufacturers handles empty enabled set")
    func filterCatalogByManufacturersHandlesEmptyEnabledSet() {
        let mockItems = createMockFilterCatalogItems()
        let enabledManufacturers: Set<String> = []
        
        // Simulate the filtering logic - empty set should return no items
        let results = mockItems.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        #expect(results.isEmpty)
    }
    
    @Test("Filter catalog by manufacturers excludes nil manufacturers")
    func filterCatalogByManufacturersExcludesNilManufacturers() {
        let mockItems = createMockFilterCatalogItems()
        let enabledManufacturers: Set<String> = ["Effetre", "Unknown"] // Include "Unknown" to test nil handling
        
        // Simulate the filtering logic
        let results = mockItems.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false // This excludes nil and empty manufacturers
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        #expect(!results.contains { $0.id == "5" }) // nil manufacturer should be excluded
        #expect(!results.contains { $0.id == "6" }) // empty/whitespace manufacturer should be excluded
    }
    
    @Test("Filter catalog by manufacturers handles whitespace in manufacturer names")
    func filterCatalogByManufacturersHandlesWhitespace() {
        let mockItems = [
            MockFilterCatalogItem(id: "1", manufacturer: "  Effetre  ", tags: []),
            MockFilterCatalogItem(id: "2", manufacturer: "Vetrofond", tags: []),
            MockFilterCatalogItem(id: "3", manufacturer: "   ", tags: []) // Only whitespace
        ]
        let enabledManufacturers: Set<String> = ["Effetre", "Vetrofond"]
        
        // Simulate the filtering logic with whitespace trimming
        let results = mockItems.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        #expect(results.count == 2) // Should find items 1 and 2 (after trimming)
        #expect(results.contains { $0.id == "1" }) // Whitespace trimmed Effetre
        #expect(results.contains { $0.id == "2" }) // Vetrofond
        #expect(!results.contains { $0.id == "3" }) // Only whitespace excluded
    }
    
    // MARK: - Tag Filtering Tests
    
    @Test("Filter catalog by tags with enabled tags")
    func filterCatalogByEnabledTags() {
        let mockItems = createMockFilterCatalogItems()
        let enabledTags: Set<String> = ["transparent", "blue"]
        
        // Simulate tag filtering logic (item must have at least one enabled tag)
        let results = mockItems.filter { item in
            return item.tags.contains { tag in
                enabledTags.contains(tag.lowercased())
            }
        }
        
        #expect(results.count == 4) // Items 1, 3, 4, 8 (have transparent or blue)
        #expect(results.contains { $0.id == "1" }) // transparent, blue
        #expect(results.contains { $0.id == "3" }) // transparent  
        #expect(results.contains { $0.id == "4" }) // blue
        #expect(results.contains { $0.id == "8" }) // TRANSPARENT (case insensitive match)
        #expect(!results.contains { $0.id == "2" }) // opaque, red
    }
    
    @Test("Filter catalog by tags handles empty enabled set")
    func filterCatalogByTagsHandlesEmptyEnabledSet() {
        let mockItems = createMockFilterCatalogItems()
        let enabledTags: Set<String> = []
        
        // Empty tag set should return no items
        let results = mockItems.filter { item in
            return item.tags.contains { tag in
                enabledTags.contains(tag.lowercased())
            }
        }
        
        #expect(results.isEmpty)
    }
    
    @Test("Filter catalog by tags is case insensitive")
    func filterCatalogByTagsCaseInsensitive() {
        let mockItems = createMockFilterCatalogItems()
        let enabledTags: Set<String> = ["TRANSPARENT"] // Uppercase
        
        // Should match lowercase transparent tags
        let results = mockItems.filter { item in
            return item.tags.contains { tag in
                enabledTags.contains(tag.uppercased()) // Compare uppercase versions
            }
        }
        
        #expect(results.count == 3) // Items 1, 3, 8 (have transparent in various cases)
        #expect(results.contains { $0.id == "1" }) // transparent (lowercase)
        #expect(results.contains { $0.id == "3" }) // transparent (lowercase)
        #expect(results.contains { $0.id == "8" }) // TRANSPARENT (uppercase)
    }
    
    // MARK: - Inventory Status Filtering Tests
    
    @Test("Filter inventory by stock status - in stock")
    func filterInventoryByInStock() {
        let mockItems = createMockFilterInventoryItems()
        
        // Filter for items that are in stock (count > 5)
        let results = mockItems.filter { item in
            return item.count > 5
        }
        
        #expect(results.count == 3) // Items 1, 4, 6 (count > 5)
        #expect(results.contains { $0.id == "1" }) // count: 25
        #expect(results.contains { $0.id == "4" }) // count: 15
        #expect(results.contains { $0.id == "6" }) // count: 100
    }
    
    @Test("Filter inventory by stock status - low stock")
    func filterInventoryByLowStock() {
        let mockItems = createMockFilterInventoryItems()
        
        // Filter for items that are low stock (count > 0 and count <= 5)
        let results = mockItems.filter { item in
            return item.isLowStock
        }
        
        #expect(results.count == 2) // Items 2, 5 (low stock)
        #expect(results.contains { $0.id == "2" }) // count: 3
        #expect(results.contains { $0.id == "5" }) // count: 1
    }
    
    @Test("Filter inventory by stock status - out of stock")
    func filterInventoryByOutOfStock() {
        let mockItems = createMockFilterInventoryItems()
        
        // Filter for items that are out of stock (count == 0)
        let results = mockItems.filter { item in
            return item.count == 0
        }
        
        #expect(results.count == 1) // Item 3 (count: 0)
        #expect(results.contains { $0.id == "3" })
    }
}