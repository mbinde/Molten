//
//  InventoryTrackingServiceLocationTests.swift
//  MoltenTests
//
//  Tests for InventoryTrackingService location handling
//

import Testing
import Foundation
@testable import Molten

@Suite("Inventory Tracking Service Location Tests")
struct InventoryTrackingServiceLocationTests {

    @Test("addInventory creates inventory with location")
    func testAddInventoryWithLocation() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let service = RepositoryFactory.createInventoryTrackingService()

        // Create a glass item first
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )
        _ = try await glassItemRepo.createItem(glassItem)

        // Test
        let inventory = try await service.addInventory(
            quantity: 10,
            type: "rod",
            toItem: "test-item",
            atLocation: "Shelf A"
        )

        // Verify
        #expect(inventory.location == "Shelf A")
        #expect(inventory.quantity == 10)
        #expect(inventory.type == "rod")
    }

    @Test("addInventory creates inventory without location")
    func testAddInventoryWithoutLocation() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let service = RepositoryFactory.createInventoryTrackingService()

        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )
        _ = try await glassItemRepo.createItem(glassItem)

        // Test - no location specified
        let inventory = try await service.addInventory(
            quantity: 10,
            type: "rod",
            toItem: "test-item"
        )

        // Verify
        #expect(inventory.location == nil)
        #expect(inventory.quantity == 10)
    }

    @Test("createCompleteItem with initial inventory including locations")
    func testCreateCompleteItemWithLocations() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let service = RepositoryFactory.createInventoryTrackingService()

        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )

        let initialInventory = [
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 5, location: "Shelf A"),
            InventoryModel(item_stable_id: "test-item", type: "sheet", quantity: 2, location: "Shelf B")
        ]

        // Test
        let completeItem = try await service.createCompleteItem(
            glassItem,
            initialInventory: initialInventory,
            tags: []
        )

        // Verify
        #expect(completeItem.inventory.count == 2)
        #expect(completeItem.inventory.contains { $0.location == "Shelf A" && $0.type == "rod" })
        #expect(completeItem.inventory.contains { $0.location == "Shelf B" && $0.type == "sheet" })
        #expect(completeItem.locations.count == 2)
        #expect(completeItem.locations.contains("Shelf A"))
        #expect(completeItem.locations.contains("Shelf B"))
    }

    @Test("getCompleteItem includes location information")
    func testGetCompleteItemWithLocations() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let inventoryRepo = RepositoryFactory.createInventoryRepository()
        let service = RepositoryFactory.createInventoryTrackingService()

        // Create glass item
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )
        _ = try await glassItemRepo.createItem(glassItem)

        // Create inventory with locations
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 3, location: "Shelf B")
        )

        // Test
        let completeItem = try await service.getCompleteItem(stableId: "test-item")

        // Verify
        #expect(completeItem != nil)
        #expect(completeItem?.inventory.count == 2)
        #expect(completeItem?.locations.count == 2)
        #expect(completeItem?.locations.contains("Shelf A") == true)
        #expect(completeItem?.locations.contains("Shelf B") == true)
        #expect(completeItem?.inventoryByLocation["Shelf A"] == 5.0)
        #expect(completeItem?.inventoryByLocation["Shelf B"] == 3.0)
    }

    @Test("getInventorySummary includes location details")
    func testGetInventorySummaryWithLocations() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let inventoryRepo = RepositoryFactory.createInventoryRepository()
        let service = RepositoryFactory.createInventoryTrackingService()

        // Create glass item
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )
        _ = try await glassItemRepo.createItem(glassItem)

        // Create inventory with locations
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 3, location: "Shelf B")
        )
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: "test-item", type: "sheet", quantity: 2, location: "Shelf A")
        )

        // Test
        let summary = try await service.getInventorySummary(for: "test-item")

        // Verify
        #expect(summary != nil)
        #expect(summary?.summary.totalQuantity == 10.0)
        #expect(summary?.locationDetails["rod"]?.count == 2)
        #expect(summary?.locationDetails["sheet"]?.count == 1)

        // Check rod locations
        let rodLocations = summary?.locationDetails["rod"]
        #expect(rodLocations?.contains { $0.location == "Shelf A" && $0.quantity == 5.0 } == true)
        #expect(rodLocations?.contains { $0.location == "Shelf B" && $0.quantity == 3.0 } == true)

        // Check sheet location
        let sheetLocations = summary?.locationDetails["sheet"]
        #expect(sheetLocations?.contains { $0.location == "Shelf A" && $0.quantity == 2.0 } == true)
    }

    @Test("Multiple locations for same item and type")
    func testMultipleLocationsForSameItemType() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let service = RepositoryFactory.createInventoryTrackingService()

        // Create glass item
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )
        _ = try await glassItemRepo.createItem(glassItem)

        // Test - add same type to multiple locations
        let inv1 = try await service.addInventory(
            quantity: 5,
            type: "rod",
            toItem: "test-item",
            atLocation: "Shelf A"
        )

        let inv2 = try await service.addInventory(
            quantity: 3,
            type: "rod",
            toItem: "test-item",
            atLocation: "Shelf B"
        )

        // Verify - should create separate inventory records
        #expect(inv1.id != inv2.id)
        #expect(inv1.location == "Shelf A")
        #expect(inv2.location == "Shelf B")

        // Verify total quantity
        let completeItem = try await service.getCompleteItem(stableId: "test-item")
        #expect(completeItem?.totalQuantity == 8.0)
        #expect(completeItem?.inventory.count == 2)
    }

    @Test("validateInventoryConsistency checks for negative quantities")
    func testValidateInventoryConsistency() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let inventoryRepo = RepositoryFactory.createInventoryRepository()
        let service = RepositoryFactory.createInventoryTrackingService()

        // Create glass item
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )
        _ = try await glassItemRepo.createItem(glassItem)

        // Create valid inventory
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 5, location: "Shelf A")
        )

        // Test - should be valid
        let validation = try await service.validateInventoryConsistency(for: "test-item")
        #expect(validation.isValid == true)
        #expect(validation.errors.isEmpty)
    }

    @Test("Inventory without location is valid")
    func testInventoryWithoutLocationIsValid() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let glassItemRepo = RepositoryFactory.createGlassItemRepository()
        let service = RepositoryFactory.createInventoryTrackingService()

        // Create glass item
        let glassItem = GlassItemModel(
            stable_id: "test-item",
            name: "Test Glass",
            sku: "001",
            manufacturer: "Test Mfr",
            coe: 96,
            mfr_status: "available"
        )
        _ = try await glassItemRepo.createItem(glassItem)

        // Add inventory without location
        _ = try await service.addInventory(
            quantity: 10,
            type: "rod",
            toItem: "test-item",
            atLocation: nil
        )

        // Verify
        let completeItem = try await service.getCompleteItem(stableId: "test-item")
        #expect(completeItem?.inventory.count == 1)
        #expect(completeItem?.inventory.first?.location == nil)
        #expect(completeItem?.locations.isEmpty == true) // No locations since location is nil
    }
}
