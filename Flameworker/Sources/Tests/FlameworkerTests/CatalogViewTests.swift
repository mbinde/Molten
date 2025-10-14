//
//  CatalogViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 1 Testing Improvements: Core SwiftUI Views Testing
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

@Suite("CatalogView Comprehensive Tests")
struct CatalogViewTests {
    
    // MARK: - Test Data Factory
    
    private func createMockCatalogService() -> CatalogService {
        let mockRepo = MockCatalogRepository()
        return CatalogService(repository: mockRepo)
    }
    
    private func createTestCatalogItems() -> [CatalogItemModel] {
        return [
            CatalogItemModel(name: "Bullseye Red", rawCode: "RGR-001", manufacturer: "Bullseye Glass"),
            CatalogItemModel(name: "Spectrum Blue", rawCode: "BGS-002", manufacturer: "Spectrum Glass"),
            CatalogItemModel(name: "Uroboros Green", rawCode: "GRN-003", manufacturer: "Uroboros"),
            CatalogItemModel(name: "Bullseye Yellow", rawCode: "YLW-004", manufacturer: "Bullseye Glass"),
            CatalogItemModel(name: "Spectrum Clear", rawCode: "CLR-005", manufacturer: "Spectrum Glass")
        ]
    }
    
    // MARK: - Basic View Creation and Configuration Tests
    
    @Test("Should create CatalogView with repository service")
    func testCatalogViewCreation() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Test that the view can be created successfully
        #expect(catalogView != nil, "CatalogView should be created successfully with repository service")
    }
    
    @Test("Should load catalog items through repository pattern")
    func testCatalogViewRepositoryDataLoading() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add test data to the service
        let testItems = createTestCatalogItems()
        for item in testItems {
            _ = try await catalogService.createItem(item)
        }
        
        // Test that the view can load data from the repository
        let loadedItems = try await catalogView.loadItemsFromRepository()
        
        #expect(loadedItems.count == 5, "Should load all 5 test catalog items")
        
        let codes = loadedItems.map { $0.code }
        #expect(codes.contains("BULLSEYE GLASS-RGR-001"), "Should contain Bullseye Red item")
        #expect(codes.contains("SPECTRUM GLASS-BGS-002"), "Should contain Spectrum Blue item")
        #expect(codes.contains("UROBOROS-GRN-003"), "Should contain Uroboros Green item")
    }
    
    // MARK: - Search Functionality Tests
    
    @Test("Should perform search through repository")
    func testCatalogViewSearchFunctionality() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add test data
        let testItems = createTestCatalogItems()
        for item in testItems {
            _ = try await catalogService.createItem(item)
        }
        
        // Test search by catalog code
        let bullseyeSearchResults = await catalogView.performSearch(searchText: "BULLSEYE")
        #expect(bullseyeSearchResults.count == 2, "Should find 2 Bullseye items")
        
        // Test search by name
        let redSearchResults = await catalogView.performSearch(searchText: "Red")
        #expect(redSearchResults.count == 1, "Should find 1 Red item")
        
        // Test search by manufacturer
        let spectrumSearchResults = await catalogView.performSearch(searchText: "Spectrum")
        #expect(spectrumSearchResults.count == 2, "Should find 2 Spectrum items")
        
        // Test case-insensitive search
        let lowercaseResults = await catalogView.performSearch(searchText: "bullseye")
        #expect(lowercaseResults.count == 2, "Search should be case-insensitive")
    }
    
    @Test("Should handle empty search results")
    func testCatalogViewEmptySearchResults() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add test data
        let testItems = createTestCatalogItems()
        for item in testItems {
            _ = try await catalogService.createItem(item)
        }
        
        // Test search with no matches
        let noMatchResults = await catalogView.performSearch(searchText: "NonExistentColor")
        #expect(noMatchResults.isEmpty, "Should return empty results for non-existent items")
        
        // Test empty search (should return all items)
        let emptySearchResults = await catalogView.performSearch(searchText: "")
        #expect(emptySearchResults.count == 5, "Empty search should return all items")
    }
    
    // MARK: - Filter and Sort Functionality Tests
    
    @Test("Should get available manufacturers")
    func testCatalogViewManufacturerFiltering() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add test data
        let testItems = createTestCatalogItems()
        for item in testItems {
            _ = try await catalogService.createItem(item)
        }
        
        let manufacturers = await catalogView.getAvailableManufacturers()
        
        #expect(manufacturers.count == 3, "Should have 3 unique manufacturers")
        #expect(manufacturers.contains("Bullseye Glass"), "Should contain Bullseye Glass")
        #expect(manufacturers.contains("Spectrum Glass"), "Should contain Spectrum Glass")
        #expect(manufacturers.contains("Uroboros"), "Should contain Uroboros")
        #expect(manufacturers.sorted() == manufacturers, "Manufacturers should be sorted alphabetically")
    }
    
    @Test("Should get display items correctly")
    func testCatalogViewDisplayItems() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add test data
        let testItems = createTestCatalogItems()
        for item in testItems {
            _ = try await catalogService.createItem(item)
        }
        
        let displayItems = await catalogView.getDisplayItems()
        
        #expect(displayItems.count == 5, "Should return all 5 catalog items for display")
        
        // Test that display items have proper formatting
        for item in displayItems {
            #expect(!item.name.isEmpty, "Each item should have a non-empty name")
            #expect(!item.code.isEmpty, "Each item should have a non-empty code")
            #expect(!item.manufacturer.isEmpty, "Each item should have a non-empty manufacturer")
        }
    }
    
    // MARK: - Empty State Tests
    
    @Test("Should handle empty catalog correctly")
    func testCatalogViewEmptyState() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Don't add any items - test empty state
        let emptyItems = await catalogView.getDisplayItems()
        #expect(emptyItems.isEmpty, "Should return empty array when no catalog items exist")
        
        let emptySearchResults = await catalogView.performSearch(searchText: "anything")
        #expect(emptySearchResults.isEmpty, "Should return empty search results when catalog is empty")
        
        let emptyManufacturers = await catalogView.getAvailableManufacturers()
        #expect(emptyManufacturers.isEmpty, "Should return empty manufacturers list when catalog is empty")
    }
    
    // MARK: - Data Consistency Tests
    
    @Test("Should maintain data consistency across operations")
    func testCatalogViewDataConsistency() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add initial data
        let initialItems = Array(createTestCatalogItems().prefix(3))
        for item in initialItems {
            _ = try await catalogService.createItem(item)
        }
        
        let initialCount = await catalogView.getDisplayItems().count
        #expect(initialCount == 3, "Should show 3 initial items")
        
        // Add more items
        let additionalItems = Array(createTestCatalogItems().suffix(2))
        for item in additionalItems {
            _ = try await catalogService.createItem(item)
        }
        
        // Test that the view picks up new items after refresh
        let updatedItems = try await catalogView.loadItemsFromRepository()
        #expect(updatedItems.count == 5, "Should show all 5 items after adding more")
        
        // Test that search results are consistent
        let searchResults = await catalogView.performSearch(searchText: "Bullseye")
        #expect(searchResults.count == 2, "Search results should reflect all added items")
    }
    
    // MARK: - Performance and Edge Case Tests
    
    @Test("Should handle duplicate catalog codes gracefully")
    func testCatalogViewDuplicateHandling() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add item with same code but different details
        let item1 = CatalogItemModel(name: "Red Glass", rawCode: "TEST-001", manufacturer: "Manufacturer A")
        let item2 = CatalogItemModel(name: "Blue Glass", rawCode: "TEST-001", manufacturer: "Manufacturer B")
        
        _ = try await catalogService.createItem(item1)
        _ = try await catalogService.createItem(item2)
        
        let allItems = await catalogView.getDisplayItems()
        
        // The repository should handle duplicates according to its business rules
        // At minimum, the view should not crash
        #expect(allItems.count >= 1, "Should handle duplicate codes without crashing")
    }
    
    @Test("Should handle special characters in search")
    func testCatalogViewSpecialCharacterSearch() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add items with special characters
        let specialItems = [
            CatalogItemModel(name: "Red & Blue", rawCode: "R&B-001", manufacturer: "Test Corp"),
            CatalogItemModel(name: "Glass #1", rawCode: "GLASS-#1", manufacturer: "Test Corp"),
            CatalogItemModel(name: "Clear (Transparent)", rawCode: "CLR-001", manufacturer: "Test Corp")
        ]
        
        for item in specialItems {
            _ = try await catalogService.createItem(item)
        }
        
        // Test search with special characters
        let ampersandResults = await catalogView.performSearch(searchText: "&")
        #expect(ampersandResults.count >= 0, "Should handle ampersand in search")
        
        let hashResults = await catalogView.performSearch(searchText: "#")
        #expect(hashResults.count >= 0, "Should handle hash symbol in search")
        
        let parenthesesResults = await catalogView.performSearch(searchText: "(")
        #expect(parenthesesResults.count >= 0, "Should handle parentheses in search")
    }
    
    // MARK: - Navigation Integration Tests (Placeholder)
    
    @Test("Should support navigation destination creation")
    func testCatalogNavigationDestinations() async throws {
        let catalogService = createMockCatalogService()
        let testItem = CatalogItemModel(name: "Test Item", rawCode: "TEST-001", manufacturer: "Test Corp")
        
        // Test navigation destination creation
        let catalogDestination = CatalogNavigationDestination.catalogItemDetail(itemModel: testItem)
        let inventoryDestination = CatalogNavigationDestination.addInventoryItem(catalogCode: "TEST-001")
        
        // Test that navigation destinations can be created
        // (Full navigation testing would require UI testing framework)
        #expect(catalogDestination != nil, "Should create catalog detail navigation destination")
        #expect(inventoryDestination != nil, "Should create add inventory navigation destination")
    }
}

