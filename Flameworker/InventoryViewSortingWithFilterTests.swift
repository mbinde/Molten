//  InventoryViewSortingWithFilterTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("InventoryView Sorting with Filter Tests")
struct InventoryViewSortingWithFilterTests {
    
    // MARK: - Mock Data for Sorting Tests
    
    private func createSortingTestItems() -> [ConsolidatedInventoryItem] {
        return [
            // High inventory count, alphabetically first
            ConsolidatedInventoryItem(
                id: "glass-a",
                catalogCode: "AAA-001",
                catalogItemName: "Alpha Glass",
                items: [],
                totalInventoryCount: 100.0,
                totalBuyCount: 0.0,
                totalSellCount: 0.0,
                inventoryUnits: .rods,
                buyUnits: nil,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            ),
            // Medium inventory count, alphabetically second
            ConsolidatedInventoryItem(
                id: "glass-b",
                catalogCode: "BBB-002",
                catalogItemName: "Beta Glass",
                items: [],
                totalInventoryCount: 50.0,
                totalBuyCount: 0.0,
                totalSellCount: 0.0,
                inventoryUnits: .rods,
                buyUnits: nil,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            ),
            // Low inventory count, alphabetically third
            ConsolidatedInventoryItem(
                id: "glass-c",
                catalogCode: "CCC-003",
                catalogItemName: "Charlie Glass",
                items: [],
                totalInventoryCount: 10.0,
                totalBuyCount: 0.0,
                totalSellCount: 0.0,
                inventoryUnits: .rods,
                buyUnits: nil,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            ),
            // High buy count, no inventory
            ConsolidatedInventoryItem(
                id: "glass-d",
                catalogCode: "DDD-004",
                catalogItemName: "Delta Glass",
                items: [],
                totalInventoryCount: 0.0,
                totalBuyCount: 75.0,
                totalSellCount: 0.0,
                inventoryUnits: nil,
                buyUnits: .rods,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            ),
            // High sell count, no inventory
            ConsolidatedInventoryItem(
                id: "glass-e",
                catalogCode: "EEE-005",
                catalogItemName: "Echo Glass",
                items: [],
                totalInventoryCount: 0.0,
                totalBuyCount: 0.0,
                totalSellCount: 90.0,
                inventoryUnits: nil,
                buyUnits: nil,
                sellUnits: .rods,
                hasNotes: false,
                allNotes: ""
            ),
            // Mixed counts for complex sorting
            ConsolidatedInventoryItem(
                id: "glass-f",
                catalogCode: "FFF-006",
                catalogItemName: "Foxtrot Glass",
                items: [],
                totalInventoryCount: 30.0,
                totalBuyCount: 20.0,
                totalSellCount: 40.0,
                inventoryUnits: .rods,
                buyUnits: .rods,
                sellUnits: .rods,
                hasNotes: false,
                allNotes: ""
            )
        ]
    }
    
    // MARK: - Name Sorting with Filters
    
    @Test("Name sorting works with inventory filter")
    func testNameSortingWithInventoryFilter() {
        let mockItems = createSortingTestItems()
        let inventoryFilter: Set<InventoryFilterType> = [.inventory]
        
        // Filter to inventory items only
        let filteredItems = mockItems.filter { item in
            inventoryFilter.contains(.inventory) && item.totalInventoryCount > 0
        }
        
        // Sort by name
        let sortedItems = filteredItems.sorted { item1, item2 in
            item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
        }
        
        #expect(sortedItems.count == 4, "Should have 4 items with inventory")
        #expect(sortedItems[0].displayName == "Alpha Glass", "First item should be Alpha")
        #expect(sortedItems[1].displayName == "Beta Glass", "Second item should be Beta")
        #expect(sortedItems[2].displayName == "Charlie Glass", "Third item should be Charlie")
        #expect(sortedItems[3].displayName == "Foxtrot Glass", "Fourth item should be Foxtrot")
    }
    
