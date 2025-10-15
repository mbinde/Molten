//
//  DataLoadingServiceTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/12/25.
//

import Foundation
import CoreData
// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

@testable import Flameworker

@Suite("Data Loading Service Repository Integration Tests")
struct DataLoadingServiceRepositoryTests {
    
    @Test("Should work with CatalogService using new GlassItem architecture")
    func testDataLoadingServiceBasicFunctionality() async throws {
        // Arrange: Create DataLoadingService with catalog service using RepositoryFactory
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        
        let dataLoader = DataLoadingService(catalogService: catalogService)
        
        // Act & Assert: Test that DataLoadingService can be instantiated
        #expect(dataLoader != nil, "DataLoadingService should be created with CatalogService")
    }
    
    @Test("Should load and manage glass items using repository pattern")
    func testDataLoadingServiceWithGlassItems() async throws {
        // Arrange: Configure factory and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        // Create test glass item with inventory
        let testGlassItem = GlassItemModel(
            naturalKey: "TEST-LOADER-001",
            name: "Test Loading Glass",
            sku: "TLG-001",
            manufacturer: "TestCorp",
            mfrNotes: "Test glass for data loading",
            coe: 90,
            url: "https://testcorp.com",
            mfrStatus: "available"
        )
        
        let testInventory = [
            InventoryModel(itemNaturalKey: "TEST-LOADER-001", type: "rod", quantity: 10.0)
        ]
        
        _ = try await inventoryTrackingService.createCompleteItem(
            testGlassItem,
            initialInventory: testInventory,
            tags: ["test"]
        )
        
        let dataLoader = DataLoadingService(catalogService: catalogService)
        
        // Act: Load catalog items
        let loadResult = try await dataLoader.loadCatalogItems()
        
        // Assert: Should load glass items successfully
        #expect(loadResult.success == true, "Data loading should succeed")
        #expect(loadResult.itemsLoaded == 1, "Should load one test item")
        #expect(loadResult.details.contains("glass items"), "Should mention glass items in details")
    }
    
    @Test("Should provide system overview using repository services")
    func testDataLoadingServiceSystemOverview() async throws {
        // Arrange: Configure factory and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        // Create multiple test glass items
        let testItems = [
            (naturalKey: "BULLSEYE-001", name: "Bullseye Red", manufacturer: "Bullseye", quantity: 15.0),
            (naturalKey: "SPECTRUM-001", name: "Spectrum Blue", manufacturer: "Spectrum", quantity: 25.0)
        ]
        
        for (naturalKey, name, manufacturer, quantity) in testItems {
            let glassItem = GlassItemModel(
                naturalKey: naturalKey,
                name: name,
                sku: naturalKey,
                manufacturer: manufacturer,
                mfrNotes: "Test glass item",
                coe: 90,
                url: "https://\(manufacturer.lowercased()).com",
                mfrStatus: "available"
            )
            
            let inventory = [
                InventoryModel(itemNaturalKey: naturalKey, type: "rod", quantity: quantity)
            ]
            
            _ = try await inventoryTrackingService.createCompleteItem(
                glassItem,
                initialInventory: inventory,
                tags: []
            )
        }
        
        let dataLoader = DataLoadingService(catalogService: catalogService)
        
        // Act: Get system overview
        let overview = try await dataLoader.getSystemOverview()
        
        // Assert: Should provide accurate system overview
        #expect(overview.totalItems == 2, "Should report correct number of items")
        #expect(overview.totalManufacturers == 2, "Should report correct number of manufacturers")
        #expect(overview.totalInventoryQuantity == 40.0, "Should calculate total inventory correctly")
        #expect(overview.systemType == "GlassItem Architecture", "Should identify correct system type")
    }
    
