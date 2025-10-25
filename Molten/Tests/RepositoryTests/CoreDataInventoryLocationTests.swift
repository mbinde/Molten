//
//  CoreDataInventoryLocationTests.swift
//  RepositoryTests
//
//  Tests for Core Data inventory location persistence
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data Inventory Location Tests")
struct CoreDataInventoryLocationTests {

    @Test("Core Data persists location field")
    func testCoreDataPersistsLocation() async throws {
        // Setup - use isolated test controller
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        // Test
        let created = try await repository.createInventory(
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 10, location: "Shelf A")
        )

        // Verify - fetch from Core Data
        let fetched = try await repository.fetchInventory(byId: created.id)
        #expect(fetched != nil)
        #expect(fetched?.location == "Shelf A")
        #expect(fetched?.quantity == 10)
    }

    @Test("Core Data handles nil location")
    func testCoreDataHandlesNilLocation() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        // Test
        let created = try await repository.createInventory(
            InventoryModel(item_stable_id: "test-item", type: "rod", quantity: 10, location: nil)
        )

        // Verify
        let fetched = try await repository.fetchInventory(byId: created.id)
        #expect(fetched != nil)
        #expect(fetched?.location == nil)
    }

    @Test("Core Data fetchInventory(atLocation:) works correctly")
    func testCoreDataFetchAtLocation() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
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
    }

    @Test("Core Data getDistinctLocations works correctly")
    func testCoreDataGetDistinctLocations() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        // Create inventory
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
        let locations = try await repository.getDistinctLocations()

        // Verify
        #expect(locations.count == 2)
        #expect(locations.contains("Shelf A"))
        #expect(locations.contains("Shelf B"))
    }

    @Test("Core Data getLocationNames(withPrefix:) case-insensitive search")
    func testCoreDataGetLocationNamesWithPrefix() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item2", type: "rod", quantity: 3, location: "Shelf B")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item3", type: "sheet", quantity: 2, location: "Bin 1")
        )

        // Test with case-insensitive prefix
        let shelfLocations = try await repository.getLocationNames(withPrefix: "shelf")

        // Verify
        #expect(shelfLocations.count == 2)
        #expect(shelfLocations.contains("Shelf A"))
        #expect(shelfLocations.contains("Shelf B"))
    }

    @Test("Core Data getLocationUtilization calculates correctly")
    func testCoreDataGetLocationUtilization() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        // Create multiple items at same location
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
    }

    @Test("Core Data getAllLocationUtilization works correctly")
    func testCoreDataGetAllLocationUtilization() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item2", type: "rod", quantity: 3, location: "Shelf A")
        )
        _ = try await repository.createInventory(
            InventoryModel(item_stable_id: "item3", type: "sheet", quantity: 10, location: "Shelf B")
        )

        // Test
        let utilization = try await repository.getAllLocationUtilization()

        // Verify
        #expect(utilization["Shelf A"] == 8.0)
        #expect(utilization["Shelf B"] == 10.0)
    }

    @Test("Core Data update preserves location")
    func testCoreDataUpdatePreservesLocation() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        let created = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )

        // Test - update quantity
        let updated = InventoryModel(
            id: created.id,
            item_stable_id: created.item_stable_id,
            type: created.type,
            quantity: 10,
            location: "Shelf A",
            date_added: created.date_added,
            date_modified: Date()
        )

        _ = try await repository.updateInventory(updated)

        // Verify
        let fetched = try await repository.fetchInventory(byId: created.id)
        #expect(fetched?.location == "Shelf A")
        #expect(fetched?.quantity == 10)
    }

    @Test("Core Data handles multiple records same item different locations")
    func testCoreDataMultipleLocationsSameItem() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        // Create same item/type at different locations
        let inv1 = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )
        let inv2 = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 3, location: "Shelf B")
        )

        // Verify both exist as separate records
        let allInventory = try await repository.fetchInventory(forItem: "item1")
        #expect(allInventory.count == 2)
        #expect(allInventory.contains { $0.id == inv1.id })
        #expect(allInventory.contains { $0.id == inv2.id })

        // Verify total
        let total = try await repository.getTotalQuantity(forItem: "item1", type: "rod")
        #expect(total == 8.0)
    }

    @Test("Core Data delete removes location data")
    func testCoreDataDeleteRemovesLocation() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        let created = try await repository.createInventory(
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A")
        )

        // Verify it exists
        let beforeDelete = try await repository.fetchInventory(atLocation: "Shelf A")
        #expect(beforeDelete.count == 1)

        // Test - delete
        try await repository.deleteInventory(id: created.id)

        // Verify it's gone
        let afterDelete = try await repository.fetchInventory(atLocation: "Shelf A")
        #expect(afterDelete.isEmpty)

        let distinctLocations = try await repository.getDistinctLocations()
        #expect(!distinctLocations.contains("Shelf A"))
    }

    @Test("Core Data batch create preserves locations")
    func testCoreDataBatchCreateWithLocations() async throws {
        // Setup
        RepositoryFactory.configureForTestingWithCoreData()
        let repository = RepositoryFactory.createInventoryRepository()

        let inventories = [
            InventoryModel(item_stable_id: "item1", type: "rod", quantity: 5, location: "Shelf A"),
            InventoryModel(item_stable_id: "item2", type: "rod", quantity: 3, location: "Shelf B"),
            InventoryModel(item_stable_id: "item3", type: "sheet", quantity: 2, location: "Shelf A")
        ]

        // Test
        let created = try await repository.createInventories(inventories)

        // Verify
        #expect(created.count == 3)
        #expect(created.allSatisfy { $0.location != nil })

        let shelfAInventory = try await repository.fetchInventory(atLocation: "Shelf A")
        #expect(shelfAInventory.count == 2)

        let locations = try await repository.getDistinctLocations()
        #expect(locations.count == 2)
    }
}
