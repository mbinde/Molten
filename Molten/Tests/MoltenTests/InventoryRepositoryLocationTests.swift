//
//  InventoryRepositoryLocationTests.swift
//  MoltenTests
//
//  Tests for InventoryRepository location methods
//

import Testing
import Foundation
@testable import Molten

@Suite("Inventory Repository Location Tests")
struct InventoryRepositoryLocationTests {

    @Test("fetchInventory(atLocation:) returns inventory at specific location")
    func testFetchInventoryAtLocation() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        // Create inventory at different locations
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item2", type: "rod", quantity: 3, location: "Shelf B")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item3", type: "sheet", quantity: 2, location: "Shelf A")
        )

        // Test
        let shelfAInventory = try await repository.fetchInventory(atLocation: "Shelf A")

        // Verify
        #expect(shelfAInventory.count == 2)
        #expect(shelfAInventory.allSatisfy { $0.location == "Shelf A" })
        #expect(shelfAInventory.contains { $0.item_stable_id == "item1" })
        #expect(shelfAInventory.contains { $0.item_stable_id == "item3" })
    }

    @Test("fetchInventory(atLocation:) handles whitespace normalization")
    func testFetchInventoryAtLocationNormalization() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )

        // Test with extra whitespace
        let inventory = try await repository.fetchInventory(atLocation: "  Shelf A  ")

        // Verify
        #expect(inventory.count == 1)
        #expect(inventory.first?.location == "Shelf A")
    }

    @Test("getDistinctLocations returns unique location names")
    func testGetDistinctLocations() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        // Create inventory at various locations
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item2", type: "rod", quantity: 3, location: "Shelf B")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item3", type: "sheet", quantity: 2, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item4", type: "frit", quantity: 1, location: nil)
        )

        // Test
        let locations = try await repository.getDistinctLocations()

        // Verify
        #expect(locations.count == 2)
        #expect(locations.contains("Shelf A"))
        #expect(locations.contains("Shelf B"))
        #expect(!locations.contains(where: { $0.isEmpty })) // nil location not included
    }

    @Test("getLocationNames(withPrefix:) filters by prefix")
    func testGetLocationNamesWithPrefix() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        // Create inventory at various locations
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item2", type: "rod", quantity: 3, location: "Shelf B")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item3", type: "sheet", quantity: 2, location: "Bin 1")
        )

        // Test
        let shelfLocations = try await repository.getLocationNames(withPrefix: "Shelf")

        // Verify
        #expect(shelfLocations.count == 2)
        #expect(shelfLocations.contains("Shelf A"))
        #expect(shelfLocations.contains("Shelf B"))
        #expect(!shelfLocations.contains("Bin 1"))
    }

    @Test("getLocationNames(withPrefix:) is case-insensitive")
    func testGetLocationNamesWithPrefixCaseInsensitive() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )

        // Test with lowercase prefix
        let locations = try await repository.getLocationNames(withPrefix: "shelf")

        // Verify
        #expect(locations.count == 1)
        #expect(locations.contains("Shelf A"))
    }

    @Test("getLocationUtilization(for:) calculates quantities per item")
    func testGetLocationUtilization() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        // Create inventory for multiple items at same location
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item2", type: "rod", quantity: 3, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "sheet", quantity: 2, location: "Shelf A")
        )

        // Test
        let utilization = try await repository.getLocationUtilization(for: "Shelf A")

        // Verify
        #expect(utilization["item1"] == 7.0) // 5 rods + 2 sheets
        #expect(utilization["item2"] == 3.0)
        #expect(utilization.count == 2)
    }

    @Test("getAllLocationUtilization returns totals for all locations")
    func testGetAllLocationUtilization() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        // Create inventory at various locations
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item2", type: "rod", quantity: 3, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item3", type: "sheet", quantity: 10, location: "Shelf B")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item4", type: "frit", quantity: 2, location: nil)
        )

        // Test
        let utilization = try await repository.getAllLocationUtilization()

        // Verify
        #expect(utilization["Shelf A"] == 8.0) // 5 + 3
        #expect(utilization["Shelf B"] == 10.0)
        #expect(utilization.count == 2) // nil location not included
    }

    @Test("createInventory preserves location field")
    func testCreateInventoryPreservesLocation() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        // Test
        let created = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )

        // Verify
        #expect(created.location == "Shelf A")

        // Fetch and verify persistence
        let fetched = try await repository.fetchInventory(byId: created.id)
        #expect(fetched?.location == "Shelf A")
    }

    @Test("updateInventory preserves location field")
    func testUpdateInventoryPreservesLocation() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        let created = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )

        // Test - update quantity but keep location
        let updated = InventoryModel(
            id: created.id,
            item_stable_id: created.item_stable_id,
            type: created.type,
            quantity: 10,
            location: "Shelf A",
            date_added: created.date_added,
            date_modified: Date()
        )

        let result = try await repository.updateInventory(updated)

        // Verify
        #expect(result.location == "Shelf A")
        #expect(result.quantity == 10)
    }

    @Test("Multiple inventory records for same item at different locations")
    func testMultipleRecordsDifferentLocations() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        // Test - same item, same type, different locations
        let inv1 = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        let inv2 = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 3, location: "Shelf B")
        )

        // Verify both exist
        let allInventory = try await repository.fetchInventory(forItem: "item1")
        #expect(allInventory.count == 2)
        #expect(allInventory.contains { $0.id == inv1.id && $0.location == "Shelf A" })
        #expect(allInventory.contains { $0.id == inv2.id && $0.location == "Shelf B" })

        // Verify total quantity
        let total = try await repository.getTotalQuantity(forItem: "item1", type: "rod")
        #expect(total == 8.0)
    }

    @Test("Multiple inventory records for same item/location with different types")
    func testMultipleRecordsSameLocationDifferentTypes() async throws {
        // Setup
        RepositoryFactory.configureForTesting()
        let repository = RepositoryFactory.createInventoryRepository()

        // Test - same item, same location, different types
        let inv1 = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        let inv2 = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "sheet", quantity: 2, location: "Shelf A")
        )

        // Verify both exist
        let allInventory = try await repository.fetchInventory(forItem: "item1")
        #expect(allInventory.count == 2)

        // Verify location utilization
        let utilization = try await repository.getLocationUtilization(for: "Shelf A")
        #expect(utilization["item1"] == 7.0) // 5 rods + 2 sheets
    }
}