    @Test("Should support glass item search functionality")
    func testDataLoadingServiceSearch() async throws {
        // Arrange: Configure factory and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        // Create searchable glass items
        let searchableItems = [
            (naturalKey: "BULLSEYE-RED-001", name: "Bullseye Red Rod", manufacturer: "Bullseye"),
            (naturalKey: "BULLSEYE-BLUE-001", name: "Bullseye Blue Sheet", manufacturer: "Bullseye"),
            (naturalKey: "SPECTRUM-GREEN-001", name: "Spectrum Green Frit", manufacturer: "Spectrum")
        ]
        
        for (naturalKey, name, manufacturer) in searchableItems {
            let glassItem = GlassItemModel(
                naturalKey: naturalKey,
                name: name,
                sku: naturalKey,
                manufacturer: manufacturer,
                mfrNotes: "Searchable test item",
                coe: 90,
                url: "https://\(manufacturer.lowercased()).com",
                mfrStatus: "available"
            )
            
            let inventory = [
                InventoryModel(itemNaturalKey: naturalKey, type: "rod", quantity: 5.0)
            ]
            
            _ = try await inventoryTrackingService.createCompleteItem(
                glassItem,
                initialInventory: inventory,
                tags: []
            )
        }
        
        let dataLoader = DataLoadingService(catalogService: catalogService)
        
        // Act: Search for Bullseye items
        let searchResults = try await dataLoader.searchGlassItems(searchText: "Bullseye")
        
        // Assert: Should find matching items
        #expect(searchResults.count == 2, "Should find two Bullseye items")
        #expect(searchResults.allSatisfy { $0.glassItem.manufacturer == "Bullseye" }, "All results should be from Bullseye")
    }
    
    @Test("Should filter items by manufacturer")
    func testDataLoadingServiceManufacturerFilter() async throws {
        // Arrange: Configure factory and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        
        // Create items from different manufacturers
        let manufacturerItems = [
            (naturalKey: "BULLSEYE-ITEM-001", name: "Bullseye Item", manufacturer: "Bullseye"),
            (naturalKey: "SPECTRUM-ITEM-001", name: "Spectrum Item", manufacturer: "Spectrum"),
            (naturalKey: "KOKOMO-ITEM-001", name: "Kokomo Item", manufacturer: "Kokomo")
        ]
        
        for (naturalKey, name, manufacturer) in manufacturerItems {
            let glassItem = GlassItemModel(
                naturalKey: naturalKey,
                name: name,
                sku: naturalKey,
                manufacturer: manufacturer,
                mfrNotes: "Manufacturer filter test item",
                coe: 90,
                url: "https://\(manufacturer.lowercased()).com",
                mfrStatus: "available"
            )
            
            let inventory = [
                InventoryModel(itemNaturalKey: naturalKey, type: "rod", quantity: 8.0)
            ]
            
            _ = try await inventoryTrackingService.createCompleteItem(
                glassItem,
                initialInventory: inventory,
                tags: []
            )
        }
        
        let dataLoader = DataLoadingService(catalogService: catalogService)
        
        // Act: Get items from Spectrum manufacturer
        let spectrumItems = try await dataLoader.getItemsByManufacturer("Spectrum")
        
        // Assert: Should return only Spectrum items
        #expect(spectrumItems.count == 1, "Should find one Spectrum item")
        #expect(spectrumItems.first?.glassItem.manufacturer == "Spectrum", "Should be Spectrum manufacturer")
        #expect(spectrumItems.first?.glassItem.name == "Spectrum Item", "Should have correct item name")
    }
    
    @Test("Should detect existing data in system")
    func testDataLoadingServiceExistingDataDetection() async throws {
        // Arrange: Configure factory and create services
        RepositoryFactory.configureForTesting()
        let catalogService = RepositoryFactory.createCatalogService()
        let dataLoader = DataLoadingService(catalogService: catalogService)
        
        // Act & Assert: Initially should have no data
        let initialHasData = try await dataLoader.hasExistingData()
        #expect(initialHasData == false, "Should initially have no data")
        
        // Add some test data
        let inventoryTrackingService = RepositoryFactory.createInventoryTrackingService()
        let testGlassItem = GlassItemModel(
            naturalKey: "DETECTION-TEST-001",
            name: "Detection Test Item",
            sku: "DT-001",
            manufacturer: "TestCorp",
            mfrNotes: "Item for data detection test",
            coe: 90,
            url: "https://testcorp.com",
            mfrStatus: "available"
        )
        
        _ = try await inventoryTrackingService.createCompleteItem(
            testGlassItem,
            initialInventory: [],
            tags: []
        )
        
        // Act & Assert: Now should have data
        let finalHasData = try await dataLoader.hasExistingData()
        #expect(finalHasData == true, "Should now detect existing data")
    }
}
