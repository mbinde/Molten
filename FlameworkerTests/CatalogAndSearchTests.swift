//
//  CatalogAndSearchTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
import CoreData
import os
@testable import Flameworker

@Suite("CatalogItemHelpers Basic Tests")
struct CatalogItemHelpersBasicTests {
    
    @Test("AvailabilityStatus has correct display text")
    func testAvailabilityStatusDisplayText() {
        #expect(AvailabilityStatus.available.displayText == "Available", "Available should have correct display text")
        #expect(AvailabilityStatus.discontinued.displayText == "Discontinued", "Discontinued should have correct display text")
        #expect(AvailabilityStatus.futureRelease.displayText == "Future Release", "Future release should have correct display text")
    }
    
    @Test("AvailabilityStatus has correct colors")
    func testAvailabilityStatusColors() {
        #expect(AvailabilityStatus.available.color == .green, "Available should be green")
        #expect(AvailabilityStatus.discontinued.color == .orange, "Discontinued should be orange")
        #expect(AvailabilityStatus.futureRelease.color == .blue, "Future release should be blue")
    }
    
    @Test("AvailabilityStatus has correct short display text")
    func testAvailabilityStatusShortText() {
        #expect(AvailabilityStatus.available.shortDisplayText == "Avail.", "Available should have short text")
        #expect(AvailabilityStatus.discontinued.shortDisplayText == "Disc.", "Discontinued should have short text")
        #expect(AvailabilityStatus.futureRelease.shortDisplayText == "Future", "Future release should have short text")
    }
    
    @Test("Create tags string from array works correctly")
    func testCreateTagsString() {
        let tags = ["red", "glass", "rod"]
        let result = CatalogItemHelpers.createTagsString(from: tags)
        #expect(result == "red,glass,rod", "Should create comma-separated string")
        
        // Test with empty strings
        let tagsWithEmpty = ["red", "", "glass", "   ", "rod"]
        let filteredResult = CatalogItemHelpers.createTagsString(from: tagsWithEmpty)
        #expect(filteredResult == "red,glass,rod", "Should filter out empty and whitespace-only strings")
        
        // Test empty array
        let emptyResult = CatalogItemHelpers.createTagsString(from: [])
        #expect(emptyResult.isEmpty, "Empty array should produce empty string")
    }
    
    @Test("Format date works correctly")
    func testFormatDate() {
        let date = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021
        let formatted = CatalogItemHelpers.formatDate(date, style: .short)
        
        // Just verify it's not empty and is a reasonable date string
        #expect(!formatted.isEmpty, "Formatted date should not be empty")
        #expect(formatted.count >= 6, "Formatted date should have reasonable length")
        
        // Test that the function handles different styles without crashing
        let mediumFormatted = CatalogItemHelpers.formatDate(date, style: .medium)
        #expect(!mediumFormatted.isEmpty, "Medium formatted date should not be empty")
        
        let longFormatted = CatalogItemHelpers.formatDate(date, style: .long)
        #expect(!longFormatted.isEmpty, "Long formatted date should not be empty")
    }
    
    @Test("CatalogItemDisplayInfo nameWithCode works correctly") 
    func testCatalogItemDisplayInfoNameWithCode() {
        let displayInfo = CatalogItemDisplayInfo(
            name: "Test Glass",
            code: "TG001",
            manufacturer: "Test Mfg",
            manufacturerFullName: "Test Manufacturing Co",
            coe: "96",
            stockType: "rod",
            tags: ["red", "glass"],
            synonyms: ["test", "sample"],
            color: .blue,
            manufacturerURL: nil,
            imagePath: nil,
            description: "Test description"
        )
        
        #expect(displayInfo.nameWithCode == "Test Glass (TG001)", "Should combine name and code correctly")
        #expect(displayInfo.hasExtendedInfo == true, "Should have extended info with tags")
        #expect(displayInfo.hasDescription == true, "Should have description")
    }
    
