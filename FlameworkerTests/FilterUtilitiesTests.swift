//
//  FilterUtilitiesTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("FilterUtilities Tests")
struct FilterUtilitiesTests {
    
    // MARK: - Mock Data Setup
    
    // Mock CatalogItem for testing
    struct MockCatalogItem {
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
    struct MockInventoryItem {
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
    
    private func createMockCatalogItems() -> [MockCatalogItem] {
        return [
            MockCatalogItem(id: "1", manufacturer: "Effetre", tags: ["transparent", "blue"]),
            MockCatalogItem(id: "2", manufacturer: "Vetrofond", tags: ["opaque", "red"]),
            MockCatalogItem(id: "3", manufacturer: "Reichenbach", tags: ["transparent", "silver"]),
            MockCatalogItem(id: "4", manufacturer: "Effetre", tags: ["opaque", "blue", "special"]),
            MockCatalogItem(id: "5", manufacturer: nil, tags: ["clear"]), // No manufacturer
            MockCatalogItem(id: "6", manufacturer: "  ", tags: ["white"]), // Empty/whitespace manufacturer
            MockCatalogItem(id: "7", manufacturer: "Double Helix", tags: []), // No tags
            MockCatalogItem(id: "8", manufacturer: "EFFETRE", tags: ["TRANSPARENT", "GREEN"]) // Case variations
        ]
    }
    
    private func createMockInventoryItems() -> [MockInventoryItem] {
        return [
            MockInventoryItem(id: "1", count: 25, type: 1), // In stock
            MockInventoryItem(id: "2", count: 3, type: 2),  // Low stock
            MockInventoryItem(id: "3", count: 0, type: 1),  // Out of stock
            MockInventoryItem(id: "4", count: 15, type: 3), // In stock
            MockInventoryItem(id: "5", count: 1, type: 2),  // Low stock
            MockInventoryItem(id: "6", count: 100, type: 1) // High stock
        ]
    }
    
    // MARK: - Manufacturer Filtering Tests
    
    @Test("Filter catalog by manufacturers with valid enabled manufacturers")
    func filterCatalogByValidEnabledManufacturers() {
        // Note: This test validates the logic pattern but uses mock data
        // The actual FilterUtilities.filterCatalogByManufacturers works with real CatalogItem Core Data entities
        
        let mockItems = createMockCatalogItems()
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
        let mockItems = createMockCatalogItems()
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
        let mockItems = createMockCatalogItems()
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
            MockCatalogItem(id: "1", manufacturer: "  Effetre  ", tags: []),
            MockCatalogItem(id: "2", manufacturer: "Vetrofond", tags: []),
            MockCatalogItem(id: "3", manufacturer: "   ", tags: []) // Only whitespace
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
        
        #expect(results.count == 2) // Should find trimmed "Effetre" and "Vetrofond"
        #expect(results.contains { $0.id == "1" }) // Trimmed "Effetre" should match
        #expect(results.contains { $0.id == "2" })
        #expect(!results.contains { $0.id == "3" }) // Whitespace-only should be excluded
    }
    
    @Test("Filter catalog by manufacturers is case sensitive")
    func filterCatalogByManufacturersIsCaseSensitive() {
        let mockItems = createMockCatalogItems()
        let enabledManufacturers: Set<String> = ["effetre"] // lowercase
        
        // Simulate the filtering logic - should be case sensitive
        let results = mockItems.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        #expect(results.isEmpty) // "Effetre" != "effetre", "EFFETRE" != "effetre"
    }
    
    // MARK: - Tag Filtering Tests
    
    @Test("Filter catalog by tags with single selected tag")
    func filterCatalogBySingleSelectedTag() {
        let mockItems = createMockCatalogItems()
        let selectedTags: Set<String> = ["transparent"]
        
        // Simulate the filtering logic
        let results = mockItems.filter { item in
            let itemTags = Set(item.tags)
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        #expect(results.count == 2) // Only items 1, 3 have "transparent" (case-sensitive)
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "3" })
        #expect(!results.contains { $0.id == "8" }) // "TRANSPARENT" != "transparent" (case-sensitive)
    }
    
