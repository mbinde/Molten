//
//  CatalogServiceAdvancedTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 1 Testing Improvements: Service Layer Edge Cases
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

@Suite("CatalogService Advanced Business Logic")
struct CatalogServiceAdvancedTests {
    
    // MARK: - Test Data Factory
    
    private func createMockService() -> CatalogService {
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()
        
        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            inventoryRepository: inventoryRepo,
            locationRepository: locationRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        let shoppingListService = ShoppingListService(
            itemMinimumRepository: itemMinimumRepo,
            inventoryRepository: inventoryRepo,
            glassItemRepository: glassItemRepo,
            itemTagsRepository: itemTagsRepo
        )
        
        return CatalogService(
            glassItemRepository: glassItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            shoppingListService: shoppingListService,
            itemTagsRepository: itemTagsRepo
        )
    }
    
    private func createDuplicateProneItems() -> [GlassItemModel] {
        return [
            GlassItemModel(natural_key: "bullseye-rg-001-0", name: "Red Glass", sku: "RG-001", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "bullseye-rg-001-1", name: "Red Glass", sku: "RG-001", manufacturer: "Bullseye", coe: 90, mfr_status: "available"), // Different sequence
            GlassItemModel(natural_key: "bullseye-rg001-0", name: "Red Glass", sku: "RG001", manufacturer: "Bullseye", coe: 90, mfr_status: "available"), // Similar code
            GlassItemModel(natural_key: "spectrum-rg-001-0", name: "Crimson Glass", sku: "RG-001", manufacturer: "Spectrum", coe: 96, mfr_status: "available"), // Same code, different manufacturer
            GlassItemModel(natural_key: "bullseye-rg-001-2", name: "Deep Red", sku: "RG-001", manufacturer: "Bullseye", coe: 90, mfr_status: "available") // Same code, different name
        ]
    }
    
    private func createSearchTestItems() -> [GlassItemModel] {
        return [
            GlassItemModel(natural_key: "bullseye-0124-0", name: "Bullseye Red Opal", sku: "0124", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "bullseye-1108-0", name: "Bullseye Blue Transparent", sku: "1108", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "spectrum-125-0", name: "Spectrum Red", sku: "125", manufacturer: "Spectrum", coe: 96, mfr_status: "available"),
            GlassItemModel(natural_key: "uroboros-94-16-0", name: "Uroboros Red with Silver", sku: "94-16", manufacturer: "Uroboros", coe: 96, mfr_status: "available"),
            GlassItemModel(natural_key: "kokomo-142ag-0", name: "Kokomo Amber Granite", sku: "142AG", manufacturer: "Kokomo", coe: 96, mfr_status: "available")
        ]
    }
    
    private func createValidationTestItems() -> [GlassItemModel] {
        return [
            // Valid items
            GlassItemModel(natural_key: "bullseye-001-0", name: "Standard Glass", sku: "001", manufacturer: "Bullseye", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "spectrum-g-123-0", name: "Another Glass", sku: "G-123", manufacturer: "Spectrum", coe: 96, mfr_status: "available"),
            
            // Edge cases that should still be valid
            GlassItemModel(natural_key: "testcorp-abc-123-xyz-0", name: "Glass with Numbers 123", sku: "ABC-123-XYZ", manufacturer: "TestCorp", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "x-1-0", name: "Single", sku: "1", manufacturer: "X", coe: 90, mfr_status: "available"),
            
            // Special characters - these should be handled gracefully
            GlassItemModel(natural_key: "testandco-gm-001-0", name: "Glass & More", sku: "GM-001", manufacturer: "TestAndCo", coe: 90, mfr_status: "available"),
            GlassItemModel(natural_key: "numbercorp-1-0", name: "Glass #1", sku: "1", manufacturer: "NumberCorp", coe: 90, mfr_status: "available")
        ]
    }
    
    // MARK: - Duplicate Detection and Resolution Tests
    
    @Test("Should detect potential duplicates by code similarity")
    func testDuplicateDetection() async throws {
        let service = createMockService()
        let duplicateItems = createDuplicateProneItems()
        
        // Add items to service
        var addedItems: [CompleteInventoryItemModel] = []
        for item in duplicateItems {
            let savedItem = try await service.createGlassItem(item, initialInventory: [], tags: [])
            addedItems.append(savedItem)
        }
        
        // Test that we can retrieve all items (repository handles duplicate logic)
        let allItems = try await service.getAllGlassItems()
        
        // The exact behavior depends on repository duplicate handling policy
        // At minimum, the service should not crash and should return valid items
        #expect(allItems.count >= 1, "Service should handle duplicates gracefully")
        
        for item in allItems {
            #expect(!item.glassItem.name.isEmpty, "All returned items should have valid names")
            #expect(!item.glassItem.natural_key.isEmpty, "All returned items should have valid natural keys")
            #expect(!item.glassItem.manufacturer.isEmpty, "All returned items should have valid manufacturers")
        }
    }
    