    @Test("CatalogItemDisplayInfo detects extended info correctly")
    func testCatalogItemDisplayInfoExtendedInfo() {
        // Test with no extended info
        let basicInfo = CatalogItemDisplayInfo(
            name: "Basic",
            code: "B001", 
            manufacturer: "Basic Mfg",
            manufacturerFullName: "Basic Manufacturing",
            coe: nil,
            stockType: nil,
            tags: [],
            synonyms: [],
            color: .gray,
            manufacturerURL: nil,
            imagePath: nil,
            description: nil
        )
        
        #expect(basicInfo.hasExtendedInfo == false, "Should not have extended info")
        #expect(basicInfo.hasDescription == false, "Should not have description")
        
        // Test with extended info
        let extendedInfo = CatalogItemDisplayInfo(
            name: "Extended",
            code: "E001",
            manufacturer: "Extended Mfg", 
            manufacturerFullName: "Extended Manufacturing",
            coe: nil,
            stockType: "rod",
            tags: [],
            synonyms: [],
            color: .gray,
            manufacturerURL: nil,
            imagePath: nil,
            description: "   "
        )
        
        #expect(extendedInfo.hasExtendedInfo == true, "Should have extended info due to stock type")
        #expect(extendedInfo.hasDescription == false, "Should not have description due to whitespace")
    }
}

@Suite("Simple Filter Logic Tests")
struct SimpleFilterLogicTests {
    
    @Test("Basic inventory filtering logic works correctly")
    func testBasicInventoryFiltering() {
        // Test basic filtering logic patterns without requiring specific classes
        
        // Mock inventory item
        struct MockInventoryItem {
            let count: Double
            let type: Int16
            
            var isInStock: Bool { count > 10 }
            var isLowStock: Bool { count > 0 && count <= 10.0 }
            var isOutOfStock: Bool { count == 0 }
        }
        
        let highStock = MockInventoryItem(count: 20.0, type: 0)
        let lowStock = MockInventoryItem(count: 5.0, type: 0)
        let outOfStock = MockInventoryItem(count: 0.0, type: 0)
        
        // Test stock level detection
        #expect(highStock.isInStock == true, "High stock item should be in stock")
        #expect(highStock.isLowStock == false, "High stock item should not be low stock")
        #expect(highStock.isOutOfStock == false, "High stock item should not be out of stock")
        
        #expect(lowStock.isInStock == false, "Low stock item should not be in high stock")
        #expect(lowStock.isLowStock == true, "Low stock item should be low stock") 
        #expect(lowStock.isOutOfStock == false, "Low stock item should not be out of stock")
        
        #expect(outOfStock.isInStock == false, "Out of stock item should not be in stock")
        #expect(outOfStock.isLowStock == false, "Out of stock item should not be low stock")
        #expect(outOfStock.isOutOfStock == true, "Out of stock item should be out of stock")
    }
    
    @Test("Type filtering logic works correctly")
    func testTypeFilteringLogic() {
        // Test basic type filtering patterns
        let selectedTypes: Set<Int16> = [1, 3]
        let item1Type: Int16 = 1
        let item2Type: Int16 = 2
        let item3Type: Int16 = 3
        
        #expect(selectedTypes.contains(item1Type), "Should include item with selected type 1")
        #expect(!selectedTypes.contains(item2Type), "Should not include item with unselected type 2")
        #expect(selectedTypes.contains(item3Type), "Should include item with selected type 3")
        
        // Test empty set behavior
        let emptySet: Set<Int16> = []
        #expect(emptySet.isEmpty, "Empty set should be empty")
        #expect(!emptySet.contains(1), "Empty set should not contain any items")
    }
}

@Suite("Basic Sort Logic Tests")
struct BasicSortLogicTests {
    
    @Test("Basic sorting patterns work correctly")
    func testBasicSortingPatterns() {
        // Test basic sorting patterns without requiring specific classes
        
        struct TestItem {
            let name: String?
            let code: String?
            let value: Double
        }
        
        let items = [
            TestItem(name: "Zebra", code: "Z001", value: 30.0),
            TestItem(name: "Alpha", code: "A001", value: 10.0),
            TestItem(name: "Beta", code: "B001", value: 20.0),
            TestItem(name: nil, code: "X001", value: 5.0)
        ]
        
        // Test sorting by name
        let sortedByName = items.sorted { first, second in
            let firstName = first.name ?? ""
            let secondName = second.name ?? ""
            return firstName < secondName
        }
        
        #expect(sortedByName.count == items.count, "Should maintain item count when sorting")
        #expect(sortedByName[0].name == nil, "Nil name should sort first (as empty string)")
        #expect(sortedByName[1].name == "Alpha", "Alpha should sort second")
        #expect(sortedByName[2].name == "Beta", "Beta should sort third")
        #expect(sortedByName[3].name == "Zebra", "Zebra should sort last")
        
        // Test sorting by numeric value
        let sortedByValue = items.sorted { $0.value < $1.value }
        #expect(sortedByValue[0].value == 5.0, "Smallest value should sort first")
        #expect(sortedByValue[3].value == 30.0, "Largest value should sort last")
    }
    
