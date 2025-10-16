//  InventorySearchSuggestionsTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Comprehensive tests for InventorySearchSuggestions complex search algorithm - CORRECTED VERSION
//

import Foundation
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Inventory Search Suggestions Tests - Complex Algorithm")
struct InventorySearchSuggestionsTests {
    
    // MARK: - Test Data Creation Helpers
    
    private func createTestCompleteItems() -> [CompleteInventoryItemModel] {
        let glassItems = [
            GlassItemModel(natural_key: "bullseye-rgr-001", name: "Red Glass Rod", sku: "RGR-001", manufacturer: "Bullseye", coe: 90, mfr_status: "active"),
            GlassItemModel(natural_key: "spectrum-bsg-002", name: "Blue Sheet Glass", sku: "BSG-002", manufacturer: "Spectrum", coe: 96, mfr_status: "active"),
            GlassItemModel(natural_key: "bullseye-cff-003", name: "Clear Frit Fine", sku: "CFF-003", manufacturer: "Bullseye", coe: 90, mfr_status: "active"),
            GlassItemModel(natural_key: "effetre-gs-004", name: "Green Stringer", sku: "GS-004", manufacturer: "Effetre", coe: 104, mfr_status: "active"),
            GlassItemModel(natural_key: "vetrofond-yor-005", name: "Yellow Opal Rod", sku: "YOR-005", manufacturer: "Vetrofond", coe: 104, mfr_status: "active"),
            GlassItemModel(natural_key: "doublehelix-pt-006", name: "Purple Transparent", sku: "PT-006", manufacturer: "Double Helix", coe: 104, mfr_status: "active"),
            GlassItemModel(natural_key: "kokomo-og-007", name: "Orange Granite", sku: "OG-007", manufacturer: "Kokomo", coe: 96, mfr_status: "active"),
            GlassItemModel(natural_key: "northstar-bo-008", name: "Black Opaque", sku: "BO-008", manufacturer: "Northstar", coe: 104, mfr_status: "active")
        ]
        
        return glassItems.map { glassItem in
            CompleteInventoryItemModel(
                glassItem: glassItem,
                inventory: [],
                tags: ["glass", "test"],
                locations: []
            )
        }
    }
    