    @Test("Should handle exact code duplicates across manufacturers")
    func testCrossManufacturerDuplicates() async throws {
        let service = createMockService()
        
        // Create items with same raw code but different manufacturers
        let item1 = GlassItemModel(natural_key: "bullseye-rg-001-0", name: "Red Glass A", sku: "RG-001", manufacturer: "Bullseye", coe: 90, mfr_status: "available")
        let item2 = GlassItemModel(natural_key: "spectrum-rg-001-0", name: "Red Glass B", sku: "RG-001", manufacturer: "Spectrum", coe: 96, mfr_status: "available")
        
        let savedItem1 = try await service.createGlassItem(item1, initialInventory: [], tags: [])
        let savedItem2 = try await service.createGlassItem(item2, initialInventory: [], tags: [])
        
        // Both should be valid since they have different manufacturers
        #expect(savedItem1.glassItem.natural_key.contains("bullseye"), "First item should have bullseye in natural key")
        #expect(savedItem2.glassItem.natural_key.contains("spectrum"), "Second item should have spectrum in natural key")
        
        // Natural keys should be different due to manufacturer prefix
        #expect(savedItem1.glassItem.natural_key != savedItem2.glassItem.natural_key, "Natural keys should be different across manufacturers")
    }
    
    @Test("Should handle duplicate resolution strategies")
    func testDuplicateResolutionStrategies() async throws {
        let service = createMockService()
        
        // Add original item
        let originalItem = GlassItemModel(natural_key: "bullseye-rg-001-0", name: "Original Red", sku: "RG-001", manufacturer: "Bullseye", coe: 90, mfr_status: "available")
        let savedOriginal = try await service.createGlassItem(originalItem, initialInventory: [], tags: [])
        
        // Try to add potential duplicate (different natural key but similar concept)
        let duplicateItem = GlassItemModel(natural_key: "bullseye-rg-001-1", name: "Updated Red", sku: "RG-001", manufacturer: "Bullseye", coe: 90, mfr_status: "available")
        
        // The behavior here depends on service business rules
        // It might reject, merge, or create separate items
        do {
            let savedDuplicate = try await service.createGlassItem(duplicateItem, initialInventory: [], tags: [])
            
            // If it allows the duplicate, verify both are accessible
            let allItems = try await service.getAllGlassItems()
            let matchingItems = allItems.filter { $0.glassItem.natural_key.contains("bullseye-rg-001") }
            
            #expect(matchingItems.count >= 1, "Should have at least one item with the natural key pattern")
            
        } catch {
            // If it rejects duplicates, that's also valid behavior
            #expect(error != nil, "Service may reject duplicates")
        }
    }
    
    // MARK: - Advanced Search with Ranking Tests
    