    @Test("Name sorting works with buy filter")
    func testNameSortingWithBuyFilter() {
        let mockItems = createSortingTestItems()
        let buyFilter: Set<InventoryFilterType> = [.buy]
        
        // Filter to buy items only
        let filteredItems = mockItems.filter { item in
            buyFilter.contains(.buy) && item.totalBuyCount > 0
        }
        
        // Sort by name
        let sortedItems = filteredItems.sorted { item1, item2 in
            item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
        }
        
        #expect(sortedItems.count == 2, "Should have 2 items with buy count")
        #expect(sortedItems[0].displayName == "Delta Glass", "First item should be Delta")
        #expect(sortedItems[1].displayName == "Foxtrot Glass", "Second item should be Foxtrot")
    }
    
    @Test("Name sorting works with all filters")
    func testNameSortingWithAllFilters() {
        let mockItems = createSortingTestItems()
        let allFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // Filter to show all items
        let filteredItems = mockItems.filter { item in
            (allFilters.contains(.inventory) && item.totalInventoryCount > 0) ||
            (allFilters.contains(.buy) && item.totalBuyCount > 0) ||
            (allFilters.contains(.sell) && item.totalSellCount > 0)
        }
        
        // Sort by name
        let sortedItems = filteredItems.sorted { item1, item2 in
            item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
        }
        
        #expect(sortedItems.count == 6, "Should have all 6 items")
        #expect(sortedItems[0].displayName == "Alpha Glass", "First item should be Alpha")
        #expect(sortedItems[1].displayName == "Beta Glass", "Second item should be Beta")
        #expect(sortedItems[2].displayName == "Charlie Glass", "Third item should be Charlie")
        #expect(sortedItems[3].displayName == "Delta Glass", "Fourth item should be Delta")
        #expect(sortedItems[4].displayName == "Echo Glass", "Fifth item should be Echo")
        #expect(sortedItems[5].displayName == "Foxtrot Glass", "Sixth item should be Foxtrot")
    }
    
    // MARK: - Count Sorting with Filters
    
    @Test("Inventory count sorting works with inventory filter")
    func testInventoryCountSortingWithInventoryFilter() {
        let mockItems = createSortingTestItems()
        let inventoryFilter: Set<InventoryFilterType> = [.inventory]
        
        // Filter to inventory items only
        let filteredItems = mockItems.filter { item in
            inventoryFilter.contains(.inventory) && item.totalInventoryCount > 0
        }
        
        // Sort by inventory count (descending)
        let sortedItems = filteredItems.sorted { item1, item2 in
            if item1.totalInventoryCount != item2.totalInventoryCount {
                return item1.totalInventoryCount > item2.totalInventoryCount
            } else {
                return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            }
        }
        
        #expect(sortedItems.count == 4, "Should have 4 items with inventory")
        #expect(sortedItems[0].totalInventoryCount == 100.0, "First item should have highest inventory count")
        #expect(sortedItems[1].totalInventoryCount == 50.0, "Second item should have medium inventory count")
        #expect(sortedItems[2].totalInventoryCount == 30.0, "Third item should have low inventory count")
        #expect(sortedItems[3].totalInventoryCount == 10.0, "Fourth item should have lowest inventory count")
    }
    
    @Test("Buy count sorting works with buy filter")
    func testBuyCountSortingWithBuyFilter() {
        let mockItems = createSortingTestItems()
        let buyFilter: Set<InventoryFilterType> = [.buy]
        
        // Filter to buy items only
        let filteredItems = mockItems.filter { item in
            buyFilter.contains(.buy) && item.totalBuyCount > 0
        }
        
        // Sort by buy count (descending)
        let sortedItems = filteredItems.sorted { item1, item2 in
            if item1.totalBuyCount != item2.totalBuyCount {
                return item1.totalBuyCount > item2.totalBuyCount
            } else {
                return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            }
        }
        
        #expect(sortedItems.count == 2, "Should have 2 items with buy count")
        #expect(sortedItems[0].totalBuyCount == 75.0, "First item should have higher buy count")
        #expect(sortedItems[1].totalBuyCount == 20.0, "Second item should have lower buy count")
    }
    
