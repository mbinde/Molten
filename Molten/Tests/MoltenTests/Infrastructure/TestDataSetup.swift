//
//  TestDataSetup.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/15/25.
//  Centralized test data setup to ensure consistent test data across all test files
//

import Foundation
import CryptoKit
@testable import Molten

/// Centralized test data setup utilities
struct TestDataSetup {

    /// Create standard test glass items that all tests can expect
    static func createStandardTestGlassItems() -> [GlassItemModel] {
        return [
            // CIM manufacturer items
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "cim", sku: "874"),
                name: "Adamantium",
                sku: "874",
                manufacturer: "cim",
                mfr_notes: "A brown gray color",
                coe: 104,
                url: "https://creationismessy.com",
                mfr_status: "available"
            ),

            // Bullseye manufacturer items
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "bullseye", sku: "001"),
                name: "Bullseye Clear Rod 5mm",
                sku: "001",
                manufacturer: "bullseye",
                mfr_notes: "Clear transparent rod",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfr_status: "available"
            ),

            GlassItemModel(
                stable_id: generateStableId(manufacturer: "bullseye", sku: "254"),
                name: "Red",
                sku: "254",
                manufacturer: "bullseye",
                mfr_notes: "Bright red opaque",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfr_status: "available"
            ),

            // Spectrum manufacturer items
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "spectrum", sku: "002"),
                name: "Blue",
                sku: "002",
                manufacturer: "spectrum",
                mfr_notes: "Deep blue transparent",
                coe: 96,
                url: "https://spectrumglass.com",
                mfr_status: "available"
            ),

            GlassItemModel(
                stable_id: generateStableId(manufacturer: "spectrum", sku: "125"),
                name: "Medium Amber",
                sku: "125",
                manufacturer: "spectrum",
                mfr_notes: "Amber transparent",
                coe: 96,
                url: "https://spectrumglass.com",
                mfr_status: "available"
            ),

            // Kokomo manufacturer items
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "kokomo", sku: "003"),
                name: "Green Glass",
                sku: "003",
                manufacturer: "kokomo",
                mfr_notes: "Green transparent",
                coe: 96,
                url: "https://kokomoglass.com",
                mfr_status: "available"
            ),

            // Additional items for comprehensive search testing
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "spectrum", sku: "100"),
                name: "Clear",
                sku: "100",
                manufacturer: "spectrum",
                mfr_notes: "Crystal clear",
                coe: 96,
                url: "https://spectrumglass.com",
                mfr_status: "available"
            ),

            GlassItemModel(
                stable_id: generateStableId(manufacturer: "bullseye", sku: "discontinued"),
                name: "Old Blue",
                sku: "discontinued",
                manufacturer: "bullseye",
                mfr_notes: "No longer made",
                coe: 90,
                url: "https://bullseyeglass.com",
                mfr_status: "discontinued"
            ),

            // More COE 96 items for search tests
            GlassItemModel(
                stable_id: generateStableId(manufacturer: "spectrum", sku: "200"),
                name: "Red COE96",
                sku: "200",
                manufacturer: "spectrum",
                mfr_notes: "Red transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfr_status: "available"
            ),

            GlassItemModel(
                stable_id: generateStableId(manufacturer: "kokomo", sku: "210"),
                name: "White COE96",
                sku: "210",
                manufacturer: "kokomo",
                mfr_notes: "White opaque COE96",
                coe: 96,
                url: "https://kokomoglass.com",
                mfr_status: "available"
            ),

            GlassItemModel(
                stable_id: generateStableId(manufacturer: "spectrum", sku: "220"),
                name: "Yellow COE96",
                sku: "220",
                manufacturer: "spectrum",
                mfr_notes: "Yellow transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfr_status: "available"
            ),

            GlassItemModel(
                stable_id: generateStableId(manufacturer: "kokomo", sku: "230"),
                name: "Purple COE96",
                sku: "230",
                manufacturer: "kokomo",
                mfr_notes: "Purple opal COE96",
                coe: 96,
                url: "https://kokomoglass.com",
                mfr_status: "available"
            ),

            GlassItemModel(
                stable_id: generateStableId(manufacturer: "spectrum", sku: "240"),
                name: "Orange COE96",
                sku: "240",
                manufacturer: "spectrum",
                mfr_notes: "Orange transparent COE96",
                coe: 96,
                url: "https://spectrumglass.com",
                mfr_status: "available"
            )
        ]
    }

    /// Create standard test tags that match the glass items
    static func createStandardTestTags() -> [(itemKey: String, tags: [String])] {
        return [
            (generateStableId(manufacturer: "cim", sku: "874"), ["brown", "gray", "coe104"]),
            (generateStableId(manufacturer: "bullseye", sku: "001"), ["clear", "transparent", "rod", "coe90"]),
            (generateStableId(manufacturer: "bullseye", sku: "254"), ["red", "opaque", "coe90"]),
            (generateStableId(manufacturer: "spectrum", sku: "002"), ["blue", "transparent", "coe96"]),
            (generateStableId(manufacturer: "spectrum", sku: "125"), ["amber", "transparent", "coe96"]),
            (generateStableId(manufacturer: "kokomo", sku: "003"), ["green", "transparent", "coe96"]),
            (generateStableId(manufacturer: "spectrum", sku: "100"), ["clear", "transparent", "coe96"]),
            (generateStableId(manufacturer: "bullseye", sku: "discontinued"), ["blue", "discontinued", "coe90"]),
            (generateStableId(manufacturer: "spectrum", sku: "200"), ["red", "transparent", "coe96"]),
            (generateStableId(manufacturer: "kokomo", sku: "210"), ["white", "opaque", "coe96"]),
            (generateStableId(manufacturer: "spectrum", sku: "220"), ["yellow", "transparent", "coe96"]),
            (generateStableId(manufacturer: "kokomo", sku: "230"), ["purple", "opal", "coe96"]),
            (generateStableId(manufacturer: "spectrum", sku: "240"), ["orange", "transparent", "coe96"])
        ]
    }

    /// Create standard test inventory items
    static func createStandardTestInventory() -> [InventoryModel] {
        return [
            InventoryModel(item_stable_id: generateStableId(manufacturer: "bullseye", sku: "001"), type: "inventory", quantity: 5.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "bullseye", sku: "254"), type: "inventory", quantity: 3.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "spectrum", sku: "002"), type: "inventory", quantity: 8.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "spectrum", sku: "125"), type: "inventory", quantity: 2.0),
            InventoryModel(item_stable_id: generateStableId(manufacturer: "kokomo", sku: "003"), type: "inventory", quantity: 4.0)
        ]
    }

    /// Set up a complete test environment with all repositories populated
    static func setupCompleteTestEnvironment() async throws -> (
        glassItemRepo: MockGlassItemRepository,
        inventoryRepo: MockInventoryRepository,
        locationRepo: MockStorageLocationRepository,
        itemTagsRepo: MockItemTagsRepository,
        itemMinimumRepo: MockItemMinimumRepository
    ) {
        let glassItemRepo = MockGlassItemRepository()
        let inventoryRepo = MockInventoryRepository()
        let locationRepo = MockStorageLocationRepository()
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
        let userTagsRepo = MockUserTagsRepository()
        let coatingItemRepo = MockCoatingItemRepository()
        let toolItemRepo = MockToolItemRepository()
        let locationDefinitionRepo = MockStorageLocationDefinitionRepository()
        let moveRecordRepo = MockInventoryMoveRecordRepository()
        let consumptionRecordRepo = MockInventoryConsumptionRecordRepository()

        let storageLocationService = await StorageLocationService(
            definitionRepository: locationDefinitionRepo,
            storageLocationRepository: locationRepo,
            moveRecordRepository: moveRecordRepo,
            consumptionRecordRepository: consumptionRecordRepo
        )

        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryRepository: inventoryRepo,
            itemTagsRepository: itemTagsRepo,
            storageLocationDefinitionRepository: locationDefinitionRepo,
            storageLocationRepository: locationRepo,
            storageLocationService: storageLocationService
        )

        let catalogService = await CatalogService(
            glassItemRepository: glassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryTrackingService: inventoryTrackingService,
            itemMinimumRepository: itemMinimumRepo,
            itemTagsRepository: itemTagsRepo,
            userTagsRepository: userTagsRepo,
            ratingService: AppDependencies.shared.ratingService,
            storageLocationRepository: locationRepo
        )

        return catalogService
    }

    /// Create a complete inventory tracking service with populated test data
    static func createTestInventoryTrackingService() async throws -> InventoryTrackingService {
        let (glassItemRepo, inventoryRepo, locationRepo, itemTagsRepo, _) = try await setupCompleteTestEnvironment()
        let coatingItemRepo = MockCoatingItemRepository()
        let toolItemRepo = MockToolItemRepository()
        let locationDefinitionRepo = MockStorageLocationDefinitionRepository()
        let moveRecordRepo = MockInventoryMoveRecordRepository()
        let consumptionRecordRepo = MockInventoryConsumptionRecordRepository()

        let storageLocationService = await StorageLocationService(
            definitionRepository: locationDefinitionRepo,
            storageLocationRepository: locationRepo,
            moveRecordRepository: moveRecordRepo,
            consumptionRecordRepository: consumptionRecordRepo
        )

        let inventoryTrackingService = InventoryTrackingService(
            glassItemRepository: glassItemRepo,
            coatingItemRepository: coatingItemRepo,
            toolItemRepository: toolItemRepo,
            inventoryRepository: inventoryRepo,
            itemTagsRepository: itemTagsRepo,
            storageLocationDefinitionRepository: locationDefinitionRepo,
            storageLocationRepository: locationRepo,
            storageLocationService: storageLocationService
        )

        return inventoryTrackingService
    }
}

// Note: This setup requires mock repositories to have these methods:
// - MockGlassItemRepository: simulateLatency, shouldRandomlyFail, suppressVerboseLogging, clearAllData(), getItemCount()
// - MockInventoryRepository: clearAllData(), getInventoryCount()
// - MockStorageLocationRepository: clearAllData()
// - MockItemTagsRepository: clearAllData(), getAllTagsCount()
// - MockItemMinimumRepository: clearAllData()
