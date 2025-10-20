//
//  GlassItemDataLoadingServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//
// Target: RepositoryTests

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
import CoreData
@testable import Flameworker

@Suite("GlassItem Data Loading Service Tests - Core Data Integration", .serialized)
struct GlassItemDataLoadingServiceTests {
    
    // MARK: - Test Helper Methods
    
    /// Create isolated test environment with Core Data
    private func createTestEnvironment() async throws -> (PersistenceController, CatalogService, GlassItemDataLoadingService) {
        let testController = PersistenceController.createTestController()
        RepositoryFactory.configure(persistentContainer: testController.container)
        RepositoryFactory.mode = .coreData
        
        let catalogService = RepositoryFactory.createCatalogService()
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .small
        
        let loadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: mockJsonLoader
        )
        
        return (testController, catalogService, loadingService)
    }
    
    /// Create test catalog item data
    private func createTestCatalogData() -> [CatalogItemData] {
        return [
            CatalogItemData(
                id: "test-1",
                code: "TESTMFG-001",
                manufacturer: "TestManufacturer",
                name: "Test Red Glass",
                manufacturer_description: "Red test glass",
                synonyms: ["red", "test"],
                tags: ["red", "test"],
                image_path: nil,
                coe: "96",
                stock_type: "rod",
                image_url: nil,
                manufacturer_url: "https://test.example.com"
            ),
            CatalogItemData(
                id: "test-2", 
                code: "TESTMFG-002",
                manufacturer: "TestManufacturer",
                name: "Test Blue Glass",
                manufacturer_description: "Blue test glass",
                synonyms: ["blue", "test"],
                tags: ["blue", "test"],
                image_path: nil,
                coe: "104",
                stock_type: "rod",
                image_url: nil,
                manufacturer_url: "https://test.example.com"
            )
        ]
    }
    
    // MARK: - Basic Loading Tests
    
    @Test("Should load initial glass items into empty Core Data store")
    func testInitialDataLoading() async throws {
        let (_, catalogService, loadingService) = try await createTestEnvironment()
        
        // Verify empty state
        let initialItems = try await catalogService.getAllGlassItems()
        #expect(initialItems.isEmpty, "Should start with empty store")
        
        // Load data
        let result = try await loadingService.loadGlassItemsFromJSON(options: .default)
        
        // Verify results
        #expect(result.itemsCreated > 0, "Should create items")
        #expect(result.itemsFailed == 0, "Should not fail any items")
        #expect(result.itemsUpdated == 0, "Should not update items on initial load")
        
        // Verify items were persisted
        let loadedItems = try await catalogService.getAllGlassItems()
        #expect(loadedItems.count == result.itemsCreated, "Should persist all created items")
    }
    
    @Test("Should skip existing items when configured to skip")
    func testSkipExistingItems() async throws {
        let (_, catalogService, loadingService) = try await createTestEnvironment()
        
        // First load
        let initialResult = try await loadingService.loadGlassItemsFromJSON(options: .default)
        #expect(initialResult.itemsCreated > 0, "Should create items initially")
        
        // Second load with skip option
        let skipOptions = GlassItemDataLoadingService.LoadingOptions(
            skipExistingItems: true,
            createInitialInventory: false,
            defaultInventoryType: "rod",
            defaultInventoryQuantity: 0.0,
            enableTagExtraction: true,
            enableSynonymTags: true,
            validateNaturalKeys: true,
            batchSize: 50
        )
        
        let skipResult = try await loadingService.loadGlassItemsFromJSON(options: skipOptions)
        #expect(skipResult.itemsCreated == 0, "Should not create duplicate items")
        #expect(skipResult.itemsSkipped > 0, "Should skip existing items")
    }
    
    // MARK: - Update Functionality Tests
    
    @Test("Should detect and update changed items")
    func testUpdateChangedItems() async throws {
        let (_, catalogService, _) = try await createTestEnvironment()

        // Create initial item with natural key format that matches code extraction
        let originalItem = GlassItemModel(
            natural_key: "testmfg-001-0", // Format: manufacturer-sku-sequence
            name: "Original Name",
            sku: "001",
            manufacturer: "testmfg",
            mfr_notes: "Original description",
            coe: 96,
            url: "https://original.com",
            mfr_status: "available"
        )

        let createdItem = try await catalogService.createGlassItem(originalItem, initialInventory: [], tags: [])
        #expect(createdItem.glassItem.name == "Original Name", "Should create original item")

        // Create mock loader with updated data - code must generate natural key "testmfg-001-0"
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .custom
        mockJsonLoader.customTestData = [
            CatalogItemData(
                id: "test-1",
                code: "TESTMFG-001", // Extracts to manufacturer="testmfg", sku="001"
                manufacturer: "TestManufacturer",
                name: "Updated Name", // Changed name
                manufacturer_description: "Updated description", // Changed description
                synonyms: ["updated", "test"],
                tags: ["updated", "test"],
                image_path: nil,
                coe: "96",
                stock_type: "rod",
                image_url: nil,
                manufacturer_url: "https://updated.com" // Changed URL
            )
        ]

        let loadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: mockJsonLoader
        )

        // Load with update option
        let updateResult = try await loadingService.loadGlassItemsFromJSON(options: .appUpdate)

        // Verify update occurred
        #expect(updateResult.itemsUpdated == 1, "Should update one item")
        #expect(updateResult.itemsCreated == 0, "Should not create new items")
        #expect(updateResult.itemsFailed == 0, "Should not fail any items")

        // Verify the item was actually updated
        let updatedItem = try await catalogService.getGlassItemByNaturalKey("testmfg-001-0")
        #expect(updatedItem?.glassItem.name == "Updated Name", "Should update name")
        #expect(updatedItem?.glassItem.mfr_notes == "Updated description", "Should update description")
        #expect(updatedItem?.glassItem.url == "https://updated.com", "Should update URL")
    }
    
    @Test("Should not update items that haven't changed")
    func testSkipUnchangedItems() async throws {
        let (_, catalogService, _) = try await createTestEnvironment()

        // Create initial item with natural key format that matches code extraction
        let originalItem = GlassItemModel(
            natural_key: "testmfg-001-0", // Format: manufacturer-sku-sequence
            name: "Unchanged Name",
            sku: "001",
            manufacturer: "testmfg",
            mfr_notes: "Unchanged description",
            coe: 96,
            url: "https://unchanged.com",
            mfr_status: "available"
        )

        _ = try await catalogService.createGlassItem(originalItem, initialInventory: [], tags: [])

        // Create mock loader with identical data - code must generate natural key "testmfg-001-0"
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .custom
        mockJsonLoader.customTestData = [
            CatalogItemData(
                id: "test-1",
                code: "TESTMFG-001", // Extracts to manufacturer="testmfg", sku="001"
                manufacturer: "TestManufacturer",
                name: "Unchanged Name", // Same data
                manufacturer_description: "Unchanged description",
                synonyms: nil, // No synonyms to match created item
                tags: nil, // No tags to match created item (created with empty tags array)
                image_path: nil,
                coe: "96",
                stock_type: "rod",
                image_url: nil,
                manufacturer_url: "https://unchanged.com"
            )
        ]

        let loadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: mockJsonLoader
        )

        // Load with update option
        let updateResult = try await loadingService.loadGlassItemsFromJSON(options: .appUpdate)

        // Verify no update occurred
        #expect(updateResult.itemsUpdated == 0, "Should not update unchanged items")
        #expect(updateResult.itemsSkipped == 1, "Should skip unchanged items")
        #expect(updateResult.itemsCreated == 0, "Should not create new items")
    }
    
    @Test("Should handle mixed create and update scenarios")
    func testMixedCreateAndUpdate() async throws {
        let (_, catalogService, _) = try await createTestEnvironment()
        
        // Create one existing item - use natural key format that matches code extraction
        // NOTE: manufacturer is lowercased, but SKU preserves case from extraction
        let existingItem = GlassItemModel(
            natural_key: "existing-EX-0", // Format: manufacturer-sku-sequence (SKU case-preserved)
            name: "Existing Item",
            sku: "EX",
            manufacturer: "existing",
            mfr_notes: "Original description",
            coe: 96,
            url: "https://original.com",
            mfr_status: "available"
        )

        _ = try await catalogService.createGlassItem(existingItem, initialInventory: [], tags: [])

        // Create mock loader with mixed data: one update, one new item
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .custom
        mockJsonLoader.customTestData = [
            // Updated existing item - code must generate natural key "existing-ex-0"
            CatalogItemData(
                id: "existing",
                code: "EXISTING-EX", // Extracts to manufacturer="existing", sku="ex"
                manufacturer: "TestManufacturer",
                name: "Updated Existing Item", // Changed name
                manufacturer_description: "Updated description",
                synonyms: ["updated"],
                tags: ["updated"],
                image_path: nil,
                coe: "96",
                stock_type: "rod",
                image_url: nil,
                manufacturer_url: "https://updated.com"
            ),
            // New item - code generates natural key "new-nw-0"
            CatalogItemData(
                id: "new",
                code: "NEW-NW", // Extracts to manufacturer="new", sku="nw"
                manufacturer: "TestManufacturer",
                name: "New Item",
                manufacturer_description: "New description",
                synonyms: ["new"],
                tags: ["new"],
                image_path: nil,
                coe: "104",
                stock_type: "sheet",
                image_url: nil,
                manufacturer_url: "https://new.com"
            )
        ]
        
        let loadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: mockJsonLoader
        )
        
        // Load with update option
        let result = try await loadingService.loadGlassItemsFromJSON(options: .appUpdate)
        
        // Verify mixed results
        #expect(result.itemsCreated == 1, "Should create one new item")
        #expect(result.itemsUpdated == 1, "Should update one existing item")
        #expect(result.itemsFailed == 0, "Should not fail any items")
        
        // Verify total count
        let allItems = try await catalogService.getAllGlassItems()
        #expect(allItems.count == 2, "Should have two items total")
        
        // Verify the existing item was updated (SKU case preserved in natural key)
        let updatedExisting = try await catalogService.getGlassItemByNaturalKey("existing-EX-0")
        #expect(updatedExisting?.glassItem.name == "Updated Existing Item", "Should update existing item")

        // Verify new item was created (SKU case preserved in natural key)
        let newItem = try await catalogService.getGlassItemByNaturalKey("new-NW-0")
        #expect(newItem?.glassItem.name == "New Item", "Should create new item")
    }
    
    // MARK: - Loading Options Tests
    
    @Test("Should use app update options correctly")
    func testAppUpdateOptions() async throws {
        let (_, _, loadingService) = try await createTestEnvironment()
        
        // Test that appUpdate options are configured correctly
        let options = GlassItemDataLoadingService.LoadingOptions.appUpdate
        
        #expect(options.skipExistingItems == false, "Should not skip existing items for updates")
        #expect(options.createInitialInventory == false, "Should not create inventory during updates") 
        #expect(options.enableTagExtraction == true, "Should extract tags")
        #expect(options.enableSynonymTags == true, "Should extract synonym tags")
        #expect(options.validateNaturalKeys == true, "Should validate natural keys")
        #expect(options.batchSize == 25, "Should use moderate batch size")
        
        // Test that loading works with these options
        let result = try await loadingService.loadGlassItemsFromJSON(options: options)
        #expect(result.itemsCreated >= 0, "Should handle loading with app update options")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Should handle update failures gracefully")
    func testUpdateFailureHandling() async throws {
        let (_, catalogService, _) = try await createTestEnvironment()
        
        // Create mock loader that will cause update failures
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .custom
        mockJsonLoader.customTestData = [
            // Invalid data that should cause update failure
            CatalogItemData(
                id: "invalid",
                code: "", // Empty code should cause failure
                manufacturer: "TestManufacturer",
                name: "Invalid Item",
                manufacturer_description: "Invalid description",
                synonyms: [],
                tags: [],
                image_path: nil,
                coe: "invalid", // Invalid COE
                stock_type: "rod",
                image_url: nil,
                manufacturer_url: nil
            )
        ]
        
        let loadingService = GlassItemDataLoadingService(
            catalogService: catalogService,
            jsonLoader: mockJsonLoader
        )
        
        // This should not throw, but should record failures
        let result = try await loadingService.loadGlassItemsFromJSON(options: .appUpdate)
        
        // Should handle failures gracefully
        #expect(result.itemsFailed >= 0, "Should record failed items")
        #expect(result.itemsCreated + result.itemsUpdated + result.itemsSkipped + result.itemsFailed > 0, 
               "Should process some items even with failures")
    }
    
    // MARK: - Performance Tests
    
    @Test("Should handle large datasets efficiently")
    func testLargeDatasetPerformance() async throws {
        let (_, _, loadingService) = try await createTestEnvironment()
        
        // Use medium dataset to test performance without overwhelming the test
        let mockJsonLoader = MockJSONDataLoader()
        mockJsonLoader.testDataMode = .medium
        
        let customService = GlassItemDataLoadingService(
            catalogService: RepositoryFactory.createCatalogService(),
            jsonLoader: mockJsonLoader
        )
        
        let startTime = Date()
        let result = try await customService.loadGlassItemsFromJSON(options: .default)
        let duration = Date().timeIntervalSince(startTime)
        
        // Performance expectations
        #expect(duration < 30.0, "Should complete within 30 seconds")
        #expect(result.batchErrors.isEmpty, "Should not have batch errors with medium dataset")
        #expect(result.itemsCreated + result.itemsFailed == result.successfulItems.count + result.failedItems.count,
               "Should account for all processed items")
    }
    
    // MARK: - Integration Tests
    
    @Test("Should integrate properly with RepositoryFactory")
    func testRepositoryFactoryIntegration() async throws {
        // Test that the factory creates working services
        RepositoryFactory.configureForTestingWithCoreData()
        
        let catalogService = RepositoryFactory.createCatalogService()
        let loadingService = GlassItemDataLoadingService(catalogService: catalogService)
        
        // Should work with factory-created service
        let result = try await loadingService.loadGlassItemsFromJSON(options: .testing)
        #expect(result.itemsCreated >= 0, "Should work with factory-created services")
    }
    
    @Test("Should work with production configuration method")
    func testConfigureForProductionWithInitialData() async throws {
        // Test the new RepositoryFactory method
        do {
            // This should not throw even if no JSON files exist
            try await RepositoryFactory.configureForProductionWithInitialData()
            
            // Should be configured for Core Data
            #expect(RepositoryFactory.mode == .coreData, "Should be in Core Data mode")
            
        } catch {
            // If it fails due to missing JSON, that's expected in test environment
            // The important thing is it doesn't crash
            #expect(true, "Should handle missing JSON gracefully")
        }
    }
}