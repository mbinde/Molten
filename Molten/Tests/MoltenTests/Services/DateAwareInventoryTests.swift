//
//  DateAwareInventoryTests.swift
//  MoltenTests
//
//  Tests for date-aware inventory operations:
//  - Increment creates/updates records based on today's date
//  - Decrement uses LIFO (Last In, First Out) strategy
//  - Date filtering for label printing workflows
//

import Testing
import Foundation
@testable import Molten

@Suite("Date-Aware Inventory Operations", .serialized)
@MainActor
struct DateAwareInventoryTests {

    // MARK: - Shared Dependencies

    /// Store AppDependencies at struct level to keep PersistenceController alive
    private let deps = AppDependencies(persistenceController: .createTestController())

    // Helper to get a real catalog item for testing
    private func getTestCatalogItem() async throws -> GlassItemModel {
        let catalogService = deps.catalogService
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        guard let item = catalogItems.first(where: { $0.sku != nil }) else {
            throw TestError.noCatalogItems
        }
        return item
    }

    // Helper to get multiple distinct catalog items
    private func getTestCatalogItems(count: Int) async throws -> [GlassItemModel] {
        let catalogService = deps.catalogService
        let catalogItems = try await catalogService.getGlassItemsLightweight()
        let items = Array(catalogItems.filter { $0.sku != nil }.prefix(count))
        guard items.count >= count else {
            throw TestError.noCatalogItems
        }
        return items
    }

    enum TestError: Error {
        case noCatalogItems
    }

    // MARK: - Increment Tests

