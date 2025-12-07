//
//  CoreDataStorageLocationRepositoryTests.swift
//  Molten
//
//  Created by Assistant on 10/19/25.
//
// Target: RepositoryTests

#if canImport(Testing)
import Testing
import Foundation
import CoreData
@testable import Molten

/// Tests for CoreDataStorageLocationRepository to verify Core Data operations work correctly
///
/// StorageLocation records are uniquely identified by their 'id' field, and are linked to
/// inventory via 'inventory_id'. Records include 'is_transfer' flag and 'date_added' for audit trails.
@Suite("CoreDataStorageLocationRepository Tests")
@MainActor
struct CoreDataStorageLocationRepositoryTests {

    let testController: PersistenceController
    let repository: CoreDataStorageLocationRepository
    let inventoryId: UUID

    init() async throws {
        // Create isolated test container
        testController = PersistenceController.createTestController()

        // Create repository with test container
        repository = CoreDataStorageLocationRepository(context: testController.container.viewContext)

        // Create a test inventory ID that we'll use across tests
        inventoryId = UUID()
    }

    // MARK: - Core Data Entity Structure Tests

    @Test("StorageLocation entity has required attributes")
    func testLocationEntityHasRequiredAttributes() async throws {
        let context = testController.container.viewContext

        guard let entity = NSEntityDescription.entity(forEntityName: "StorageLocation", in: context) else {
            Issue.record("StorageLocation entity not found")
            return
        }

        // Verify it has the expected attributes for tracking individual storage records
        #expect(entity.attributesByName.keys.contains("id"), "Should have id for unique record identification")
        #expect(entity.attributesByName.keys.contains("inventory_id"), "Should have inventory_id to link to inventory")
        #expect(entity.attributesByName.keys.contains("location"), "Should have location name")
        #expect(entity.attributesByName.keys.contains("quantity"), "Should have quantity")
        #expect(entity.attributesByName.keys.contains("is_transfer"), "Should have is_transfer flag for move tracking")
        #expect(entity.attributesByName.keys.contains("date_added"), "Should have date_added for audit trail")
    }

    // MARK: - CRUD Operations