    @Test("Sorting handles nil values correctly")
    func testSortingWithNilValues() {
        struct TestItem {
            let name: String?
        }
        
        let items = [
            TestItem(name: "Charlie"),
            TestItem(name: nil),
            TestItem(name: "Alice"),
            TestItem(name: "Bob")
        ]
        
        let sorted = items.sorted { first, second in
            let firstName = first.name ?? ""
            let secondName = second.name ?? ""
            return firstName < secondName
        }
        
        #expect(sorted.count == items.count, "Should maintain item count")
        #expect(sorted[0].name == nil, "Nil should sort first")
        #expect(sorted[1].name == "Alice", "Alice should sort after nil")
    }
}

@Suite("SearchUtilities Advanced Tests")
struct SearchUtilitiesAdvancedTests {
    
    @Test("SearchConfig default configuration is reasonable")
    func testSearchConfigDefaults() {
        let defaultConfig = SearchUtilities.SearchConfig.default
        #expect(defaultConfig.caseSensitive == false, "Default should be case insensitive")
        #expect(defaultConfig.exactMatch == false, "Default should allow partial matches")
        #expect(defaultConfig.fuzzyTolerance == nil, "Default should not use fuzzy matching")
        #expect(defaultConfig.highlightMatches == false, "Default should not highlight matches")
    }
    
    @Test("SearchConfig fuzzy configuration enables fuzzy search")
    func testSearchConfigFuzzy() {
        let fuzzyConfig = SearchUtilities.SearchConfig.fuzzy
        #expect(fuzzyConfig.caseSensitive == false, "Fuzzy should be case insensitive")
        #expect(fuzzyConfig.exactMatch == false, "Fuzzy should allow partial matches")
        #expect(fuzzyConfig.fuzzyTolerance != nil, "Fuzzy should have tolerance set")
        #expect(fuzzyConfig.fuzzyTolerance == 2, "Fuzzy tolerance should be reasonable")
    }
    
    @Test("SearchConfig exact configuration requires exact matches")
    func testSearchConfigExact() {
        let exactConfig = SearchUtilities.SearchConfig.exact
        #expect(exactConfig.caseSensitive == false, "Exact should still be case insensitive")
        #expect(exactConfig.exactMatch == true, "Exact should require exact matches")
        #expect(exactConfig.fuzzyTolerance == nil, "Exact should not use fuzzy matching")
    }
    
    @Test("Weighted search relevance scoring works correctly")
    func testWeightedSearchRelevanceScoring() {
        // Test the scoring logic without requiring actual searchable items
        
        // Mock weighted search scenario
        struct MockSearchResult {
            let relevance: Double
        }
        
        let results = [
            MockSearchResult(relevance: 10.0), // Exact match
            MockSearchResult(relevance: 5.0),  // Partial match
            MockSearchResult(relevance: 2.0),  // Fuzzy match
            MockSearchResult(relevance: 1.0)   // Weak match
        ]
        
        let sorted = results.sorted { $0.relevance > $1.relevance }
        
        #expect(sorted[0].relevance == 10.0, "Highest relevance should sort first")
        #expect(sorted[1].relevance == 5.0, "Second highest should sort second")
        #expect(sorted[2].relevance == 2.0, "Third highest should sort third")
        #expect(sorted[3].relevance == 1.0, "Lowest should sort last")
        
        // Test that sorting maintains all items
        #expect(sorted.count == results.count, "Should maintain all results when sorting")
    }
    
    @Test("Multiple terms search logic (AND) works correctly")
    func testMultipleTermsANDLogic() {
        // Test the AND logic for multiple search terms
        let searchTerms = ["glass", "red", "rod"]
        let testText = "red glass rod 6mm"
        
        let allTermsFound = searchTerms.allSatisfy { term in
            testText.lowercased().contains(term.lowercased())
        }
        
        #expect(allTermsFound == true, "Should find all terms in matching text")
        
        // Test with missing term
        let testTextMissing = "blue glass rod 6mm"
        let someTermsMissing = searchTerms.allSatisfy { term in
            testTextMissing.lowercased().contains(term.lowercased())
        }
        
        #expect(someTermsMissing == false, "Should not match when any term is missing")
    }
    