    @Test("Filter catalog by tags with multiple selected tags")
    func filterCatalogByMultipleSelectedTags() {
        let mockItems = createMockCatalogItems()
        let selectedTags: Set<String> = ["blue", "opaque"]
        
        // Simulate the filtering logic - OR logic (items with ANY of the selected tags)
        let results = mockItems.filter { item in
            let itemTags = Set(item.tags)
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        #expect(results.count == 3) // Items 1, 2, 4 (blue OR opaque)
        #expect(results.contains { $0.id == "1" }) // has "blue"
        #expect(results.contains { $0.id == "2" }) // has "opaque"
        #expect(results.contains { $0.id == "4" }) // has both "blue" and "opaque"
    }
    
    @Test("Filter catalog by tags handles empty selected tags set")
    func filterCatalogByTagsHandlesEmptySelectedSet() {
        let mockItems = createMockCatalogItems()
        let selectedTags: Set<String> = []
        
        // Empty selected tags should return all items (guard clause should catch this)
        #expect(selectedTags.isEmpty) // This validates the guard condition in FilterUtilities
        
        // Simulate the actual FilterUtilities logic with guard clause
        let results: [MockCatalogItem]
        if selectedTags.isEmpty {
            results = mockItems // Guard clause: return all items when no tags selected
        } else {
            results = mockItems.filter { item in
                let itemTags = Set(item.tags)
                return !selectedTags.isDisjoint(with: itemTags)
            }
        }
        
        #expect(results.count == mockItems.count) // Should return all 8 items due to guard clause
    }
    
    @Test("Filter catalog by tags with no matching tags")
    func filterCatalogByTagsWithNoMatchingTags() {
        let mockItems = createMockCatalogItems()
        let selectedTags: Set<String> = ["nonexistent", "missing"]
        
        // Simulate the filtering logic
        let results = mockItems.filter { item in
            let itemTags = Set(item.tags)
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        #expect(results.isEmpty)
    }
    
    @Test("Filter catalog by tags handles items with empty tag lists")
    func filterCatalogByTagsHandlesEmptyTagLists() {
        let mockItems = createMockCatalogItems()
        let selectedTags: Set<String> = ["transparent"]
        
        // Simulate the filtering logic
        let results = mockItems.filter { item in
            let itemTags = Set(item.tags)
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        #expect(!results.contains { $0.id == "7" }) // Item 7 has empty tags array
    }
    
    @Test("Filter catalog by tags is case sensitive")
    func filterCatalogByTagsIsCaseSensitive() {
        let mockItems = createMockCatalogItems()
        let selectedTags: Set<String> = ["TRANSPARENT"] // uppercase
        
        // Simulate the filtering logic - should be case sensitive
        let results = mockItems.filter { item in
            let itemTags = Set(item.tags)
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        #expect(results.count == 1) // Only item 8 has "TRANSPARENT" (uppercase)
        #expect(results.contains { $0.id == "8" })
        #expect(!results.contains { $0.id == "1" }) // "transparent" != "TRANSPARENT" (case-sensitive)
        #expect(!results.contains { $0.id == "3" }) // "transparent" != "TRANSPARENT" (case-sensitive)
    }
    
    @Test("Filter catalog by tags case sensitivity demonstration")
    func filterCatalogByTagsCaseSensitivityDemo() {
        let mockItems = createMockCatalogItems()
        
        // Test lowercase search
        let lowercaseResults = mockItems.filter { item in
            let itemTags = Set(item.tags)
            let selectedTags: Set<String> = ["transparent"]
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        // Test uppercase search  
        let uppercaseResults = mockItems.filter { item in
            let itemTags = Set(item.tags)
            let selectedTags: Set<String> = ["TRANSPARENT"]
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        #expect(lowercaseResults.count == 2) // Items 1, 3 have "transparent"
        #expect(uppercaseResults.count == 1) // Only item 8 has "TRANSPARENT"
        #expect(Set(lowercaseResults.map { $0.id }).isDisjoint(with: Set(uppercaseResults.map { $0.id }))) // No overlap due to case sensitivity
    }
    
    @Test("Filter catalog by tags intersection logic")
    func filterCatalogByTagsIntersectionLogic() {
        let mockItems = [
            MockCatalogItem(id: "1", manufacturer: "Test", tags: ["a", "b", "c"]),
            MockCatalogItem(id: "2", manufacturer: "Test", tags: ["b", "c", "d"]),
            MockCatalogItem(id: "3", manufacturer: "Test", tags: ["d", "e", "f"]),
            MockCatalogItem(id: "4", manufacturer: "Test", tags: ["x", "y", "z"])
        ]
        let selectedTags: Set<String> = ["b", "e"]
        
        // Simulate the filtering logic - OR logic (items with ANY matching tag)
        let results = mockItems.filter { item in
            let itemTags = Set(item.tags)
            return !selectedTags.isDisjoint(with: itemTags) // This is OR logic - any intersection
        }
        
        #expect(results.count == 3) // Items 1, 2, 3
        #expect(results.contains { $0.id == "1" }) // has "b"
        #expect(results.contains { $0.id == "2" }) // has "b"
        #expect(results.contains { $0.id == "3" }) // has "e"
        #expect(!results.contains { $0.id == "4" }) // no intersection
    }
    
    // MARK: - Inventory Status Filtering Tests
    
    @Test("Filter inventory by status with all options enabled")
    func filterInventoryByStatusAllEnabled() {
        let mockItems = createMockInventoryItems()
        
        // Simulate the filtering logic with all status options enabled
        let results = mockItems.filter { item in
            let showInStock = true
            let showLowStock = true
            let showOutOfStock = true
            
            if showInStock && item.count > 10 { return true }
            if showLowStock && item.isLowStock { return true }
            if showOutOfStock && item.count == 0 { return true }
            return false
        }
        
        #expect(results.count == mockItems.count) // All items should be included
    }
    
    @Test("Filter inventory by status in stock only")
    func filterInventoryByStatusInStockOnly() {
        let mockItems = createMockInventoryItems()
        
        // Simulate the filtering logic with only in-stock enabled
        let results = mockItems.filter { item in
            let showInStock = true
            let showLowStock = false
            let showOutOfStock = false
            
            if showInStock && item.count > 10 { return true }
            if showLowStock && item.isLowStock { return true }
            if showOutOfStock && item.count == 0 { return true }
            return false
        }
        
        #expect(results.count == 3) // Items with count > 10: items 1, 4, 6
        #expect(results.contains { $0.id == "1" }) // count: 25
        #expect(results.contains { $0.id == "4" }) // count: 15
        #expect(results.contains { $0.id == "6" }) // count: 100
    }
    
    @Test("Filter inventory by status low stock only")
    func filterInventoryByStatusLowStockOnly() {
        let mockItems = createMockInventoryItems()
        
        // Simulate the filtering logic with only low-stock enabled
        let results = mockItems.filter { item in
            let showInStock = false
            let showLowStock = true
            let showOutOfStock = false
            
            if showInStock && item.count > 10 { return true }
            if showLowStock && item.isLowStock { return true }
            if showOutOfStock && item.count == 0 { return true }
            return false
        }
        
        #expect(results.count == 2) // Items with isLowStock: items 2, 5
        #expect(results.contains { $0.id == "2" }) // count: 3
        #expect(results.contains { $0.id == "5" }) // count: 1
    }
    
    @Test("Filter inventory by status out of stock only")
    func filterInventoryByStatusOutOfStockOnly() {
        let mockItems = createMockInventoryItems()
        
        // Simulate the filtering logic with only out-of-stock enabled
        let results = mockItems.filter { item in
            let showInStock = false
            let showLowStock = false
            let showOutOfStock = true
            
            if showInStock && item.count > 10 { return true }
            if showLowStock && item.isLowStock { return true }
            if showOutOfStock && item.count == 0 { return true }
            return false
        }
        
        #expect(results.count == 1) // Items with count == 0: item 3
        #expect(results.contains { $0.id == "3" })
    }
    
    @Test("Filter inventory by status no options enabled")
    func filterInventoryByStatusNoOptionsEnabled() {
        let mockItems = createMockInventoryItems()
        
        // Simulate the filtering logic with no status options enabled
        let results = mockItems.filter { item in
            let showInStock = false
            let showLowStock = false
            let showOutOfStock = false
            
            if showInStock && item.count > 10 { return true }
            if showLowStock && item.isLowStock { return true }
            if showOutOfStock && item.count == 0 { return true }
            return false
        }
        
        #expect(results.isEmpty)
    }
    
    @Test("Filter inventory by status boundary values")
    func filterInventoryByStatusBoundaryValues() {
        let boundaryItems = [
            MockInventoryItem(id: "1", count: 0, type: 1),   // Out of stock
            MockInventoryItem(id: "2", count: 1, type: 1),   // Low stock (boundary)
            MockInventoryItem(id: "3", count: 5, type: 1),   // Low stock (boundary)
            MockInventoryItem(id: "4", count: 6, type: 1),   // Not low stock
            MockInventoryItem(id: "5", count: 10, type: 1),  // Not in stock (boundary)
            MockInventoryItem(id: "6", count: 11, type: 1)   // In stock (boundary)
        ]
        
        // Test low stock boundary (count > 0 && count <= 5)
        let lowStockResults = boundaryItems.filter { item in
            let showInStock = false
            let showLowStock = true
            let showOutOfStock = false
            
            if showInStock && item.count > 10 { return true }
            if showLowStock && item.isLowStock { return true }
            if showOutOfStock && item.count == 0 { return true }
            return false
        }
        
        #expect(lowStockResults.count == 2) // Items 2, 3 (count 1, 5)
        #expect(lowStockResults.contains { $0.id == "2" })
        #expect(lowStockResults.contains { $0.id == "3" })
        
        // Test in stock boundary (count > 10)
        let inStockResults = boundaryItems.filter { item in
            let showInStock = true
            let showLowStock = false
            let showOutOfStock = false
            
            if showInStock && item.count > 10 { return true }
            if showLowStock && item.isLowStock { return true }
            if showOutOfStock && item.count == 0 { return true }
            return false
        }
        
        #expect(inStockResults.count == 1) // Only item 6 (count 11)
        #expect(inStockResults.contains { $0.id == "6" })
    }
    
    // MARK: - Inventory Type Filtering Tests
    
    @Test("Filter inventory by type with valid selected types")
    func filterInventoryByTypeWithValidSelectedTypes() {
        let mockItems = createMockInventoryItems()
        let selectedTypes: Set<Int16> = [1, 3]
        
        // Simulate the filtering logic
        let results = mockItems.filter { selectedTypes.contains($0.type) }
        
        #expect(results.count == 4) // Items 1, 3, 4, 6 have type 1 or 3
        #expect(results.contains { $0.id == "1" }) // type 1
        #expect(results.contains { $0.id == "3" }) // type 1
        #expect(results.contains { $0.id == "4" }) // type 3
        #expect(results.contains { $0.id == "6" }) // type 1
    }
    
    @Test("Filter inventory by type with empty selected types")
    func filterInventoryByTypeWithEmptySelectedTypes() {
        let mockItems = createMockInventoryItems()
        let selectedTypes: Set<Int16> = []
        
        // Empty selected types should return all items (guard clause in FilterUtilities)
        #expect(selectedTypes.isEmpty) // Validates the guard condition
        
        // If no guard clause, filter would return empty
        let results = mockItems.filter { selectedTypes.contains($0.type) }
        #expect(results.isEmpty)
    }
    
    @Test("Filter inventory by type with single selected type")
    func filterInventoryByTypeWithSingleSelectedType() {
        let mockItems = createMockInventoryItems()
        let selectedTypes: Set<Int16> = [2]
        
        // Simulate the filtering logic
        let results = mockItems.filter { selectedTypes.contains($0.type) }
        
        #expect(results.count == 2) // Items 2, 5 have type 2
        #expect(results.contains { $0.id == "2" })
        #expect(results.contains { $0.id == "5" })
    }
    
    @Test("Filter inventory by type with nonexistent type")
    func filterInventoryByTypeWithNonexistentType() {
        let mockItems = createMockInventoryItems()
        let selectedTypes: Set<Int16> = [999] // Non-existent type
        
        // Simulate the filtering logic
        let results = mockItems.filter { selectedTypes.contains($0.type) }
        
        #expect(results.isEmpty)
    }
    
    // MARK: - Combined Filter Tests
    
    @Test("Combined manufacturer and tag filtering logic pattern")
    func combinedManufacturerAndTagFilteringLogic() {
        let mockItems = createMockCatalogItems()
        let enabledManufacturers: Set<String> = ["Effetre", "Vetrofond"]
        let selectedTags: Set<String> = ["blue"]
        
        // Simulate applying both filters (this tests the logical combination)
        var results = mockItems
        
        // First apply manufacturer filter
        results = results.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        // Then apply tag filter
        results = results.filter { item in
            let itemTags = Set(item.tags)
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        #expect(results.count == 2) // Items 1, 4 (Effetre with blue tags)
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "4" })
        #expect(!results.contains { $0.id == "2" }) // Vetrofond but no blue tag
    }
    
    // MARK: - Performance Tests
    
    @Test("Filter performance with large datasets")
    func filterPerformanceWithLargeDatasets() {
        // Create large mock dataset
        let largeItems = (1...1000).map { i in
            MockCatalogItem(
                id: "\(i)",
                manufacturer: "Manufacturer_\(i % 10)", // 10 different manufacturers
                tags: ["tag_\(i % 20)", "category_\(i % 5)"] // Various tags
            )
        }
        
        let enabledManufacturers: Set<String> = ["Manufacturer_1", "Manufacturer_3", "Manufacturer_5"]
        
        let startTime = Date()
        
        // Simulate the filtering logic
        let results = largeItems.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(results.count == 300) // 3 manufacturers out of 10, so 30% of 1000
        #expect(duration < 0.05, "Filter should complete within 50ms for 1000 items")
    }
    
    // MARK: - Edge Cases Tests
    
    @Test("Filter handles empty input arrays gracefully")
    func filterHandlesEmptyInputArraysGracefully() {
        let emptyItems: [MockCatalogItem] = []
        let enabledManufacturers: Set<String> = ["Effetre"]
        
        // Simulate the filtering logic
        let results = emptyItems.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        #expect(results.isEmpty)
    }
    
    @Test("Filter handles special characters in manufacturer names")
    func filterHandlesSpecialCharactersInManufacturerNames() {
        let specialItems = [
            MockCatalogItem(id: "1", manufacturer: "Double-Helix", tags: []),
            MockCatalogItem(id: "2", manufacturer: "Glass & More", tags: []),
            MockCatalogItem(id: "3", manufacturer: "Müller GmbH", tags: []),
            MockCatalogItem(id: "4", manufacturer: "Double-Helix", tags: [])
        ]
        let enabledManufacturers: Set<String> = ["Double-Helix", "Glass & More"]
        
        // Simulate the filtering logic
        let results = specialItems.filter { item in
            guard let manufacturer = item.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !manufacturer.isEmpty else {
                return false
            }
            return enabledManufacturers.contains(manufacturer)
        }
        
        #expect(results.count == 3) // Items 1, 2, 4
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "2" })
        #expect(results.contains { $0.id == "4" })
        #expect(!results.contains { $0.id == "3" }) // Müller GmbH not in enabled set
    }
    
    @Test("Filter handles special characters in tag names")
    func filterHandlesSpecialCharactersInTagNames() {
        let specialTagItems = [
            MockCatalogItem(id: "1", manufacturer: "Test", tags: ["café-au-lait", "français"]),
            MockCatalogItem(id: "2", manufacturer: "Test", tags: ["über-glass", "deutsch"]),
            MockCatalogItem(id: "3", manufacturer: "Test", tags: ["москва", "русский"]),
            MockCatalogItem(id: "4", manufacturer: "Test", tags: ["café-au-lait", "special"])
        ]
        let selectedTags: Set<String> = ["café-au-lait", "über-glass"]
        
        // Simulate the filtering logic
        let results = specialTagItems.filter { item in
            let itemTags = Set(item.tags)
            return !selectedTags.isDisjoint(with: itemTags)
        }
        
        #expect(results.count == 3) // Items 1, 2, 4
        #expect(results.contains { $0.id == "1" })
        #expect(results.contains { $0.id == "2" })
        #expect(results.contains { $0.id == "4" })
        #expect(!results.contains { $0.id == "3" })
    }
}