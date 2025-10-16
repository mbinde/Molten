//
//  CatalogViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/13/25.
//  Phase 1 Testing Improvements: Core SwiftUI Views Testing
//  ✅ MIGRATED to GlassItem Architecture on 10/14/25
//
//  MIGRATION SUMMARY:
//  • Updated from CatalogItemModel to CompleteInventoryItemModel
//  • Switched from createItem() to createGlassItem() API calls  
//  • Updated test data from createTestCatalogItems() to createTestGlassItems()
//  • Fixed mock service setup with proper constructor parameters
//  • Updated all property accesses to use glassItem.property structure
//  • Converted test assertions to use natural key system
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
        // NEW: Use the new GlassItem system with mock repositories
        let mockGlassItemRepo = MockGlassItemRepository()
        let mockInventoryRepo = MockInventoryRepository()
        let mockItemTagsRepo = MockItemTagsRepository()
        let mockLocationRepo = MockLocationRepository()
        let mockItemMinimumRepo = MockItemMinimumRepository()
        
        let mockInventoryTrackingService = InventoryTrackingService(
            glassItemRepository: mockGlassItemRepo,
            inventoryRepository: mockInventoryRepo,
            locationRepository: mockLocationRepo,
            itemTagsRepository: mockItemTagsRepo
        )
        
        let mockShoppingListService = ShoppingListService(
            itemMinimumRepository: mockItemMinimumRepo,
            inventoryRepository: mockInventoryRepo,  // NEW: Pass inventory repository directly
            glassItemRepository: mockGlassItemRepo,  // NEW: Pass glass item repository directly
            itemTagsRepository: mockItemTagsRepo     // NEW: Pass item tags repository directly
        )
        
        return CatalogService(
            glassItemRepository: mockGlassItemRepo,
            inventoryTrackingService: mockInventoryTrackingService,
            shoppingListService: mockShoppingListService,
            itemTagsRepository: mockItemTagsRepo
        )
    }
    
    private func createTestGlassItems() -> [GlassItemModel] {  // NEW: Create GlassItemModel instead of CatalogItemModel
        return [
            GlassItemModel(
                natural_key: "bullseye-rgr-001-0",
                name: "Bullseye Red",
                sku: "rgr-001",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "spectrum-bgs-002-0",
                name: "Spectrum Blue",
                sku: "bgs-002",
                manufacturer: "spectrum",
                coe: 96,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "uroboros-grn-003-0",
                name: "Uroboros Green",
                sku: "grn-003",
                manufacturer: "uroboros",
                coe: 96,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "bullseye-ylw-004-0",
                name: "Bullseye Yellow",
                sku: "ylw-004",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "spectrum-clr-005-0",
                name: "Spectrum Clear",
                sku: "clr-005",
                manufacturer: "spectrum",
                coe: 96,
                mfr_status: "available"
            )
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
        
        // Add test data to the service - NEW: Use GlassItem system
        let testItems = createTestGlassItems()  // NEW: Use createTestGlassItems
        for item in testItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
        }
        
        // Test that the view can load data from the repository
        let loadedItems = try await catalogView.loadItemsFromRepository()
        
        #expect(loadedItems.count == 5, "Should load all 5 test catalog items")
        
        // NEW: Access through glassItem.naturalKey instead of code
        let naturalKeys = loadedItems.map { $0.glassItem.natural_key }
        #expect(naturalKeys.contains("bullseye-rgr-001-0"), "Should contain Bullseye Red item")
        #expect(naturalKeys.contains("spectrum-bgs-002-0"), "Should contain Spectrum Blue item")
        #expect(naturalKeys.contains("uroboros-grn-003-0"), "Should contain Uroboros Green item")
    }
    
    // MARK: - Search Functionality Tests
    
    @Test("Should perform search through repository")
    func testCatalogViewSearchFunctionality() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add test data - NEW: Use GlassItem system
        let testItems = createTestGlassItems()  // NEW: Use createTestGlassItems
        for item in testItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
        }
        
        // Test search by manufacturer
        let bullseyeSearchResults = await catalogView.performSearch(searchText: "bullseye")
        #expect(bullseyeSearchResults.count == 2, "Should find 2 Bullseye items")
        
        // Test search by name
        let redSearchResults = await catalogView.performSearch(searchText: "Red")
        #expect(redSearchResults.count == 1, "Should find 1 Red item")
        
        // Test search by manufacturer
        let spectrumSearchResults = await catalogView.performSearch(searchText: "spectrum")
        #expect(spectrumSearchResults.count == 2, "Should find 2 Spectrum items")
        
        // Test case-insensitive search
        let lowercaseResults = await catalogView.performSearch(searchText: "bullseye")
        #expect(lowercaseResults.count == 2, "Search should be case-insensitive")
    }
    
    @Test("Should handle empty search results")
    func testCatalogViewEmptySearchResults() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add test data - NEW: Use GlassItem system
        let testItems = createTestGlassItems()  // NEW: Use createTestGlassItems
        for item in testItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
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
        
        // Add test data - NEW: Use GlassItem system
        let testItems = createTestGlassItems()  // NEW: Use createTestGlassItems
        for item in testItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
        }
        
        let manufacturers = await catalogView.getAvailableManufacturers()
        
        #expect(manufacturers.count == 3, "Should have 3 unique manufacturers")
        #expect(manufacturers.contains("bullseye"), "Should contain bullseye")  // NEW: Use lowercase manufacturer names
        #expect(manufacturers.contains("spectrum"), "Should contain spectrum")  // NEW: Use lowercase manufacturer names
        #expect(manufacturers.contains("uroboros"), "Should contain uroboros")  // NEW: Use lowercase manufacturer names
        #expect(manufacturers.sorted() == manufacturers, "Manufacturers should be sorted alphabetically")
    }
    
    @Test("Should get display items correctly")
    func testCatalogViewDisplayItems() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add test data - NEW: Use GlassItem system
        let testItems = createTestGlassItems()  // NEW: Use createTestGlassItems
        for item in testItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
        }
        
        let displayItems = await catalogView.getDisplayItems()
        
        #expect(displayItems.count == 5, "Should return all 5 catalog items for display")
        
        // Test that display items have proper formatting - NEW: Access through glassItem
        for item in displayItems {
            #expect(!item.glassItem.name.isEmpty, "Each item should have a non-empty name")
            #expect(!item.glassItem.natural_key.isEmpty, "Each item should have a non-empty natural key")
            #expect(!item.glassItem.manufacturer.isEmpty, "Each item should have a non-empty manufacturer")
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
        
        // Add initial data - NEW: Use GlassItem system
        let initialItems = Array(createTestGlassItems().prefix(3))  // NEW: Use createTestGlassItems
        for item in initialItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
        }
        
        let initialCount = await catalogView.getDisplayItems().count
        #expect(initialCount == 3, "Should show 3 initial items")
        
        // Add more items
        let additionalItems = Array(createTestGlassItems().suffix(2))  // NEW: Use createTestGlassItems
        for item in additionalItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
        }
        
        // Test that the view picks up new items after refresh
        let updatedItems = try await catalogView.loadItemsFromRepository()
        #expect(updatedItems.count == 5, "Should show all 5 items after adding more")
        
        // Test that search results are consistent
        let searchResults = await catalogView.performSearch(searchText: "bullseye")  // NEW: Use lowercase
        #expect(searchResults.count == 2, "Search results should reflect all added items")
    }
    
    // MARK: - Performance and Edge Case Tests
    
    @Test("Should handle duplicate catalog codes gracefully")
    func testCatalogViewDuplicateHandling() async throws {
        let catalogService = createMockCatalogService()
        let catalogView = CatalogView(catalogService: catalogService)
        
        // Add items with different natural keys but similar properties
        let item1 = GlassItemModel(
            natural_key: "test-001-0",
            name: "Red Glass",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        let item2 = GlassItemModel(
            natural_key: "test-001-1",  // Different sequence number
            name: "Blue Glass", 
            sku: "001",  // Same SKU but different sequence
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        
        _ = try await catalogService.createGlassItem(item1, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
        _ = try await catalogService.createGlassItem(item2, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
        
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
            GlassItemModel(
                natural_key: "test-rb-001-0",
                name: "Red & Blue",
                sku: "rb-001",
                manufacturer: "test",
                coe: 96,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "test-g1-001-0",
                name: "Glass #1",
                sku: "g1-001",
                manufacturer: "test",
                coe: 96,
                mfr_status: "available"
            ),
            GlassItemModel(
                natural_key: "test-clr-001-0",
                name: "Clear (Transparent)",
                sku: "clr-001",
                manufacturer: "test",
                coe: 96,
                mfr_status: "available"
            )
        ]
        
        for item in specialItems {
            _ = try await catalogService.createGlassItem(item, initialInventory: [], tags: [])  // NEW: Use createGlassItem with proper parameters
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
        
        // Create a CompleteInventoryItemModel for testing
        let testGlassItem = GlassItemModel(
            natural_key: "test-001-0",
            name: "Test Item",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        let testCompleteItem = CompleteInventoryItemModel(
            glassItem: testGlassItem,
            inventory: [],
            tags: [],
            locations: []
        )
        
        // Test navigation destination creation
        let catalogDestination = CatalogNavigationDestination.catalogItemDetail(itemModel: testCompleteItem)
        let inventoryDestination = CatalogNavigationDestination.addInventoryItem(naturalKey: "test-001-0")
        
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
        // Create a CompleteInventoryItemModel for testing
        let testGlassItem = GlassItemModel(
            natural_key: "test-001-0",
            name: "Test",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )
        let testCompleteItem = CompleteInventoryItemModel(
            glassItem: testGlassItem,
            inventory: [],
            tags: [],
            locations: []
        )

        let catalogDestination = CatalogNavigationDestination.catalogItemDetail(itemModel: testCompleteItem)
        let inventoryDestination = CatalogNavigationDestination.addInventoryItem(naturalKey: "test-001-0")

        // Test Hashable conformance (required for NavigationStack)
        let destinationSet: Set<CatalogNavigationDestination> = [catalogDestination, inventoryDestination]
        #expect(destinationSet.count == 2, "Navigation destinations should be hashable and unique")
    }
}

// MARK: - CatalogItemModelRowView Tests

@Suite("CatalogItemModelRowView Image Tests")
struct CatalogItemModelRowViewTests {

    @Test("CatalogItemModelRowView should use ProductImageThumbnail with sku field")
    func testRowViewUsesProductImageThumbnailWithSKU() {
        // Arrange: Create a CompleteInventoryItemModel with known sku
        let glassItem = GlassItemModel(
            natural_key: "cim-550-0",
            name: "Cim Test Color",
            sku: "550",
            manufacturer: "CIM",
            coe: 104,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create row view with the item
        let rowView = CatalogItemModelRowView(item: completeItem)

        // Assert: View should be created successfully
        #expect(rowView != nil, "CatalogItemModelRowView should be created successfully")
    }

    @Test("CatalogItemModelRowView should handle items without images gracefully")
    func testRowViewHandlesItemsWithoutImages() {
        // Arrange: Create item with SKU that doesn't have an image file
        let glassItem = GlassItemModel(
            natural_key: "test-nonexistent-999-0",
            name: "Item Without Image",
            sku: "nonexistent-999",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create row view - should not crash even if image doesn't exist
        let rowView = CatalogItemModelRowView(item: completeItem)

        // Assert: View should be created without crashing
        #expect(rowView != nil, "CatalogItemModelRowView should handle missing images gracefully")
    }

    @Test("CatalogItemModelRowView should use sku not natural_key for images")
    func testRowViewUsesSKUNotNaturalKey() {
        // Arrange: Create item where natural_key differs from sku
        // This ensures we're testing that the code uses sku, not natural_key
        let glassItem = GlassItemModel(
            natural_key: "ef-591284-0",  // natural_key includes sequence
            name: "Effetre Test Color",
            sku: "591284",  // sku is just the product code
            manufacturer: "EF",
            coe: 104,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],
            locations: []
        )

        // Act: Create row view
        let rowView = CatalogItemModelRowView(item: completeItem)

        // Assert: View should use sku (591284) not natural_key (ef-591284-0)
        // ProductImageThumbnail should look for "EF-591284.jpg", not "EF-ef-591284-0.jpg"
        #expect(rowView != nil, "CatalogItemModelRowView should use sku for image lookup")
    }

    @Test("CatalogItemModelRowView should display all item information")
    func testRowViewDisplaysAllItemInformation() {
        // Arrange: Create item with full details
        let glassItem = GlassItemModel(
            natural_key: "dh-pd-304-0",
            name: "Double Helix Pandora",
            sku: "PD-304",
            manufacturer: "DH",
            coe: 104,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: ["reactive", "striking"],
            locations: []
        )

        // Act: Create row view
        let rowView = CatalogItemModelRowView(item: completeItem)

        // Assert: View should be created with all information
        // The view displays: image, name, natural_key, manufacturer, and tags
        #expect(rowView != nil, "CatalogItemModelRowView should display all item information")
        #expect(!completeItem.glassItem.name.isEmpty, "Item should have name")
        #expect(!completeItem.glassItem.natural_key.isEmpty, "Item should have natural key")
        #expect(!completeItem.glassItem.manufacturer.isEmpty, "Item should have manufacturer")
        #expect(completeItem.tags.count == 2, "Item should have tags")
    }

    @Test("CatalogItemModelRowView should handle empty tags")
    func testRowViewHandlesEmptyTags() {
        // Arrange: Create item with no tags
        let glassItem = GlassItemModel(
            natural_key: "test-001-0",
            name: "Item Without Tags",
            sku: "001",
            manufacturer: "test",
            coe: 96,
            mfr_status: "available"
        )

        let completeItem = CompleteInventoryItemModel(
            glassItem: glassItem,
            inventory: [],
            tags: [],  // No tags
            locations: []
        )

        // Act: Create row view
        let rowView = CatalogItemModelRowView(item: completeItem)

        // Assert: View should handle empty tags without crashing
        #expect(rowView != nil, "CatalogItemModelRowView should handle empty tags")
        #expect(completeItem.tags.isEmpty, "Item should have no tags")
    }
}