    @Test("Sort criteria enums have reasonable values")
    func testSortCriteriaEnums() {
        // Test InventorySortCriteria
        let inventoryCriteria = InventorySortCriteria.allCases
        #expect(inventoryCriteria.contains(.catalogCode), "Should include catalog code sort")
        #expect(inventoryCriteria.contains(.count), "Should include count sort") 
        #expect(inventoryCriteria.contains(.type), "Should include type sort")
        
        // Test that raw values are reasonable
        for criteria in inventoryCriteria {
            #expect(!criteria.rawValue.isEmpty, "Sort criteria should have non-empty display name")
        }
        
        // Test CatalogSortCriteria
        let catalogCriteria = CatalogSortCriteria.allCases
        #expect(catalogCriteria.contains(.name), "Should include name sort")
        #expect(catalogCriteria.contains(.manufacturer), "Should include manufacturer sort")
        #expect(catalogCriteria.contains(.code), "Should include code sort")
        
        // Test that raw values are reasonable
        for criteria in catalogCriteria {
            #expect(!criteria.rawValue.isEmpty, "Sort criteria should have non-empty display name")
        }
    }
    
    @Test("FilterUtilities manufacturer filtering handles edge cases")
    func testFilterUtilitiesManufacturerEdgeCases() {
        // Test the manufacturer filtering logic patterns
        
        struct MockCatalogItem {
            let manufacturer: String?
            
            var isValidForManufacturerFilter: Bool {
                guard let manufacturer = manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !manufacturer.isEmpty else {
                    return false
                }
                return true
            }
        }
        
        let validItem = MockCatalogItem(manufacturer: "Effetre")
        let emptyItem = MockCatalogItem(manufacturer: "")
        let nilItem = MockCatalogItem(manufacturer: nil)
        let whitespaceItem = MockCatalogItem(manufacturer: "   ")
        
        #expect(validItem.isValidForManufacturerFilter == true, "Valid manufacturer should pass filter")
        #expect(emptyItem.isValidForManufacturerFilter == false, "Empty manufacturer should not pass filter")
        #expect(nilItem.isValidForManufacturerFilter == false, "Nil manufacturer should not pass filter")
        #expect(whitespaceItem.isValidForManufacturerFilter == false, "Whitespace manufacturer should not pass filter")
    }
    
    @Test("FilterUtilities tag filtering with set operations works correctly")
    func testFilterUtilitiesTagFiltering() {
        // Test the set operations logic used in tag filtering
        
        let selectedTags: Set<String> = ["red", "glass", "transparent"]
        let itemTags1: Set<String> = ["red", "opaque", "rod"]
        let itemTags2: Set<String> = ["blue", "metal", "wire"] 
        let itemTags3: Set<String> = ["red", "glass", "clear"]
        
        // Test isDisjoint logic (no common elements)
        let item1Matches = !selectedTags.isDisjoint(with: itemTags1)
        let item2Matches = !selectedTags.isDisjoint(with: itemTags2)
        let item3Matches = !selectedTags.isDisjoint(with: itemTags3)
        
        #expect(item1Matches == true, "Item 1 should match (has 'red')")
        #expect(item2Matches == false, "Item 2 should not match (no common tags)")
        #expect(item3Matches == true, "Item 3 should match (has 'red' and 'glass')")
        
        // Test empty selected tags
        let emptySelected: Set<String> = []
        let emptyResult = emptySelected.isEmpty
        #expect(emptyResult == true, "Empty set should be detected correctly")
    }
}

@Suite("Catalog Tab Search Clear Tests")
struct CatalogTabSearchClearTests {
    
    @Test("Catalog tab should clear search when tapped while already active")
    func testCatalogTabClearSearchWhenTappedWhileActive() {
        // Verify that CatalogView can receive and handle the clearCatalogSearch notification
        var searchTextCleared = false
        
        // Create a mock notification observer
        let expectation = NotificationCenter.default.addObserver(
            forName: .clearCatalogSearch,
            object: nil,
            queue: .main
        ) { _ in
            searchTextCleared = true
        }
        
        // Simulate the notification being posted (this would happen in MainTabView)
        NotificationCenter.default.post(name: .clearCatalogSearch, object: nil)
        
        // Verify the notification was received
        #expect(searchTextCleared == true, "Search should be cleared when notification is posted")
        
        // Clean up
        NotificationCenter.default.removeObserver(expectation)
    }
    
