//
//  StorageLocationRepositoryTests.swift
//  RepositoryTests
//
//  Tests for StorageLocationRepository protocol, focusing on receipt import methods.
//

import Testing
import Foundation
@testable import Molten

@Suite("StorageLocationRepository Tests", .serialized)
@MainActor
struct StorageLocationRepositoryTests {

    // MARK: - Test Helpers

    private func createTestLocation(
        inventoryId: UUID,
        locationName: String = "Test Location",
        quantity: Double = 10.0,
        dateAdded: Date = Date(),
        purchaseRecordItemId: UUID? = nil,
        unitPrice: Decimal? = nil,
        currency: String? = nil
    ) -> StorageLocationModel {
        return StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: locationName,
            quantity: quantity,
            dateAdded: dateAdded,
            dateModified: dateAdded,
            purchaseRecordItemId: purchaseRecordItemId,
            unitPrice: unitPrice,
            currency: currency
        )
    }

    // MARK: - Fetch Location by ID Tests

    @Test("Can fetch location by ID")
    func testFetchLocationById() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()
        let location = createTestLocation(inventoryId: inventoryId, locationName: "Shelf A")

        _ = try await repository.createLocation(location)

        let fetched = try await repository.fetchLocation(byId: location.id)

        #expect(fetched != nil)
        #expect(fetched?.id == location.id)
        #expect(fetched?.locationName == "Shelf A")
    }

    @Test("Fetch by ID returns nil for non-existent location")
    func testFetchByIdNotFound() async throws {
        let repository = MockStorageLocationRepository()

        let fetched = try await repository.fetchLocation(byId: UUID())

        #expect(fetched == nil)
    }

    // MARK: - Fetch Unlinked Locations Tests

    @Test("Can fetch unlinked locations for inventory")
    func testFetchUnlinkedLocations() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()

        // Create one linked and one unlinked location
        let linkedLocation = createTestLocation(
            inventoryId: inventoryId,
            locationName: "Linked",
            purchaseRecordItemId: UUID()
        )
        let unlinkedLocation = createTestLocation(
            inventoryId: inventoryId,
            locationName: "Unlinked",
            purchaseRecordItemId: nil
        )

        _ = try await repository.createLocation(linkedLocation)
        _ = try await repository.createLocation(unlinkedLocation)

        let unlinked = try await repository.fetchUnlinkedLocations(
            forInventory: inventoryId,
            addedOnOrAfter: nil
        )

        #expect(unlinked.count == 1)
        #expect(unlinked.first?.locationName == "Unlinked")
    }

    @Test("Fetch unlinked locations excludes zero quantity")
    func testFetchUnlinkedExcludesZeroQuantity() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()

        let zeroQuantity = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Empty",
            quantity: 0,
            dateAdded: Date(),
            dateModified: Date(),
            purchaseRecordItemId: nil
        )
        let hasQuantity = createTestLocation(
            inventoryId: inventoryId,
            locationName: "Has Stock",
            quantity: 5.0
        )

        _ = try await repository.createLocation(zeroQuantity)
        _ = try await repository.createLocation(hasQuantity)

        let unlinked = try await repository.fetchUnlinkedLocations(
            forInventory: inventoryId,
            addedOnOrAfter: nil
        )

        #expect(unlinked.count == 1)
        #expect(unlinked.first?.locationName == "Has Stock")
    }

    @Test("Fetch unlinked locations filters by date")
    func testFetchUnlinkedFiltersbyDate() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()
        let now = Date()
        let weekAgo = now.addingTimeInterval(-86400 * 7)
        let twoWeeksAgo = now.addingTimeInterval(-86400 * 14)

        let oldLocation = createTestLocation(
            inventoryId: inventoryId,
            locationName: "Old",
            dateAdded: twoWeeksAgo
        )
        let recentLocation = createTestLocation(
            inventoryId: inventoryId,
            locationName: "Recent",
            dateAdded: now
        )

        _ = try await repository.createLocation(oldLocation)
        _ = try await repository.createLocation(recentLocation)

        let unlinked = try await repository.fetchUnlinkedLocations(
            forInventory: inventoryId,
            addedOnOrAfter: weekAgo
        )

        #expect(unlinked.count == 1)
        #expect(unlinked.first?.locationName == "Recent")
    }

    @Test("Fetch unlinked locations returns empty for different inventory")
    func testFetchUnlinkedDifferentInventory() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId1 = UUID()
        let inventoryId2 = UUID()

        let location = createTestLocation(inventoryId: inventoryId1)
        _ = try await repository.createLocation(location)

        let unlinked = try await repository.fetchUnlinkedLocations(
            forInventory: inventoryId2,
            addedOnOrAfter: nil
        )

        #expect(unlinked.isEmpty)
    }

    @Test("Fetch unlinked locations sorts by date ascending")
    func testFetchUnlinkedSortsByDate() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()
        let now = Date()

        let location1 = createTestLocation(
            inventoryId: inventoryId,
            locationName: "Latest",
            dateAdded: now
        )
        let location2 = createTestLocation(
            inventoryId: inventoryId,
            locationName: "Earliest",
            dateAdded: now.addingTimeInterval(-86400)
        )
        let location3 = createTestLocation(
            inventoryId: inventoryId,
            locationName: "Middle",
            dateAdded: now.addingTimeInterval(-43200)
        )

        _ = try await repository.createLocation(location1)
        _ = try await repository.createLocation(location2)
        _ = try await repository.createLocation(location3)

        let unlinked = try await repository.fetchUnlinkedLocations(
            forInventory: inventoryId,
            addedOnOrAfter: nil
        )

        #expect(unlinked.count == 3)
        #expect(unlinked[0].locationName == "Earliest")
        #expect(unlinked[1].locationName == "Middle")
        #expect(unlinked[2].locationName == "Latest")
    }

    // MARK: - Update Location by ID Tests

    @Test("Can update location by ID")
    func testUpdateLocationById() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()
        let purchaseItemId = UUID()

        let original = createTestLocation(inventoryId: inventoryId, quantity: 10.0)
        _ = try await repository.createLocation(original)

        // Update with purchase link
        let updated = StorageLocationModel(
            id: original.id,
            inventoryId: inventoryId,
            locationName: original.locationName,
            quantity: 10.0,
            dateAdded: original.dateAdded,
            dateModified: Date(),
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(15.00),
            currency: "USD"
        )

        let result = try await repository.updateLocationById(updated)

        #expect(result.purchaseRecordItemId == purchaseItemId)
        #expect(result.unitPrice == Decimal(15.00))
        #expect(result.currency == "USD")
    }

    @Test("Update by ID throws error for non-existent location")
    func testUpdateByIdNotFound() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()

        let location = createTestLocation(inventoryId: inventoryId)

        await #expect(throws: Error.self) {
            _ = try await repository.updateLocationById(location)
        }
    }

    // MARK: - Receipt Import Field Tests

    @Test("Can create location with all receipt import fields")
    func testCreateLocationWithReceiptFields() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()
        let purchaseItemId = UUID()

        let location = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 5.0,
            dateAdded: Date(),
            dateModified: Date(),
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(12.50),
            currency: "USD"
        )

        let created = try await repository.createLocation(location)

        #expect(created.purchaseRecordItemId == purchaseItemId)
        #expect(created.unitPrice == Decimal(12.50))
        #expect(created.currency == "USD")
    }

    @Test("Receipt import fields persist through fetch")
    func testReceiptFieldsPersist() async throws {
        let repository = MockStorageLocationRepository()
        let inventoryId = UUID()
        let purchaseItemId = UUID()

        let location = StorageLocationModel(
            id: UUID(),
            inventoryId: inventoryId,
            locationName: "Shelf A",
            quantity: 5.0,
            dateAdded: Date(),
            dateModified: Date(),
            purchaseRecordItemId: purchaseItemId,
            unitPrice: Decimal(12.50),
            currency: "EUR"
        )

        _ = try await repository.createLocation(location)
        let fetched = try await repository.fetchLocation(byId: location.id)

        #expect(fetched?.purchaseRecordItemId == purchaseItemId)
        #expect(fetched?.unitPrice == Decimal(12.50))
        #expect(fetched?.currency == "EUR")
    }
}