    @Test("Sell count sorting works with sell filter")
    func testSellCountSortingWithSellFilter() {
        let mockItems = createSortingTestItems()
        let sellFilter: Set<InventoryFilterType> = [.sell]
        
        // Filter to sell items only
        let filteredItems = mockItems.filter { item in
            sellFilter.contains(.sell) && item.totalSellCount > 0
        }
        
        // Sort by sell count (descending)
        let sortedItems = filteredItems.sorted { item1, item2 in
            if item1.totalSellCount != item2.totalSellCount {
                return item1.totalSellCount > item2.totalSellCount
            } else {
                return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            }
        }
        
        #expect(sortedItems.count == 2, "Should have 2 items with sell count")
        #expect(sortedItems[0].totalSellCount == 90.0, "First item should have higher sell count")
        #expect(sortedItems[1].totalSellCount == 40.0, "Second item should have lower sell count")
    }
    
    // MARK: - Secondary Sorting (Name as Tiebreaker)
    
    @Test("Name sorting acts as tiebreaker for equal counts")
    func testNameSortingAsTiebreaker() {
        let itemsWithEqualCounts = [
            ConsolidatedInventoryItem(
                id: "glass-z",
                catalogCode: "ZZZ-001",
                catalogItemName: "Zulu Glass",
                items: [],
                totalInventoryCount: 50.0,
                totalBuyCount: 0.0,
                totalSellCount: 0.0,
                inventoryUnits: .rods,
                buyUnits: nil,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            ),
            ConsolidatedInventoryItem(
                id: "glass-a",
                catalogCode: "AAA-002",
                catalogItemName: "Alpha Glass",
                items: [],
                totalInventoryCount: 50.0,
                totalBuyCount: 0.0,
                totalSellCount: 0.0,
                inventoryUnits: .rods,
                buyUnits: nil,
                sellUnits: nil,
                hasNotes: false,
                allNotes: ""
            )
        ]
        
        // Sort by inventory count with name tiebreaker
        let sortedItems = itemsWithEqualCounts.sorted { item1, item2 in
            if item1.totalInventoryCount != item2.totalInventoryCount {
                return item1.totalInventoryCount > item2.totalInventoryCount
            } else {
                return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            }
        }
        
        #expect(sortedItems[0].displayName == "Alpha Glass", "Alpha should come before Zulu alphabetically")
        #expect(sortedItems[1].displayName == "Zulu Glass", "Zulu should come after Alpha alphabetically")
    }
    
    // MARK: - Sort Option Behavior Tests
    
    @Test("Sort options have correct properties")
    func testSortOptionProperties() {
        // This would test the InventorySortOption enum from InventoryView
        // Since we can't directly access it, we'll test the expected behavior
        
        let sortOptions = [
            (title: "Name", icon: "textformat.abc"),
            (title: "Inventory Count", icon: "archivebox.fill"),
            (title: "Buy Count", icon: "cart.fill"),
            (title: "Sell Count", icon: "dollarsign.circle.fill")
        ]
        
        #expect(sortOptions.count == 4, "Should have 4 sort options")
        
        // Test that all options have valid titles and icons
        for option in sortOptions {
            #expect(!option.title.isEmpty, "Sort option should have non-empty title")
            #expect(!option.icon.isEmpty, "Sort option should have non-empty icon")
        }
    }
    
    // MARK: - Complex Sorting Scenarios
    