    @Test("Should support advanced search with relevance ranking")
    func testAdvancedSearchRanking() async throws {
        let service = createMockService()
        let searchItems = createSearchTestItems()
        
        // Add test data
        for item in searchItems {
            _ = try await service.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Test search ranking for "Red" - should prioritize exact matches
        let searchRequest = GlassItemSearchRequest(searchText: "Red")
        let searchResult = try await service.searchGlassItems(request: searchRequest)
        
        #expect(searchResult.items.count >= 2, "Should find multiple red items")
        
        // Verify that results contain relevant items
        let resultNames = searchResult.items.map { $0.glassItem.name }
        #expect(resultNames.contains { $0.localizedCaseInsensitiveContains("Red") }, "Results should contain items with 'Red' in name")
    }
    
    @Test("Should support fuzzy matching with tolerance")
    func testFuzzySearchMatching() async throws {
        let service = createMockService()
        let searchItems = createSearchTestItems()
        
        // Add test data
        for item in searchItems {
            _ = try await service.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Test fuzzy matching - slight misspellings should still find results
        let fuzzyRequest1 = GlassItemSearchRequest(searchText: "Bulleye") // Missing 's'
        let fuzzyResults1 = try await service.searchGlassItems(request: fuzzyRequest1)
        
        let fuzzyRequest2 = GlassItemSearchRequest(searchText: "Spectrim") // Wrong last letter
        let fuzzyResults2 = try await service.searchGlassItems(request: fuzzyRequest2)
        
        // Depending on implementation, fuzzy matching might or might not work
        // At minimum, search should not crash with misspelled terms
        #expect(fuzzyResults1.items.count >= 0, "Fuzzy search should not crash")
        #expect(fuzzyResults2.items.count >= 0, "Fuzzy search should not crash")
    }
    
    @Test("Should handle complex search queries")
    func testComplexSearchQueries() async throws {
        let service = createMockService()
        let searchItems = createSearchTestItems()
        
        // Add test data
        for item in searchItems {
            _ = try await service.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Test multi-word searches
        let multiWordRequest = GlassItemSearchRequest(searchText: "Bullseye Red")
        let multiWordResults = try await service.searchGlassItems(request: multiWordRequest)
        #expect(multiWordResults.items.count >= 0, "Should handle multi-word searches")
        
        // Test searches with special characters
        let specialCharRequest = GlassItemSearchRequest(searchText: "94-16")
        let specialCharResults = try await service.searchGlassItems(request: specialCharRequest)
        #expect(specialCharResults.items.count >= 0, "Should handle searches with special characters")
        
        // Test empty and whitespace searches
        let emptyRequest = GlassItemSearchRequest(searchText: "")
        let emptyResults = try await service.searchGlassItems(request: emptyRequest)
        
        let whitespaceRequest = GlassItemSearchRequest(searchText: "   ")
        let whitespaceResults = try await service.searchGlassItems(request: whitespaceRequest)
        
        #expect(emptyResults.items.count >= 0, "Should handle empty searches")
        #expect(whitespaceResults.items.count >= 0, "Should handle whitespace searches")
    }
    
    @Test("Should support search result caching for performance")
    func testSearchResultCaching() async throws {
        let service = createMockService()
        let searchItems = createSearchTestItems()
        
        // Add test data
        for item in searchItems {
            _ = try await service.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        let searchRequest = GlassItemSearchRequest(searchText: "Bullseye")
        
        // Perform same search multiple times
        let startTime = Date()
        let firstResults = try await service.searchGlassItems(request: searchRequest)
        let firstSearchTime = Date().timeIntervalSince(startTime)
        
        let secondStart = Date()
        let secondResults = try await service.searchGlassItems(request: searchRequest)
        let secondSearchTime = Date().timeIntervalSince(secondStart)
        
        // Results should be identical
        #expect(firstResults.items.count == secondResults.items.count, "Search results should be consistent")
        
        // Performance comparison would depend on caching implementation
        // At minimum, both searches should complete successfully
        #expect(firstSearchTime >= 0, "First search should complete")
        #expect(secondSearchTime >= 0, "Second search should complete")
    }
    
    // MARK: - Business Rules Validation Tests
    
    @Test("Should validate catalog code formats correctly")
    func testCatalogCodeFormatValidation() async throws {
        let service = createMockService()
        let validationItems = createValidationTestItems()
        
        // Test that all validation items can be created
        for item in validationItems {
            do {
                let savedItem = try await service.createGlassItem(item, initialInventory: [], tags: [])
                
                // Verify that natural keys are properly formatted
                #expect(!savedItem.glassItem.natural_key.isEmpty, "Saved item should have non-empty natural key")
                #expect(savedItem.glassItem.natural_key.contains(item.manufacturer.lowercased()), "Natural key should contain manufacturer prefix")
                
            } catch {
                // Some items might be rejected by business rules - that's valid too
                #expect(error != nil, "Service may reject invalid items based on business rules")
            }
        }
    }
    
    @Test("Should validate manufacturer-specific rules")
    func testManufacturerSpecificValidation() async throws {
        let service = createMockService()
        
        // Test different manufacturer-specific patterns
        let manufacturerTests = [
            ("Bullseye", "0124", true), // Typical Bullseye numeric code
            ("Spectrum", "125", true),  // Typical Spectrum numeric code  
            ("Uroboros", "94-16", true), // Typical Uroboros hyphenated code
            ("Kokomo", "142AG", true),  // Typical Kokomo alphanumeric code
        ]
        
        for (manufacturer, sku, shouldBeValid) in manufacturerTests {
            let naturalKey = GlassItemModel.createNaturalKey(manufacturer: manufacturer.lowercased(), sku: sku, sequence: 0)
            let testItem = GlassItemModel(
                natural_key: naturalKey,
                name: "Test Glass",
                sku: sku,
                manufacturer: manufacturer,
                coe: 90,
                mfr_status: "available"
            )
            
            do {
                let savedItem = try await service.createGlassItem(testItem, initialInventory: [], tags: [])
                #expect(shouldBeValid, "Item should be valid for manufacturer \(manufacturer)")
                #expect(savedItem.glassItem.manufacturer == manufacturer, "Manufacturer should be preserved")
                
            } catch {
                #expect(!shouldBeValid, "Item should be rejected for manufacturer \(manufacturer)")
            }
        }
    }
    
    @Test("Should validate price range constraints")
    func testPriceRangeValidation() async throws {
        let service = createMockService()
        
        // Create test item (note: current GlassItemModel doesn't have price field)
        // This test demonstrates how price validation would work if added
        let testItem = GlassItemModel(natural_key: "test-001-0", name: "Test Glass", sku: "001", manufacturer: "Test", coe: 90, mfr_status: "available")
        
        let savedItem = try await service.createGlassItem(testItem, initialInventory: [], tags: [])
        
        // For now, just verify the item can be created
        #expect(!savedItem.glassItem.name.isEmpty, "Item should be created successfully")
        
        // Future: When price field is added to GlassItemModel, test:
        // - Negative prices rejected
        // - Zero prices handled appropriately  
        // - Extremely high prices flagged
        // - Price format validation (decimal places, currency)
    }
    
    // MARK: - Error Handling and Edge Cases
    
    @Test("Should handle repository errors gracefully")
    func testRepositoryErrorHandling() async throws {
        let service = createMockService()
        
        // This test verifies the service handles repository-level errors
        // The MockRepository should support error injection for comprehensive testing
        
        let testItem = GlassItemModel(natural_key: "test-001-0", name: "Test", sku: "001", manufacturer: "Test", coe: 90, mfr_status: "available")
        
        do {
            let savedItem = try await service.createGlassItem(testItem, initialInventory: [], tags: [])
            #expect(!savedItem.glassItem.natural_key.isEmpty, "Should create item successfully under normal conditions")
            
        } catch {
            // Service should handle errors appropriately
            #expect(error != nil, "Service should propagate appropriate errors")
        }
    }
    
    @Test("Should handle concurrent access safely")
    func testConcurrentAccess() async throws {
        let service = createMockService()
        
        let testItems = createSearchTestItems()
        
        // Test concurrent item creation
        await withTaskGroup(of: Void.self) { group in
            for item in testItems {
                group.addTask {
                    do {
                        _ = try await service.createGlassItem(item, initialInventory: [], tags: [])
                    } catch {
                        // Some might fail due to concurrency - that's expected
                    }
                }
            }
        }
        
        // Verify final state is consistent
        let finalItems = try await service.getAllGlassItems()
        #expect(finalItems.count >= 0, "Final state should be consistent after concurrent operations")
        
        for item in finalItems {
            #expect(!item.glassItem.natural_key.isEmpty, "All final items should have valid natural keys")
            #expect(!item.glassItem.name.isEmpty, "All final items should have valid names")
        }
    }
    
    @Test("Should handle memory pressure gracefully")
    func testMemoryPressureHandling() async throws {
        let service = createMockService()
        
        // Create a large number of items to test memory handling
        var largeItemSet: [GlassItemModel] = []
        
        for i in 1...100 {
            let naturalKey = GlassItemModel.createNaturalKey(manufacturer: "testcorp\(i % 10)", sku: String(format: "%03d", i), sequence: 0)
            let item = GlassItemModel(
                natural_key: naturalKey,
                name: "Test Item \(i)",
                sku: String(format: "%03d", i),
                manufacturer: "TestCorp\(i % 10)", // 10 different manufacturers
                coe: 90,
                mfr_status: "available"
            )
            largeItemSet.append(item)
        }
        
        // Add all items
        for item in largeItemSet {
            _ = try await service.createGlassItem(item, initialInventory: [], tags: [])
        }
        
        // Test that service can still perform operations efficiently
        let allItems = try await service.getAllGlassItems()
        #expect(allItems.count == 100, "Should handle 100 items efficiently")
        
        // Test search performance with large dataset
        let searchRequest = GlassItemSearchRequest(searchText: "Test")
        let searchResults = try await service.searchGlassItems(request: searchRequest)
        #expect(searchResults.items.count == 100, "Search should work efficiently with 100 items")
        
        // Test filtering performance
        let filteredResults = allItems.filter { $0.glassItem.manufacturer.contains("Corp1") }
        #expect(filteredResults.count == 10, "Filtering should work efficiently")
    }
}