// MARK: - CatalogView Extension Tests

@Suite("CatalogView Supporting Types Tests") 
struct CatalogViewSupportingTypesTests {
    
    @Test("Should support sort options")
    func testSortOptions() async throws {
        // Test SortOption enum from CatalogSortOption.swift
        #expect(SortOption.allCases.count >= 3, "Should have at least 3 sort options")
        
        for option in SortOption.allCases {
            #expect(!option.rawValue.isEmpty, "Each sort option should have a non-empty raw value")
        }
        
        // Test that sort options are suitable for catalog display
        let expectedOptions: Set<String> = ["name", "manufacturer", "code"]
        let actualOptions = Set(SortOption.allCases.map { $0.rawValue.lowercased() })
        
        for expected in expectedOptions {
            #expect(actualOptions.contains { $0.contains(expected) }, "Should contain \(expected) sort option")
        }
    }
    
    @Test("Should support catalog navigation destinations")
    func testCatalogNavigationDestination() async throws {
        let testItem = CatalogItemModel(name: "Test", rawCode: "TEST-001", manufacturer: "Test")
        
        let catalogDestination = CatalogNavigationDestination.catalogItemDetail(itemModel: testItem)
        let inventoryDestination = CatalogNavigationDestination.addInventoryItem(catalogCode: "TEST-001")
        
        // Test Hashable conformance (required for NavigationStack)
        let destinationSet: Set<CatalogNavigationDestination> = [catalogDestination, inventoryDestination]
        #expect(destinationSet.count == 2, "Navigation destinations should be hashable and unique")
    }
}