    @Test("Create location without id field")
    func testCreateLocationWithoutId() async throws {
        let location = StorageLocationModel(
            inventoryId: inventoryId,
            locationName: "Studio",
            quantity: 10.0
        )

        let created = try await repository.createLocation(location)

        // Verify the location was created
        #expect(created.inventoryId == inventoryId)
        #expect(created.locationName == "Studio")
        #expect(created.quantity == 10.0)

        // Verify we can fetch it back
        let fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.count == 1)
        #expect(fetched.first?.locationName == "Studio")
    }

    @Test("Create multiple locations for same inventory")
    func testCreateMultipleLocationsForSameInventory() async throws {
        let location1 = StorageLocationModel(inventoryId: inventoryId, locationName: "Studio", quantity: 5.0)
        let location2 = StorageLocationModel(inventoryId: inventoryId, locationName: "Storage", quantity: 15.0)

        _ = try await repository.createLocation(location1)
        _ = try await repository.createLocation(location2)

        let fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.count == 2)

        let locations = Set(fetched.map { $0.locationName })
        #expect(locations.contains("Studio"))
        #expect(locations.contains("Storage"))
    }

    @Test("Update location using composite key")
    func testUpdateLocationUsingCompositeKey() async throws {
        // Create initial location
        let original = StorageLocationModel(inventoryId: inventoryId, locationName: "Studio", quantity: 10.0)
        _ = try await repository.createLocation(original)

        // Update using inventory_id + location name (composite key)
        let updated = StorageLocationModel(inventoryId: inventoryId, locationName: "Studio", quantity: 25.0)
        let result = try await repository.updateLocation(updated)

        #expect(result.quantity == 25.0)

        // Verify only one location exists
        let fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.count == 1)
        #expect(fetched.first?.quantity == 25.0)
    }

    @Test("Delete location using composite key")
    func testDeleteLocationUsingCompositeKey() async throws {
        // Create location
        let location = StorageLocationModel(inventoryId: inventoryId, locationName: "Studio", quantity: 10.0)
        _ = try await repository.createLocation(location)

        // Verify it exists
        var fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.count == 1)

        // Delete it
        try await repository.deleteLocation(location)

        // Verify it's gone
        fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.isEmpty)
    }

    @Test("Add quantity to location")
    func testAddQuantityToLocation() async throws {
        // Add quantity to non-existent location (should create it)
        let created = try await repository.addQuantity(10.0, toLocation: "Studio", forInventory: inventoryId)
        #expect(created.quantity == 10.0)

        // Add more quantity to existing location
        let updated = try await repository.addQuantity(5.0, toLocation: "Studio", forInventory: inventoryId)
        #expect(updated.quantity == 15.0)

        // Verify only one location record exists
        let fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.count == 1)
    }

    @Test("Subtract quantity from location")
    func testSubtractQuantityFromLocation() async throws {
        // Create location with initial quantity
        _ = try await repository.addQuantity(20.0, toLocation: "Studio", forInventory: inventoryId)

        // Subtract some quantity
        let updated = try await repository.subtractQuantity(5.0, fromLocation: "Studio", forInventory: inventoryId)
        #expect(updated?.quantity == 15.0)

        // Subtract remaining quantity (should delete the record)
        let deleted = try await repository.subtractQuantity(15.0, fromLocation: "Studio", forInventory: inventoryId)
        #expect(deleted == nil, "Location should be deleted when quantity reaches zero")

        // Verify location no longer exists
        let fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.isEmpty)
    }

    @Test("Move quantity between locations")
    func testMoveQuantityBetweenLocations() async throws {
        // Create initial location
        _ = try await repository.addQuantity(20.0, toLocation: "Studio", forInventory: inventoryId)

        // Move some quantity to storage
        try await repository.moveQuantity(8.0, fromLocation: "Studio", toLocation: "Storage", forInventory: inventoryId)

        let fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.count == 2)

        let studio = fetched.first { $0.locationName == "Studio" }
        let storage = fetched.first { $0.locationName == "Storage" }

        #expect(studio?.quantity == 12.0)
        #expect(storage?.quantity == 8.0)
    }

    @Test("Set locations replaces all existing locations")
    func testSetLocationsReplacesAll() async throws {
        // Create initial locations
        _ = try await repository.addQuantity(10.0, toLocation: "Studio", forInventory: inventoryId)
        _ = try await repository.addQuantity(5.0, toLocation: "Storage", forInventory: inventoryId)

        // Set new locations (should replace everything)
        let newLocations: [(location: String, quantity: Double)] = [
            ("Shelf A", 7.0),
            ("Shelf B", 13.0)
        ]
        try await repository.setLocations(newLocations, forInventory: inventoryId)

        let fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.count == 2)

        let locationNames = Set(fetched.map { $0.locationName })
        #expect(locationNames.contains("Shelf A"))
        #expect(locationNames.contains("Shelf B"))
        #expect(!locationNames.contains("Studio"))
        #expect(!locationNames.contains("Storage"))
    }

    // MARK: - Discovery Operations

    @Test("Get distinct location names")
    func testGetDistinctLocationNames() async throws {
        let inventoryId1 = UUID()
        let inventoryId2 = UUID()

        // Create locations for different inventory items with some duplicate names
        _ = try await repository.addQuantity(10.0, toLocation: "Studio", forInventory: inventoryId1)
        _ = try await repository.addQuantity(5.0, toLocation: "Studio", forInventory: inventoryId2)
        _ = try await repository.addQuantity(8.0, toLocation: "Storage", forInventory: inventoryId1)

        let distinctNames = try await repository.getDistinctLocationNames()
        #expect(distinctNames.count == 2)
        #expect(distinctNames.contains("Studio"))
        #expect(distinctNames.contains("Storage"))
    }

    @Test("Get location names with prefix")
    func testGetLocationNamesWithPrefix() async throws {
        _ = try await repository.addQuantity(10.0, toLocation: "Studio A", forInventory: inventoryId)
        _ = try await repository.addQuantity(5.0, toLocation: "Studio B", forInventory: UUID())
        _ = try await repository.addQuantity(8.0, toLocation: "Storage", forInventory: UUID())

        let studioLocations = try await repository.getLocationNames(withPrefix: "Stu")
        #expect(studioLocations.count == 2)
        #expect(studioLocations.contains("Studio A"))
        #expect(studioLocations.contains("Studio B"))

        let storageLocations = try await repository.getLocationNames(withPrefix: "Stor")
        #expect(storageLocations.count == 1)
        #expect(storageLocations.contains("Storage"))
    }

    @Test("Get inventories in location")
    func testGetInventoriesInLocation() async throws {
        let inventoryId1 = UUID()
        let inventoryId2 = UUID()
        let inventoryId3 = UUID()

        // Create locations
        _ = try await repository.addQuantity(10.0, toLocation: "Studio", forInventory: inventoryId1)
        _ = try await repository.addQuantity(5.0, toLocation: "Studio", forInventory: inventoryId2)
        _ = try await repository.addQuantity(8.0, toLocation: "Storage", forInventory: inventoryId3)

        let studioInventories = try await repository.getInventoriesInLocation("Studio")
        #expect(studioInventories.count == 2)
        #expect(studioInventories.contains(inventoryId1))
        #expect(studioInventories.contains(inventoryId2))

        let storageInventories = try await repository.getInventoriesInLocation("Storage")
        #expect(storageInventories.count == 1)
        #expect(storageInventories.contains(inventoryId3))
    }

    // MARK: - Data Validation

    @Test("Quantity stored as Double in Core Data")
    func testQuantityStoredAsDouble() async throws {
        let location = StorageLocationModel(inventoryId: inventoryId, locationName: "Studio", quantity: 15.5)
        _ = try await repository.createLocation(location)

        // Fetch the Core Data object directly to verify quantity is stored as Double
        let context = testController.container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "StorageLocation")
        fetchRequest.predicate = NSPredicate(
            format: "inventory_id == %@ AND location == %@",
            inventoryId as CVarArg,
            "Studio"
        )

        let results = try context.fetch(fetchRequest)
        #expect(results.count == 1)

        if let coreDataObject = results.first {
            let quantityValue = coreDataObject.value(forKey: "quantity")
            #expect(quantityValue is Double, "Quantity should be stored as Double in Core Data")
            #expect(quantityValue as? Double == 15.5)
        }
    }

    @Test("Location name is trimmed and cleaned")
    func testLocationNameCleaned() async throws {
        let location = StorageLocationModel(inventoryId: inventoryId, locationName: "  Studio  ", quantity: 10.0)
        let created = try await repository.createLocation(location)

        // LocationModel should clean the location name
        #expect(created.locationName == "Studio")

        // Verify in database
        let fetched = try await repository.fetchLocations(forInventory: inventoryId)
        #expect(fetched.first?.locationName == "Studio")
    }
}

#endif // canImport(Testing)