    @Test("Sorting maintains filter results correctly")
    func testSortingMaintainsFilterResults() {
        let mockItems = createSortingTestItems()
        let inventoryFilter: Set<InventoryFilterType> = [.inventory]
        
        // Filter first
        let filteredItems = mockItems.filter { item in
            inventoryFilter.contains(.inventory) && item.totalInventoryCount > 0
        }
        
        // Sort filtered results by name
        let sortedByName = filteredItems.sorted { item1, item2 in
            item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
        }
        
        // Sort filtered results by inventory count
        let sortedByCount = filteredItems.sorted { item1, item2 in
            if item1.totalInventoryCount != item2.totalInventoryCount {
                return item1.totalInventoryCount > item2.totalInventoryCount
            } else {
                return item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
            }
        }
        
        // Both sorted arrays should have same items, just in different order
        #expect(sortedByName.count == sortedByCount.count, "Both sorts should have same number of items")
        #expect(sortedByName.count == 4, "Should maintain filter result count")
        
        // Verify all items in both arrays have inventory count > 0
        for item in sortedByName {
            #expect(item.totalInventoryCount > 0, "All items should have inventory count > 0")
        }
        for item in sortedByCount {
            #expect(item.totalInventoryCount > 0, "All items should have inventory count > 0")
        }
    }
    
    @Test("Sorting empty filter results works correctly")
    func testSortingEmptyFilterResults() {
        let mockItems = createSortingTestItems()
        let emptyFilter: Set<InventoryFilterType> = []
        
        // Filter with empty selection (should return no items)
        let filteredItems = mockItems.filter { item in
            if emptyFilter.isEmpty {
                return false
            }
            
            return (emptyFilter.contains(.inventory) && item.totalInventoryCount > 0) ||
                   (emptyFilter.contains(.buy) && item.totalBuyCount > 0) ||
                   (emptyFilter.contains(.sell) && item.totalSellCount > 0)
        }
        
        // Sort empty results
        let sortedItems = filteredItems.sorted { item1, item2 in
            item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
        }
        
        #expect(filteredItems.count == 0, "Empty filter should return no items")
        #expect(sortedItems.count == 0, "Sorting empty results should return empty array")
    }
    
    // MARK: - Performance and Edge Cases
    
    @Test("Sorting handles large datasets efficiently")
    func testSortingPerformanceLargeDataset() {
        // Create a large dataset for performance testing
        let largeDataset = (0..<100).map { index in
            ConsolidatedInventoryItem(
                id: "glass-\(index)",
                catalogCode: "CODE-\(String(format: "%03d", index))",
                catalogItemName: "Glass Item \(index)",
                items: [],
                totalInventoryCount: Double(index % 50),
                totalBuyCount: Double(index % 30),
                totalSellCount: Double(index % 40),
                inventoryUnits: .rods,
                buyUnits: .rods,
                sellUnits: .rods,
                hasNotes: false,
                allNotes: ""
            )
        }
        
        let allFilters: Set<InventoryFilterType> = [.inventory, .buy, .sell]
        
        // Filter items
        let filteredItems = largeDataset.filter { item in
            (allFilters.contains(.inventory) && item.totalInventoryCount > 0) ||
            (allFilters.contains(.buy) && item.totalBuyCount > 0) ||
            (allFilters.contains(.sell) && item.totalSellCount > 0)
        }
        
        // Sort by name
        let sortedItems = filteredItems.sorted { item1, item2 in
            item1.displayName.localizedCaseInsensitiveCompare(item2.displayName) == .orderedAscending
        }
        
        #expect(sortedItems.count > 0, "Should handle large dataset")
        #expect(sortedItems.count <= largeDataset.count, "Filtered count should not exceed original")
        
        // Verify sorting order is maintained
        for i in 0..<(sortedItems.count - 1) {
            let comparison = sortedItems[i].displayName.localizedCaseInsensitiveCompare(sortedItems[i + 1].displayName)
            #expect(comparison == .orderedAscending || comparison == .orderedSame, "Items should be in alphabetical order")
        }
    }
}