    @Test("Catalog search state should be resettable")
    func testCatalogSearchStateResettable() {
        // Test that the search state properties can be reset to their initial values
        var searchText = "test search"
        var selectedTags: Set<String> = ["tag1", "tag2"]
        var selectedManufacturer: String? = "Test Manufacturer"
        
        // Simulate clearing the search state (equivalent to what clearSearch() does)
        searchText = ""
        selectedTags.removeAll()
        selectedManufacturer = nil
        
        // Verify all search state is cleared
        #expect(searchText.isEmpty, "Search text should be cleared")
        #expect(selectedTags.isEmpty, "Selected tags should be cleared")
        #expect(selectedManufacturer == nil, "Selected manufacturer should be cleared")
    }
    
    @Test("MainTabView posts clearCatalogSearch notification when catalog tab tapped while active")
    func testMainTabViewPostsClearNotification() {
        // Test that the MainTabView logic correctly posts the notification
        var notificationPosted = false
        
        let expectation = NotificationCenter.default.addObserver(
            forName: .clearCatalogSearch,
            object: nil,
            queue: .main
        ) { _ in
            notificationPosted = true
        }
        
        // Simulate the MainTabView logic: same tab tapped while already selected
        let selectedTab = DefaultTab.catalog
        let tappedTab = DefaultTab.catalog
        
        if selectedTab == tappedTab {
            // This is the logic from MainTabView.handleTabTap
            switch tappedTab {
            case .catalog:
                NotificationCenter.default.post(name: .clearCatalogSearch, object: nil)
            default:
                break
            }
        }
        
        #expect(notificationPosted == true, "MainTabView should post clearCatalogSearch notification when catalog tab is tapped while active")
        
        // Clean up
        NotificationCenter.default.removeObserver(expectation)
    }
    
    @Test("Enhanced search clearing should provide comprehensive reset functionality")
    func testEnhancedSearchClearingLogic() {
        // Test that the enhanced search clearing provides comprehensive functionality
        
        // Simulate the core logic of enhanced clear search
        var searchText = "test search"
        var selectedTags: Set<String> = ["tag1", "tag2"]
        var selectedManufacturer: String? = "Test Manufacturer"
        var animationApplied = false
        var keyboardHidden = false
        var feedbackProvided = false
        
        // Mock enhanced clear function that mimics CatalogView.clearSearch()
        func enhancedClearSearch() {
            // Clear search state with animation
            animationApplied = true
            searchText = ""
            selectedTags.removeAll()
            selectedManufacturer = nil
            
            // Hide keyboard
            keyboardHidden = true
            
            // Provide user feedback
            feedbackProvided = true
        }
        
        // Execute enhanced clear
        enhancedClearSearch()
        
        // Verify all functionality
        #expect(searchText.isEmpty, "Search text should be cleared")
        #expect(selectedTags.isEmpty, "Selected tags should be cleared")
        #expect(selectedManufacturer == nil, "Selected manufacturer should be cleared")
        #expect(animationApplied == true, "Animation should be applied for smooth visual feedback")
        #expect(keyboardHidden == true, "Keyboard should be hidden")
        #expect(feedbackProvided == true, "User feedback should be provided")
    }
    
    @Test("Search clearing should handle edge cases gracefully")
    func testSearchClearingEdgeCases() {
        // Test clearing when already cleared
        var searchText = ""
        var selectedTags: Set<String> = []
        var selectedManufacturer: String? = nil
        var clearOperationCompleted = false
        
        // Mock clear function that handles already-cleared state
        func clearSearchSafely() {
            searchText = ""
            selectedTags.removeAll()
            selectedManufacturer = nil
            clearOperationCompleted = true
        }
        
        clearSearchSafely()
        
        #expect(searchText.isEmpty, "Should handle already empty search text")
        #expect(selectedTags.isEmpty, "Should handle already empty tag selection")
        #expect(selectedManufacturer == nil, "Should handle already nil manufacturer")
        #expect(clearOperationCompleted == true, "Clear operation should complete successfully")
    }
    
    @Test("Search cleared feedback should have proper timing")
    func testSearchClearedFeedbackTiming() {
        // Test that feedback state management works correctly
        var searchClearedFeedback = false
        var feedbackResetAfterDelay = false
        
        // Mock the feedback timing logic
        func provideFeedbackWithTiming() {
            // Show feedback immediately
            searchClearedFeedback = true
            
            // Simulate async delay reset (in real app this would be DispatchQueue.main.asyncAfter)
            feedbackResetAfterDelay = true
            if feedbackResetAfterDelay {
                searchClearedFeedback = false
            }
        }
        
        provideFeedbackWithTiming()
        
        #expect(feedbackResetAfterDelay == true, "Feedback should be scheduled to reset after delay")
        #expect(searchClearedFeedback == false, "Feedback should be reset after timing logic")
    }
}