    private func createTestInventoryModels() -> [InventoryModel] {
        return [
            InventoryModel(item_natural_key: "bullseye-rgr-001", type: "inventory", quantity: 5.0),
            InventoryModel(item_natural_key: "spectrum-bsg-002", type: "buy", quantity: 3.0),
            InventoryModel(item_natural_key: "bullseye-cff-003", type: "inventory", quantity: 2.0)
        ]
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("Should return suggestions for valid queries")
    func testBasicSuggestions() async throws {
        let completeItems = createTestCompleteItems()
        let inventoryModels = createTestInventoryModels()
        
        // Search for items not in inventory
        let greenSuggestions = InventorySearchSuggestions.suggestedGlassItems(
            query: "green",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        
        #expect(greenSuggestions.count == 1, "Should find one green item")
        #expect(greenSuggestions[0].glassItem.natural_key == "effetre-gs-004", "Should find the green stringer")
        #expect(greenSuggestions[0].glassItem.name == "Green Stringer", "Should match the correct item")
    }
    
    // MARK: - Inventory Exclusion Tests
    
    @Test("Should exclude items already in inventory by exact natural key match")
    func testExactNaturalKeyExclusion() async throws {
        let completeItems = createTestCompleteItems()
        let inventoryModels = createTestInventoryModels()
        
        // Test 1: Search for exact natural key that's in inventory - should be excluded
        let excludedResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "bullseye-rgr-001",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(excludedResults.isEmpty, "bullseye-rgr-001 should be excluded as it's in inventory")
        
        // Test 2: Search for exact natural key that's NOT in inventory - should be found
        let includedResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "effetre-gs-004",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(includedResults.count == 1, "effetre-gs-004 should be found as it's not in inventory")
        #expect(includedResults[0].glassItem.natural_key == "effetre-gs-004", "Should find Green Stringer")
        
        // Test 3: Verify exclusion by checking a non-excluded item is found
        let nonExcludedResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "green",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(!nonExcludedResults.isEmpty, "Should find green items as they're not excluded")
        let greenKeys = Set(nonExcludedResults.map { $0.glassItem.natural_key })
        #expect(greenKeys.contains("effetre-gs-004"), "Should find Green Stringer")
    }
    
    @Test("Should exclude items with case-insensitive natural key matching")
    func testCaseInsensitiveExclusion() async throws {
        let completeItems = createTestCompleteItems()
        
        // Create inventory item with uppercase natural key
        let inventoryWithUppercase = [
            InventoryModel(item_natural_key: "BULLSEYE-CFF-003", type: "inventory", quantity: 2.0)
        ]
        
        // Search for clear items - bullseye-cff-003 should be excluded due to case-insensitive matching
        let clearSuggestions = InventorySearchSuggestions.suggestedGlassItems(
            query: "clear",
            inventoryModels: inventoryWithUppercase,
            completeItems: completeItems
        )
        
        #expect(clearSuggestions.isEmpty, "Clear frit should be excluded due to case-insensitive natural key match")
    }
    
    @Test("Should handle multiple exclusion patterns")
    func testMultipleExclusionPatterns() async throws {
        let completeItems = createTestCompleteItems()
        
        // Create inventory with various exclusion patterns
        let complexInventory = [
            InventoryModel(item_natural_key: "bullseye-rgr-001", type: "inventory", quantity: 5.0),
            InventoryModel(item_natural_key: "spectrum-bsg-002", type: "buy", quantity: 3.0),
            InventoryModel(item_natural_key: "bullseye-cff-003", type: "inventory", quantity: 2.0),
            InventoryModel(item_natural_key: "doublehelix-pt-006", type: "inventory", quantity: 1.0)
        ]
        
        let remainingSuggestions = InventorySearchSuggestions.suggestedGlassItems(
            query: "glass",
            inventoryModels: complexInventory,
            completeItems: completeItems
        )
        
        // Should only find items not excluded by any pattern
        let remainingKeys = Set(remainingSuggestions.map { $0.glassItem.natural_key })
        
        #expect(!remainingKeys.contains("bullseye-rgr-001"), "Should exclude bullseye-rgr-001")
        #expect(!remainingKeys.contains("spectrum-bsg-002"), "Should exclude spectrum-bsg-002")
        #expect(!remainingKeys.contains("bullseye-cff-003"), "Should exclude bullseye-cff-003")
        #expect(!remainingKeys.contains("doublehelix-pt-006"), "Should exclude doublehelix-pt-006")
        
        // Should find items that are not in inventory
        #expect(remainingKeys.contains("effetre-gs-004"), "Should include effetre-gs-004")
        #expect(remainingKeys.contains("vetrofond-yor-005"), "Should include vetrofond-yor-005")
    }
    
    // MARK: - Query Handling Tests
    
    @Test("Should handle empty and whitespace queries")
    func testEmptyQueries() async throws {
        let completeItems = createTestCompleteItems()
        let inventoryModels = createTestInventoryModels()
        
        // Test empty query
        let emptyResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(emptyResults.isEmpty, "Empty query should return no results")
        
        // Test whitespace-only query
        let whitespaceResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "   \t\n  ",
            inventoryModels: inventoryModels,
            completeItems: completeItems
        )
        #expect(whitespaceResults.isEmpty, "Whitespace-only query should return no results")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("Should handle empty inventory models")
    func testEmptyInventoryModels() async throws {
        let completeItems = createTestCompleteItems()
        let emptyInventory: [InventoryModel] = []
        
        // Test with a specific search that should match one item exactly
        let specificResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "bullseye-rgr-001",
            inventoryModels: emptyInventory,
            completeItems: completeItems
        )
        
        #expect(specificResults.count == 1, "Should find exactly one item for specific natural key search")
        #expect(specificResults[0].glassItem.natural_key == "bullseye-rgr-001", "Should find Red Glass Rod")
        
        // Test that searches work when no inventory exclusions apply
        let broadResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "glass",
            inventoryModels: emptyInventory,
            completeItems: completeItems
        )
        
        #expect(broadResults.count >= 1, "Should find at least one item for broad search")
        
        // The key test: verify that when there are no exclusions, we get results
        let redResults = InventorySearchSuggestions.suggestedGlassItems(
            query: "red",
            inventoryModels: emptyInventory,
            completeItems: completeItems
        )
        
        #expect(redResults.count >= 1, "Should find at least one result for 'red' search")
        let redKeys = Set(redResults.map { $0.glassItem.natural_key })
        #expect(redKeys.contains("bullseye-rgr-001"), "Should include Red Glass Rod in red search results")
    }
    
    @Test("Should test deprecated method returns empty")
    func testDeprecatedMethod() async throws {
        // Test that the deprecated method returns empty array
        let deprecatedResults = InventorySearchSuggestions.suggestedCatalogItems(
            query: "test",
            inventoryItems: [],
            catalogItems: []
        )
        
        #expect(deprecatedResults.isEmpty, "Deprecated method should return empty array")
    }
}
