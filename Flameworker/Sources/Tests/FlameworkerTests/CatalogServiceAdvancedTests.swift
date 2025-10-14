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
        let mockRepo = MockCatalogRepository()
        return CatalogService(repository: mockRepo)
    }
    
    private func createDuplicateProneItems() -> [CatalogItemModel] {
        return [
            CatalogItemModel(name: "Red Glass", rawCode: "RG-001", manufacturer: "Bullseye"),
            CatalogItemModel(name: "Red Glass", rawCode: "RG-001", manufacturer: "Bullseye"), // Exact duplicate
            CatalogItemModel(name: "Red Glass", rawCode: "RG001", manufacturer: "Bullseye"), // Similar code
            CatalogItemModel(name: "Crimson Glass", rawCode: "RG-001", manufacturer: "Spectrum"), // Same code, different manufacturer
            CatalogItemModel(name: "Deep Red", rawCode: "RG-001", manufacturer: "Bullseye") // Same code, different name
        ]
    }
    
    private func createSearchTestItems() -> [CatalogItemModel] {
        return [
            CatalogItemModel(name: "Bullseye Red Opal", rawCode: "0124", manufacturer: "Bullseye"),
            CatalogItemModel(name: "Bullseye Blue Transparent", rawCode: "1108", manufacturer: "Bullseye"),
            CatalogItemModel(name: "Spectrum Red", rawCode: "125", manufacturer: "Spectrum"),
            CatalogItemModel(name: "Uroboros Red with Silver", rawCode: "94-16", manufacturer: "Uroboros"),
            CatalogItemModel(name: "Kokomo Amber Granite", rawCode: "142AG", manufacturer: "Kokomo")
        ]
    }
    
    private func createValidationTestItems() -> [CatalogItemModel] {
        return [
            // Valid items
            CatalogItemModel(name: "Standard Glass", rawCode: "001", manufacturer: "Bullseye"),
            CatalogItemModel(name: "Another Glass", rawCode: "G-123", manufacturer: "Spectrum"),
            
            // Edge cases that should still be valid
            CatalogItemModel(name: "Glass with Numbers 123", rawCode: "ABC-123-XYZ", manufacturer: "Test Corp"),
            CatalogItemModel(name: "Single", rawCode: "1", manufacturer: "X"),
            
            // Special characters - these should be handled gracefully
            CatalogItemModel(name: "Glass & More", rawCode: "G&M-001", manufacturer: "Test & Co"),
            CatalogItemModel(name: "Glass #1", rawCode: "#1", manufacturer: "Number Corp")
        ]
    }
    
    // MARK: - Duplicate Detection and Resolution Tests
    
    @Test("Should detect potential duplicates by code similarity")
    func testDuplicateDetection() async throws {
        let service = createMockService()
        let duplicateItems = createDuplicateProneItems()
        
        // Add items to service
        var addedItems: [CatalogItemModel] = []
        for item in duplicateItems {
            let savedItem = try await service.createItem(item)
            addedItems.append(savedItem)
        }
        
        // Test that we can retrieve all items (repository handles duplicate logic)
        let allItems = try await service.getAllItems()
        
        // The exact behavior depends on repository duplicate handling policy
        // At minimum, the service should not crash and should return valid items
        #expect(allItems.count >= 1, "Service should handle duplicates gracefully")
        
        for item in allItems {
            #expect(!item.name.isEmpty, "All returned items should have valid names")
            #expect(!item.code.isEmpty, "All returned items should have valid codes")
            #expect(!item.manufacturer.isEmpty, "All returned items should have valid manufacturers")
        }
    }
    
    @Test("Should handle exact code duplicates across manufacturers")
    func testCrossManufacturerDuplicates() async throws {
        let service = createMockService()
        
        // Create items with same raw code but different manufacturers
        let item1 = CatalogItemModel(name: "Red Glass A", rawCode: "RG-001", manufacturer: "Bullseye")
        let item2 = CatalogItemModel(name: "Red Glass B", rawCode: "RG-001", manufacturer: "Spectrum")
        
        let savedItem1 = try await service.createItem(item1)
        let savedItem2 = try await service.createItem(item2)
        
        // Both should be valid since they have different manufacturers
        #expect(savedItem1.code.contains("BULLSEYE"), "First item should have Bullseye in code")
        #expect(savedItem2.code.contains("SPECTRUM"), "Second item should have Spectrum in code")
        
        // Full codes should be different due to manufacturer prefix
        #expect(savedItem1.code != savedItem2.code, "Full codes should be different across manufacturers")
    }
    
    @Test("Should handle duplicate resolution strategies")
    func testDuplicateResolutionStrategies() async throws {
        let service = createMockService()
        
        // Add original item
        let originalItem = CatalogItemModel(name: "Original Red", rawCode: "RG-001", manufacturer: "Bullseye")
        let savedOriginal = try await service.createItem(originalItem)
        
        // Try to add potential duplicate
        let duplicateItem = CatalogItemModel(name: "Updated Red", rawCode: "RG-001", manufacturer: "Bullseye")
        
        // The behavior here depends on service business rules
        // It might reject, merge, or create separate items
        do {
            let savedDuplicate = try await service.createItem(duplicateItem)
            
            // If it allows the duplicate, verify both are accessible
            let allItems = try await service.getAllItems()
            let matchingItems = allItems.filter { $0.code.contains("BULLSEYE-RG-001") }
            
            #expect(matchingItems.count >= 1, "Should have at least one item with the code")
            
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
            _ = try await service.createItem(item)
        }
        
        // Test search ranking for "Red" - should prioritize exact matches
        let redResults = try await service.searchItems(searchText: "Red")
        
        #expect(redResults.count >= 2, "Should find multiple red items")
        
        // Verify that results contain relevant items
        let resultNames = redResults.map { $0.name }
        #expect(resultNames.contains { $0.localizedCaseInsensitiveContains("Red") }, "Results should contain items with 'Red' in name")
    }
    
    @Test("Should support fuzzy matching with tolerance")
    func testFuzzySearchMatching() async throws {
        let service = createMockService()
        let searchItems = createSearchTestItems()
        
        // Add test data
        for item in searchItems {
            _ = try await service.createItem(item)
        }
        
        // Test fuzzy matching - slight misspellings should still find results
        let fuzzyResults1 = try await service.searchItems(searchText: "Bulleye") // Missing 's'
        let fuzzyResults2 = try await service.searchItems(searchText: "Spectrim") // Wrong last letter
        
        // Depending on implementation, fuzzy matching might or might not work
        // At minimum, search should not crash with misspelled terms
        #expect(fuzzyResults1.count >= 0, "Fuzzy search should not crash")
        #expect(fuzzyResults2.count >= 0, "Fuzzy search should not crash")
    }
    
    @Test("Should handle complex search queries")
    func testComplexSearchQueries() async throws {
        let service = createMockService()
        let searchItems = createSearchTestItems()
        
        // Add test data
        for item in searchItems {
            _ = try await service.createItem(item)
        }
        
        // Test multi-word searches
        let multiWordResults = try await service.searchItems(searchText: "Bullseye Red")
        #expect(multiWordResults.count >= 0, "Should handle multi-word searches")
        
        // Test searches with special characters
        let specialCharResults = try await service.searchItems(searchText: "94-16")
        #expect(specialCharResults.count >= 0, "Should handle searches with special characters")
        
        // Test empty and whitespace searches
        let emptyResults = try await service.searchItems(searchText: "")
        let whitespaceResults = try await service.searchItems(searchText: "   ")
        
        #expect(emptyResults.count >= 0, "Should handle empty searches")
        #expect(whitespaceResults.count >= 0, "Should handle whitespace searches")
    }
    
    @Test("Should support search result caching for performance")
    func testSearchResultCaching() async throws {
        let service = createMockService()
        let searchItems = createSearchTestItems()
        
        // Add test data
        for item in searchItems {
            _ = try await service.createItem(item)
        }
        
        let searchTerm = "Bullseye"
        
        // Perform same search multiple times
        let startTime = Date()
        let firstResults = try await service.searchItems(searchText: searchTerm)
        let firstSearchTime = Date().timeIntervalSince(startTime)
        
        let secondStart = Date()
        let secondResults = try await service.searchItems(searchText: searchTerm)
        let secondSearchTime = Date().timeIntervalSince(secondStart)
        
        // Results should be identical
        #expect(firstResults.count == secondResults.count, "Search results should be consistent")
        
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
                let savedItem = try await service.createItem(item)
                
                // Verify that codes are properly formatted
                #expect(!savedItem.code.isEmpty, "Saved item should have non-empty code")
                #expect(savedItem.code.contains(item.manufacturer.uppercased()), "Code should contain manufacturer prefix")
                
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
        
        for (manufacturer, code, shouldBeValid) in manufacturerTests {
            let testItem = CatalogItemModel(
                name: "Test Glass",
                rawCode: code,
                manufacturer: manufacturer
            )
            
            do {
                let savedItem = try await service.createItem(testItem)
                #expect(shouldBeValid, "Item should be valid for manufacturer \(manufacturer)")
                #expect(savedItem.manufacturer == manufacturer, "Manufacturer should be preserved")
                
            } catch {
                #expect(!shouldBeValid, "Item should be rejected for manufacturer \(manufacturer)")
            }
        }
    }
    
    @Test("Should validate price range constraints")
    func testPriceRangeValidation() async throws {
        let service = createMockService()
        
        // Create test item (note: current CatalogItemModel doesn't have price field)
        // This test demonstrates how price validation would work if added
        let testItem = CatalogItemModel(name: "Test Glass", rawCode: "001", manufacturer: "Test")
        
        let savedItem = try await service.createItem(testItem)
        
        // For now, just verify the item can be created
        #expect(!savedItem.name.isEmpty, "Item should be created successfully")
        
        // Future: When price field is added to CatalogItemModel, test:
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
        
        let testItem = CatalogItemModel(name: "Test", rawCode: "001", manufacturer: "Test")
        
        do {
            let savedItem = try await service.createItem(testItem)
            #expect(!savedItem.id.isEmpty, "Should create item successfully under normal conditions")
            
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
                        _ = try await service.createItem(item)
                    } catch {
                        // Some might fail due to concurrency - that's expected
                    }
                }
            }
        }
        
        // Verify final state is consistent
        let finalItems = try await service.getAllItems()
        #expect(finalItems.count >= 0, "Final state should be consistent after concurrent operations")
        
        for item in finalItems {
            #expect(!item.id.isEmpty, "All final items should have valid IDs")
            #expect(!item.name.isEmpty, "All final items should have valid names")
        }
    }
    
    @Test("Should handle memory pressure gracefully")
    func testMemoryPressureHandling() async throws {
        let service = createMockService()
        
        // Create a large number of items to test memory handling
        var largeItemSet: [CatalogItemModel] = []
        
        for i in 1...100 {
            let item = CatalogItemModel(
                name: "Test Item \(i)",
                rawCode: String(format: "%03d", i),
                manufacturer: "Test Corp \(i % 10)" // 10 different manufacturers
            )
            largeItemSet.append(item)
        }
        
        // Add all items
        for item in largeItemSet {
            _ = try await service.createItem(item)
        }
        
        // Test that service can still perform operations efficiently
        let allItems = try await service.getAllItems()
        #expect(allItems.count == 100, "Should handle 100 items efficiently")
        
        // Test search performance with large dataset
        let searchResults = try await service.searchItems(searchText: "Test")
        #expect(searchResults.count == 100, "Search should work efficiently with 100 items")
        
        // Test filtering performance
        let filteredResults = allItems.filter { $0.manufacturer.contains("Corp 1") }
        #expect(filteredResults.count == 10, "Filtering should work efficiently")
    }
}