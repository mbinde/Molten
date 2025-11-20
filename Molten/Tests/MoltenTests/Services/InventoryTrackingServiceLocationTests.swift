//
//  InventoryTrackingServiceLocationTests.swift
//  MoltenTests
//
//  Tests for InventoryTrackingService location handling
//

import Testing
import Foundation
import CryptoKit
@testable import Molten

@Suite("Inventory Tracking Service Location Tests", .serialized)
@MainActor
struct InventoryTrackingServiceLocationTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())


    @Test("addInventory creates inventory with location")
    func testAddInventoryWithLocation() async throws {
        // Setup
        let catalogService = deps.catalogService
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Test
        let inventory = try await service.addInventory(
            quantity: 10,
            type: "rod",
            toItem: stableId,
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
        let catalogService = deps.catalogService
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Test - no location specified
        let inventory = try await service.addInventory(
            quantity: 10,
            type: "rod",
            toItem: stableId
        )

        // Verify
        #expect(inventory.location == nil)
        #expect(inventory.quantity == 10)
    }

    @Test("Add inventory with multiple locations to catalog item")
    func testAddInventoryWithMultipleLocations() async throws {
        // Setup
        let catalogService = deps.catalogService
        let inventoryRepo = deps.inventoryRepository
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Test - add inventory to multiple locations
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: stableId, type: "sheet", quantity: 2, location: "Shelf B")
        )

        let completeItem = try await service.getCompleteItem(stableId: stableId)

        // Verify
        #expect(completeItem?.inventory.count == 2)
        #expect(completeItem?.inventory.contains { $0.location == "Shelf A" && $0.type == "rod" } == true)
        #expect(completeItem?.inventory.contains { $0.location == "Shelf B" && $0.type == "sheet" } == true)
        #expect(completeItem?.locations.count == 2)
        #expect(completeItem?.locations.contains("Shelf A") == true)
        #expect(completeItem?.locations.contains("Shelf B") == true)
    }

    @Test("getCompleteItem includes location information")
    func testGetCompleteItemWithLocations() async throws {
        // Setup
        let catalogService = deps.catalogService
        let inventoryRepo = deps.inventoryRepository
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Create inventory with locations
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 3, location: "Shelf B")
        )

        // Test
        let completeItem = try await service.getCompleteItem(stableId: stableId)

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
        let catalogService = deps.catalogService
        let inventoryRepo = deps.inventoryRepository
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Create inventory with locations
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 3, location: "Shelf B")
        )
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: stableId, type: "sheet", quantity: 2, location: "Shelf A")
        )

        // Test
        let summary = try await service.getInventorySummary(for: stableId)

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
        let catalogService = deps.catalogService
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Test - add same type to multiple locations
        let inv1 = try await service.addInventory(
            quantity: 5,
            type: "rod",
            toItem: stableId,
            atLocation: "Shelf A"
        )

        let inv2 = try await service.addInventory(
            quantity: 3,
            type: "rod",
            toItem: stableId,
            atLocation: "Shelf B"
        )

        // Verify - should create separate inventory records
        #expect(inv1.id != inv2.id)
        #expect(inv1.location == "Shelf A")
        #expect(inv2.location == "Shelf B")

        // Verify total quantity
        let completeItem = try await service.getCompleteItem(stableId: stableId)
        #expect(completeItem?.totalQuantity == 8.0)
        #expect(completeItem?.inventory.count == 2)
    }

    @Test("validateInventoryConsistency checks for negative quantities")
    func testValidateInventoryConsistency() async throws {
        // Setup
        let catalogService = deps.catalogService
        let inventoryRepo = deps.inventoryRepository
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Create valid inventory
        _ = try await inventoryRepo.createInventory(
            InventoryModel(item_stable_id: stableId, type: "rod", quantity: 5, location: "Shelf A")
        )

        // Test - should be valid
        let validation = try await service.validateInventoryConsistency(for: stableId)
        #expect(validation.isValid == true)
        #expect(validation.errors.isEmpty)
    }

    @Test("Inventory without location is valid")
    func testInventoryWithoutLocationIsValid() async throws {
        // Setup
        let catalogService = deps.catalogService
        let service = deps.inventoryTrackingService

        // Use real catalog data (catalog is read-only)
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let glassItem = try catalogItems.first(where: { $0.sku != nil })!
        let stableId = glassItem.stable_id

        // Add inventory without location
        _ = try await service.addInventory(
            quantity: 10,
            type: "rod",
            toItem: stableId,
            atLocation: nil
        )

        // Verify
        let completeItem = try await service.getCompleteItem(stableId: stableId)
        #expect(completeItem?.inventory.count == 1)
        #expect(completeItem?.inventory.first?.location == nil)
        #expect(completeItem?.locations.isEmpty == true) // No locations since location is nil
    }
}
