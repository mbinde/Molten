//
//  TestDataSetup.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Centralized test data setup to ensure consistent test data across all test files
//

import Foundation
@testable import Flameworker

/// Centralized test data setup utilities
struct TestDataSetup {
    
    /// Create standard test glass items that all tests can expect
    static func createStandardTestGlassItems() -> [GlassItemModel] {
        return [
            // CIM manufacturer items
            GlassItemModel(
                natural_key: "cim-874-0",
                name: "Adamantium",
                sku: "874",
                manufacturer: "cim",
                mfrNotes: "A brown gray color",
                coe: 104,
                url: "https://creationismessy.com",
                mfrStatus: "available"
            ),
            
            // Bullseye manufacturer items
            GlassItemModel(
                natural_key: "bullseye-001-0",
                name: "Bullseye Clear Rod 5mm",
                sku: "001",
                manufacturer: "bullseye",
                mfrNotes: "Clear transparent rod",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfrStatus: "available"
            ),
            
            GlassItemModel(
                natural_key: "bullseye-254-0",
                name: "Red",
                sku: "254",
                manufacturer: "bullseye",
                mfrNotes: "Bright red opaque",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfrStatus: "available"
            ),
            
            // Spectrum manufacturer items
            GlassItemModel(
                natural_key: "spectrum-002-0",
                name: "Blue",
                sku: "002",
                manufacturer: "spectrum",
                mfrNotes: "Deep blue transparent",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            
            GlassItemModel(
                natural_key: "spectrum-125-0",
                name: "Medium Amber",
                sku: "125",
                manufacturer: "spectrum",
                mfrNotes: "Amber transparent",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            
            // Kokomo manufacturer items
            GlassItemModel(
                natural_key: "kokomo-003-0",
                name: "Green Glass",
                sku: "003",
                manufacturer: "kokomo",
                mfrNotes: "Green transparent",
                coe: 96,
                url: "https://kokomoglass.com",
                mfrStatus: "available"
            ),
            
            // Additional items for comprehensive search testing
            GlassItemModel(
                natural_key: "spectrum-100-0",
                name: "Clear",
                sku: "100",
                manufacturer: "spectrum",
                mfrNotes: "Crystal clear",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            
            GlassItemModel(
                natural_key: "bullseye-discontinued-0",
                name: "Old Blue",
                sku: "discontinued",
                manufacturer: "bullseye",
                mfrNotes: "No longer made",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfrStatus: "discontinued"
            ),
            
            // More COE 96 items for search tests
            GlassItemModel(
                natural_key: "spectrum-200-0",
                name: "Red COE96",
                sku: "200",
                manufacturer: "spectrum",
                mfrNotes: "Red transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            
            GlassItemModel(
                natural_key: "kokomo-210-0",
                name: "White COE96",
                sku: "210",
                manufacturer: "kokomo",
                mfrNotes: "White opaque COE96",
                coe: 96,
                url: "https://kokomoglass.com",
                mfrStatus: "available"
            ),
            
            GlassItemModel(
                natural_key: "spectrum-220-0",
                name: "Yellow COE96",
                sku: "220",
                manufacturer: "spectrum",
                mfrNotes: "Yellow transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            ),
            
            GlassItemModel(
                natural_key: "kokomo-230-0",
                name: "Purple COE96",
                sku: "230",
                manufacturer: "kokomo",
                mfrNotes: "Purple opal COE96",
                coe: 96,
                url: "https://kokomoglass.com",
                mfrStatus: "available"
            ),
            
            GlassItemModel(
                natural_key: "spectrum-240-0",
                name: "Orange COE96",
                sku: "240",
                manufacturer: "spectrum",
                mfrNotes: "Orange transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfrStatus: "available"
            )
        ]
    }
    
    /// Create standard test tags that match the glass items
    static func createStandardTestTags() -> [(itemKey: String, tags: [String])] {
        return [
            ("cim-874-0", ["brown", "gray", "coe104"]),
            ("bullseye-001-0", ["clear", "transparent", "rod", "coe90"]),
            ("bullseye-254-0", ["red", "opaque", "coe90"]),
            ("spectrum-002-0", ["blue", "transparent", "coe96"]),
            ("spectrum-125-0", ["amber", "transparent", "coe96"]),
            ("kokomo-003-0", ["green", "transparent", "coe96"]),
            ("spectrum-100-0", ["clear", "transparent", "coe96"]),
            ("bullseye-discontinued-0", ["blue", "discontinued", "coe90"]),
            ("spectrum-200-0", ["red", "transparent", "coe96"]),
            ("kokomo-210-0", ["white", "opaque", "coe96"]),
            ("spectrum-220-0", ["yellow", "transparent", "coe96"]),
            ("kokomo-230-0", ["purple", "opal", "coe96"]),
            ("spectrum-240-0", ["orange", "transparent", "coe96"])
        ]
    }
    
    /// Create standard test inventory items
    static func createStandardTestInventory() -> [InventoryModel] {
        return [
            InventoryModel(item_natural_key: "bullseye-001-0", type: "inventory", quantity: 5.0),
            InventoryModel(item_natural_key: "bullseye-254-0", type: "inventory", quantity: 3.0),
            InventoryModel(item_natural_key: "spectrum-002-0", type: "inventory", quantity: 8.0),
            InventoryModel(item_natural_key: "spectrum-125-0", type: "inventory", quantity: 2.0),
            InventoryModel(item_natural_key: "kokomo-003-0", type: "inventory", quantity: 4.0)
        ]
    }
    
    /// Set up a complete test environment with all repositories populated
    static func setupCompleteTestEnvironment() async throws -> (
        glassItemRepo: MockGlassItemRepository,
        inventoryRepo: MockInventoryRepository,
        locationRepo: MockLocationRepository,
        itemTagsRepo: MockItemTagsRepository,
        itemMinimumRepo: MockItemMinimumRepository
    ) {
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockLocationRepository()
        let itemTagsRepo = MockItemTagsRepository()
        let itemMinimumRepo = MockItemMinimumRepository()
        
        // Configure mocks for reliable testing
        glassItemRepo.simulateLatency = false
        glassItemRepo.shouldRandomlyFail = false
        glassItemRepo.suppressVerboseLogging = true
        
        // Clear any existing data - these are mock-specific methods
        glassItemRepo.clearAllData()
        inventoryRepo.clearAllData()
        locationRepo.clearAllData() 
        itemTagsRepo.clearAllData()
        itemMinimumRepo.clearAllData()
        
        // Populate with standard test data
        let glassItems = createStandardTestGlassItems()
        do {
            let _ = try await glassItemRepo.createItems(glassItems)
        } catch {
            print("Warning: Failed to create glass items: \(error)")
        }
        
        let inventory = createStandardTestInventory()
        for item in inventory {
            do {
                let _ = try await inventoryRepo.createInventory(item)
            } catch {
                print("Warning: Failed to create inventory item: \(error)")
            }
        }
        
        let tags = createStandardTestTags()
        for (itemKey, itemTags) in tags {
            for tag in itemTags {
                do {
                    try await itemTagsRepo.addTag(tag, toItem: itemKey)
                } catch {
                    print("Warning: Failed to add tag '\(tag)' to item '\(itemKey)': \(error)")
                }
            }
        }
        
        // Verify setup - use mock-specific count methods
        let itemCount = await glassItemRepo.getItemCount()
        let inventoryCount = await inventoryRepo.getInventoryCount()
        let tagCount = await itemTagsRepo.getAllTagsCount()
        
        print("Test setup complete:")
        print("- Glass items: \(itemCount)")
        print("- Inventory records: \(inventoryCount)")  
        print("- Tag assignments: \(tagCount)")
        
        return (glassItemRepo, inventoryRepo, locationRepo, itemTagsRepo, itemMinimumRepo)
    }
    
    /// Create a complete catalog service with populated test data
    static func createTestCatalogService() async throws -> CatalogService {
        let (glassItemRepo, inventoryRepo, locationRepo, itemTagsRepo, itemMinimumRepo) = try await setupCompleteTestEnvironment()
        
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
    
    /// Create a complete inventory tracking service with populated test data
    static func createTestInventoryTrackingService() async throws -> InventoryTrackingService {
        let (glassItemRepo, inventoryRepo, locationRepo, itemTagsRepo, _) = try await setupCompleteTestEnvironment()
        
        return InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            inventoryRepository: inventoryRepo,
            locationRepository: locationRepo,
            itemTagsRepository: itemTagsRepo
        )
    }
}

// Note: This setup requires mock repositories to have these methods:
// - MockGlassItemRepository: simulateLatency, shouldRandomlyFail, suppressVerboseLogging, clearAllData(), getItemCount()
// - MockInventoryRepository: clearAllData(), getInventoryCount()
// - MockLocationRepository: clearAllData()  
// - MockItemTagsRepository: clearAllData(), getAllTagsCount()
// - MockItemMinimumRepository: clearAllData()