    @Test("Increment creates new record when none exists")
    func testIncrementCreatesNewRecord() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Increment should create a new record
        let result = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Test Location A"
        )

        #expect(result.quantity == 1)
        #expect(result.type == "rod")
        #expect(result.location == "Test Location A")
        #expect(result.item_stable_id == item.stable_id)

        // Verify date_added is today
        let calendar = Calendar.current
        #expect(calendar.isDateInToday(result.date_added))
    }

    @Test("Increment updates existing today's record")
    func testIncrementUpdatesExistingTodayRecord() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // First increment creates record
        let first = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Test Location B"
        )
        #expect(first.quantity == 1)

        // Second increment should update same record (same day)
        let second = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Test Location B"
        )
        #expect(second.quantity == 2)
        #expect(second.id == first.id) // Same record was updated

        // Third increment
        let third = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Test Location B"
        )
        #expect(third.quantity == 3)
        #expect(third.id == first.id) // Still same record

        // Verify only one record exists
        let allRecords = try await service.fetchInventory(forItem: item.stable_id)
        let matchingRecords = allRecords.filter { $0.location == "Test Location B" && $0.type == "rod" }
        #expect(matchingRecords.count == 1)
    }

    @Test("Increment creates separate records for different locations")
    func testIncrementSeparateLocations() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Increment at location A
        let recordA = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Location A"
        )

        // Increment at location B
        let recordB = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Location B"
        )

        #expect(recordA.id != recordB.id) // Different records
        #expect(recordA.location == "Location A")
        #expect(recordB.location == "Location B")
        #expect(recordA.quantity == 1)
        #expect(recordB.quantity == 1)
    }

    @Test("Increment creates separate records for different types")
    func testIncrementSeparateTypes() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Increment rod type
        let rodRecord = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Same Location"
        )

        // Increment tube type
        let tubeRecord = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "tube",
            atLocation: "Same Location"
        )

        #expect(rodRecord.id != tubeRecord.id)
        #expect(rodRecord.type == "rod")
        #expect(tubeRecord.type == "tube")
    }

    @Test("Increment handles nil location separately from named locations")
    func testIncrementNilLocationSeparate() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Increment with nil location
        let nilRecord = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: nil
        )

        // Increment with named location
        let namedRecord = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Named Location"
        )

        #expect(nilRecord.id != namedRecord.id)
        #expect(nilRecord.location == nil)
        #expect(namedRecord.location == "Named Location")
    }

    @Test("Increment with subtype creates separate records")
    func testIncrementWithSubtype() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Increment frit coarse
        let coarseRecord = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "frit",
            subtype: "coarse",
            atLocation: "Frit Shelf"
        )

        // Increment frit fine
        let fineRecord = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "frit",
            subtype: "fine",
            atLocation: "Frit Shelf"
        )

        #expect(coarseRecord.id != fineRecord.id)
        #expect(coarseRecord.subtype == "coarse")
        #expect(fineRecord.subtype == "fine")
    }

    // MARK: - Decrement LIFO Tests

    @Test("Decrement reduces quantity on newest record (LIFO)")
    func testDecrementLIFO() async throws {
        let service = deps.inventoryTrackingService
        let inventoryRepo = deps.inventoryRepository
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Create an old record (yesterday) directly via repository
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let oldRecord = InventoryModel(
            item_stable_id: item.stable_id,
            type: "rod",
            quantity: 5,
            location: "LIFO Test Location",
            date_added: Calendar.current.startOfDay(for: yesterday)
        )
        _ = try await inventoryRepo.createInventory(oldRecord)

        // Create a new record (today) via increment
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "LIFO Test Location"
        )
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "LIFO Test Location"
        )
        // Now we have: yesterday=5, today=2

        // Decrement should reduce today's record first (LIFO)
        let result = try await service.decrementInventoryLIFO(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "LIFO Test Location"
        )

        #expect(result?.quantity == 1) // Today's record went from 2 to 1

        // Verify yesterday's record is unchanged
        let allRecords = try await service.fetchInventory(forItem: item.stable_id)
        let yesterdayRecords = allRecords.filter {
            $0.location == "LIFO Test Location" &&
            $0.type == "rod" &&
            Calendar.current.isDate($0.date_added, inSameDayAs: yesterday)
        }
        #expect(yesterdayRecords.first?.quantity == 5) // Unchanged
    }

    @Test("Decrement deletes record when quantity reaches zero")
    func testDecrementDeletesAtZero() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Create a record with quantity 1
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Delete Test Location"
        )

        // Verify record exists
        var allRecords = try await service.fetchInventory(forItem: item.stable_id)
        var matchingRecords = allRecords.filter { $0.location == "Delete Test Location" }
        #expect(matchingRecords.count == 1)

        // Decrement to zero - should delete the record
        let result = try await service.decrementInventoryLIFO(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Delete Test Location"
        )

        #expect(result == nil) // Record was deleted

        // Verify record no longer exists
        allRecords = try await service.fetchInventory(forItem: item.stable_id)
        matchingRecords = allRecords.filter { $0.location == "Delete Test Location" }
        #expect(matchingRecords.count == 0)
    }

    @Test("Decrement moves to older record after newest depleted")
    func testDecrementMovesToOlderRecord() async throws {
        let service = deps.inventoryTrackingService
        let inventoryRepo = deps.inventoryRepository
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Create an old record (2 days ago) with quantity 3
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let oldRecord = InventoryModel(
            item_stable_id: item.stable_id,
            type: "rod",
            quantity: 3,
            location: "Cascade Test",
            date_added: Calendar.current.startOfDay(for: twoDaysAgo)
        )
        _ = try await inventoryRepo.createInventory(oldRecord)

        // Create today's record with quantity 1
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Cascade Test"
        )

        // First decrement: depletes today's record (1 -> 0, deleted)
        let result1 = try await service.decrementInventoryLIFO(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Cascade Test"
        )
        #expect(result1 == nil) // Today's record deleted

        // Second decrement: should now decrement old record (3 -> 2)
        let result2 = try await service.decrementInventoryLIFO(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Cascade Test"
        )
        #expect(result2?.quantity == 2) // Old record decremented
    }

    @Test("Decrement throws error when no inventory exists")
    func testDecrementThrowsWhenEmpty() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Attempt to decrement non-existent inventory
        await #expect(throws: InventoryTrackingServiceError.self) {
            _ = try await service.decrementInventoryLIFO(
                forItem: item.stable_id,
                type: "rod",
                atLocation: "Empty Location"
            )
        }
    }

    @Test("Decrement respects location filter")
    func testDecrementRespectsLocation() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Create records at two different locations
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Location X"
        )
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Location X"
        )
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Location Y"
        )

        // Decrement Location X only
        let result = try await service.decrementInventoryLIFO(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Location X"
        )

        #expect(result?.quantity == 1) // Location X: 2 -> 1

        // Verify Location Y unchanged
        let allRecords = try await service.fetchInventory(forItem: item.stable_id)
        let yRecords = allRecords.filter { $0.location == "Location Y" }
        #expect(yRecords.first?.quantity == 1)
    }

    @Test("Decrement respects type filter")
    func testDecrementRespectsType() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Create records of different types at same location
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Type Test Location"
        )
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Type Test Location"
        )
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "tube",
            atLocation: "Type Test Location"
        )

        // Decrement rod only
        let result = try await service.decrementInventoryLIFO(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Type Test Location"
        )

        #expect(result?.quantity == 1) // Rod: 2 -> 1

        // Verify tube unchanged
        let allRecords = try await service.fetchInventory(forItem: item.stable_id)
        let tubeRecords = allRecords.filter { $0.type == "tube" && $0.location == "Type Test Location" }
        #expect(tubeRecords.first?.quantity == 1)
    }

    // MARK: - Date Filtering Tests

    @Test("Fetch inventory added since specific date")
    func testFetchInventoryAddedSince() async throws {
        let service = deps.inventoryTrackingService
        let inventoryRepo = deps.inventoryRepository
        let items = try await getTestCatalogItems(count: 2)
        let item = items[0]

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Create an old record (5 days ago)
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let oldRecord = InventoryModel(
            item_stable_id: item.stable_id,
            type: "rod",
            quantity: 10,
            location: "Date Filter Test",
            date_added: Calendar.current.startOfDay(for: fiveDaysAgo)
        )
        _ = try await inventoryRepo.createInventory(oldRecord)

        // Create today's record
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Date Filter Test"
        )

        // Fetch records added since 3 days ago (should only get today's)
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let recentRecords = try await service.fetchInventoryAddedSince(threeDaysAgo, forItem: item.stable_id)

        #expect(recentRecords.count == 1)
        #expect(Calendar.current.isDateInToday(recentRecords[0].date_added))
    }

    @Test("Fetch inventory added since today")
    func testFetchInventoryAddedToday() async throws {
        let service = deps.inventoryTrackingService
        let inventoryRepo = deps.inventoryRepository
        let items = try await getTestCatalogItems(count: 2)
        let item = items[1]

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Create a yesterday record
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayRecord = InventoryModel(
            item_stable_id: item.stable_id,
            type: "rod",
            quantity: 5,
            location: "Today Filter Test",
            date_added: Calendar.current.startOfDay(for: yesterday)
        )
        _ = try await inventoryRepo.createInventory(yesterdayRecord)

        // Create today's records
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Today Filter Test"
        )
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "tube",
            atLocation: "Today Filter Test"
        )

        // Fetch records added today
        let todayRecords = try await service.fetchInventoryAddedSince(Date(), forItem: item.stable_id)

        #expect(todayRecords.count == 2)
        for record in todayRecords {
            #expect(Calendar.current.isDateInToday(record.date_added))
        }
    }

    @Test("Fetch inventory added since returns empty for future date")
    func testFetchInventoryAddedSinceFutureDate() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Create today's record
        _ = try await service.incrementInventory(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Future Test"
        )

        // Fetch records added since tomorrow (should be empty)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let futureRecords = try await service.fetchInventoryAddedSince(tomorrow, forItem: item.stable_id)

        #expect(futureRecords.isEmpty)
    }

    // MARK: - Integration Tests

    @Test("Full workflow: increment, decrement, check totals")
    func testFullWorkflow() async throws {
        let service = deps.inventoryTrackingService
        let item = try await getTestCatalogItem()

        // Clear any existing inventory first
        try await service.deleteInventory(forItem: item.stable_id)

        // Add 5 items via increment
        for _ in 0..<5 {
            _ = try await service.incrementInventory(
                forItem: item.stable_id,
                type: "rod",
                atLocation: "Workflow Test"
            )
        }

        // Check total
        var allRecords = try await service.fetchInventory(forItem: item.stable_id)
        var matching = allRecords.filter { $0.location == "Workflow Test" }
        var total = matching.reduce(0.0) { $0 + $1.quantity }
        #expect(total == 5)

        // Remove 2 items via decrement
        _ = try await service.decrementInventoryLIFO(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Workflow Test"
        )
        _ = try await service.decrementInventoryLIFO(
            forItem: item.stable_id,
            type: "rod",
            atLocation: "Workflow Test"
        )

        // Check total again
        allRecords = try await service.fetchInventory(forItem: item.stable_id)
        matching = allRecords.filter { $0.location == "Workflow Test" }
        total = matching.reduce(0.0) { $0 + $1.quantity }
        #expect(total == 3)
    }

    @Test("Multiple items at same location with different dates")
    func testMultipleItemsSameLocationDifferentDates() async throws {
        let service = deps.inventoryTrackingService
        let inventoryRepo = deps.inventoryRepository
        let items = try await getTestCatalogItems(count: 2)
        let item1 = items[0]
        let item2 = items[1]

        // Clear existing inventory
        try await service.deleteInventory(forItem: item1.stable_id)
        try await service.deleteInventory(forItem: item2.stable_id)

        // Add item1 yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let item1Record = InventoryModel(
            item_stable_id: item1.stable_id,
            type: "rod",
            quantity: 3,
            location: "Multi-Item Location",
            date_added: Calendar.current.startOfDay(for: yesterday)
        )
        _ = try await inventoryRepo.createInventory(item1Record)

        // Add item2 today
        _ = try await service.incrementInventory(
            forItem: item2.stable_id,
            type: "rod",
            atLocation: "Multi-Item Location"
        )

        // Fetch items added today - should only return item2
        let todayRecords = try await service.fetchInventoryAddedSince(Date())
        let todayStableIds = Set(todayRecords.map { $0.item_stable_id })

        #expect(todayStableIds.contains(item2.stable_id))
        #expect(!todayStableIds.contains(item1.stable_id))
    }
}
