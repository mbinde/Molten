//
//  CoreDataPurchaseRecordRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataPurchaseRecordRepository - manages purchase records
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data PurchaseRecord Repository Tests")
@MainActor
struct CoreDataPurchaseRecordRepositoryTests {

    // MARK: - Create Tests

    @Test("Should create purchase record")
    func testCreateRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            datePurchased: Date(),
            subtotal: 100.00,
            tax: 8.00,
            shipping: 10.00,
            currency: "USD",
            notes: "Test purchase"
        )

        // Test
        let created = try await repository.createRecord(record)

        // Verify
        #expect(created.supplier == "Test Supplier")
        #expect(created.subtotal == 100.00)
        #expect(created.totalPrice == 118.00)
    }

    @Test("Should create purchase record with items")
    func testCreateRecordWithItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let items = [
            PurchaseRecordItemModel(
                item_stable_id: "test-123",
                type: "rod",
                quantity: 5.0,
                totalPrice: 25.00,
                orderIndex: 0
            ),
            PurchaseRecordItemModel(
                item_stable_id: "test-456",
                type: "tube",
                quantity: 3.0,
                totalPrice: 30.00,
                orderIndex: 1
            )
        ]

        let record = PurchaseRecordModel(
            supplier: "Test Supplier",
            subtotal: 55.00,
            items: items
        )

        // Test
        let created = try await repository.createRecord(record)

        // Verify
        #expect(created.items.count == 2)
        #expect(created.items[0].item_stable_id == "test-123")
        #expect(created.items[1].item_stable_id == "test-456")
    }

    // MARK: - Read Tests

    @Test("Should fetch record by ID")
    func testFetchRecordById() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recordId = UUID()
        let record = PurchaseRecordModel(
            id: recordId,
            supplier: "Test Supplier",
            subtotal: 100.00
        )
        _ = try await repository.createRecord(record)

        // Test
        let fetched = try await repository.fetchRecord(byId: recordId)

        // Verify
        #expect(fetched != nil)
        #expect(fetched?.id == recordId)
        #expect(fetched?.supplier == "Test Supplier")
    }

    @Test("Should return nil for non-existent record")
    func testFetchNonExistentRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test
        let fetched = try await repository.fetchRecord(byId: UUID())

        // Verify
        #expect(fetched == nil)
    }

    @Test("Should fetch all records")
    func testGetAllRecords() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Supplier 1",
            subtotal: 100.00
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Supplier 2",
            subtotal: 200.00
        ))

        // Test
        let records = try await repository.getAllRecords()

        // Verify
        #expect(records.count == 2)
    }

    @Test("Should fetch records sorted by date")
    func testFetchRecordsSortedByDate() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Older",
            datePurchased: date1
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Newer",
            datePurchased: date2
        ))

        // Test
        let records = try await repository.getAllRecords()

        // Verify - Should be sorted newest first
        #expect(records.count == 2)
        #expect(records[0].supplier == "Newer")
        #expect(records[1].supplier == "Older")
    }

    @Test("Should fetch records within date range")
    func testFetchRecordsInDateRange() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let startDate = Date(timeIntervalSince1970: 1000)
        let midDate = Date(timeIntervalSince1970: 2000)
        let endDate = Date(timeIntervalSince1970: 3000)

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Before Range",
            datePurchased: Date(timeIntervalSince1970: 500)
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "In Range",
            datePurchased: midDate
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "After Range",
            datePurchased: Date(timeIntervalSince1970: 4000)
        ))

        // Test
        let records = try await repository.fetchRecords(from: startDate, to: endDate)

        // Verify
        #expect(records.count == 1)
        #expect(records[0].supplier == "In Range")
    }

    // MARK: - Update Tests

    @Test("Should update existing record")
    func testUpdateRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recordId = UUID()
        let original = PurchaseRecordModel(
            id: recordId,
            supplier: "Original Supplier",
            subtotal: 100.00
        )
        _ = try await repository.createRecord(original)

        // Test
        let updated = PurchaseRecordModel(
            id: recordId,
            supplier: "Updated Supplier",
            subtotal: 200.00
        )
        _ = try await repository.updateRecord(updated)

        // Verify
        let fetched = try await repository.fetchRecord(byId: recordId)
        #expect(fetched?.supplier == "Updated Supplier")
        #expect(fetched?.subtotal == 200.00)
    }

    @Test("Should update record items")
    func testUpdateRecordItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recordId = UUID()
        let originalItems = [
            PurchaseRecordItemModel(
                item_stable_id: "test-123",
                type: "rod",
                quantity: 5.0
            )
        ]
        let original = PurchaseRecordModel(
            id: recordId,
            supplier: "Test",
            items: originalItems
        )
        _ = try await repository.createRecord(original)

        // Test - Update with different items
        let updatedItems = [
            PurchaseRecordItemModel(
                item_stable_id: "test-456",
                type: "tube",
                quantity: 3.0
            ),
            PurchaseRecordItemModel(
                item_stable_id: "test-789",
                type: "frit",
                quantity: 2.0
            )
        ]
        let updated = PurchaseRecordModel(
            id: recordId,
            supplier: "Test",
            items: updatedItems
        )
        _ = try await repository.updateRecord(updated)

        // Verify
        let fetched = try await repository.fetchRecord(byId: recordId)
        #expect(fetched?.items.count == 2)
        #expect(fetched?.items[0].item_stable_id == "test-456")
        #expect(fetched?.items[1].item_stable_id == "test-789")
    }

    @Test("Should throw error when updating non-existent record")
    func testUpdateNonExistentRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test"
        )

        // Test & Verify
        do {
            _ = try await repository.updateRecord(record)
            Issue.record("Expected error for updating non-existent record")
        } catch {
            // Expected error
        }
    }

    // MARK: - Delete Tests

    @Test("Should delete record")
    func testDeleteRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recordId = UUID()
        let record = PurchaseRecordModel(
            id: recordId,
            supplier: "Test"
        )
        _ = try await repository.createRecord(record)

        // Test
        try await repository.deleteRecord(id: recordId)

        // Verify
        let fetched = try await repository.fetchRecord(byId: recordId)
        #expect(fetched == nil)
    }

    @Test("Should delete record and its items")
    func testDeleteRecordWithItems() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let recordId = UUID()
        let items = [
            PurchaseRecordItemModel(
                item_stable_id: "test-123",
                type: "rod",
                quantity: 5.0
            )
        ]
        let record = PurchaseRecordModel(
            id: recordId,
            supplier: "Test",
            items: items
        )
        _ = try await repository.createRecord(record)

        // Test
        try await repository.deleteRecord(id: recordId)

        // Verify
        let fetched = try await repository.fetchRecord(byId: recordId)
        #expect(fetched == nil)
    }

    @Test("Should throw error when deleting non-existent record")
    func testDeleteNonExistentRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        // Test & Verify
        do {
            try await repository.deleteRecord(id: UUID())
            Issue.record("Expected error for deleting non-existent record")
        } catch {
            // Expected error
        }
    }

    // MARK: - Search Tests

    @Test("Should search records by supplier name")
    func testSearchBySupplier() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Bullseye Glass"
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Oceanside Glass"
        ))

        // Test
        let results = try await repository.searchRecords(text: "Bullseye")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].supplier == "Bullseye Glass")
    }

    @Test("Should search records by notes")
    func testSearchByNotes() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Test",
            notes: "Special order for project"
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Test2",
            notes: "Regular stock order"
        ))

        // Test
        let results = try await repository.searchRecords(text: "Special")

        // Verify
        #expect(results.count == 1)
        #expect(results[0].notes == "Special order for project")
    }

    @Test("Should fetch records by specific supplier")
    func testFetchBySupplier() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecord(PurchaseRecordModel(supplier: "Bullseye"))
        _ = try await repository.createRecord(PurchaseRecordModel(supplier: "Bullseye"))
        _ = try await repository.createRecord(PurchaseRecordModel(supplier: "Oceanside"))

        // Test
        let results = try await repository.fetchRecords(bySupplier: "Bullseye")

        // Verify
        #expect(results.count == 2)
    }

    // MARK: - Analytics Tests

    @Test("Should get distinct suppliers")
    func testGetDistinctSuppliers() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        _ = try await repository.createRecord(PurchaseRecordModel(supplier: "Bullseye"))
        _ = try await repository.createRecord(PurchaseRecordModel(supplier: "Bullseye"))
        _ = try await repository.createRecord(PurchaseRecordModel(supplier: "Oceanside"))
        _ = try await repository.createRecord(PurchaseRecordModel(supplier: "Spectrum"))

        // Test
        let suppliers = try await repository.getDistinctSuppliers()

        // Verify
        #expect(suppliers.count == 3)
        #expect(suppliers.contains("Bullseye"))
        #expect(suppliers.contains("Oceanside"))
        #expect(suppliers.contains("Spectrum"))
    }

    @Test("Should calculate total spending")
    func testCalculateTotalSpending() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let startDate = Date(timeIntervalSince1970: 1000)
        let endDate = Date(timeIntervalSince1970: 3000)

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Test",
            datePurchased: Date(timeIntervalSince1970: 1500),
            subtotal: 100.00
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Test",
            datePurchased: Date(timeIntervalSince1970: 2000),
            subtotal: 50.00,
            tax: 5.00
        ))

        // Test
        let total = try await repository.calculateTotalSpending(from: startDate, to: endDate)

        // Verify
        #expect(total == 155.00)
    }

    @Test("Should get spending by supplier")
    func testGetSpendingBySupplier() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let startDate = Date(timeIntervalSince1970: 1000)
        let endDate = Date(timeIntervalSince1970: 3000)

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Bullseye",
            datePurchased: Date(timeIntervalSince1970: 1500),
            subtotal: 100.00
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Bullseye",
            datePurchased: Date(timeIntervalSince1970: 2000),
            subtotal: 50.00
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Oceanside",
            datePurchased: Date(timeIntervalSince1970: 2500),
            subtotal: 75.00
        ))

        // Test
        let spending = try await repository.getSpendingBySupplier(from: startDate, to: endDate)

        // Verify
        #expect(spending["Bullseye"] == 150.00)
        #expect(spending["Oceanside"] == 75.00)
    }

    // MARK: - Item Operations Tests

    @Test("Should fetch items for glass item")
    func testFetchItemsForGlassItem() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let items = [
            PurchaseRecordItemModel(
                item_stable_id: "test-123",
                type: "rod",
                quantity: 5.0
            ),
            PurchaseRecordItemModel(
                item_stable_id: "test-456",
                type: "tube",
                quantity: 3.0
            )
        ]

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Test",
            items: items
        ))

        // Test
        let fetchedItems = try await repository.fetchItemsForGlassItem(stableId: "test-123")

        // Verify
        #expect(fetchedItems.count == 1)
        #expect(fetchedItems[0].item_stable_id == "test-123")
        #expect(fetchedItems[0].quantity == 5.0)
    }

    @Test("Should get total purchased quantity")
    func testGetTotalPurchasedQuantity() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let items1 = [
            PurchaseRecordItemModel(
                item_stable_id: "test-123",
                type: "rod",
                quantity: 5.0
            )
        ]
        let items2 = [
            PurchaseRecordItemModel(
                item_stable_id: "test-123",
                type: "rod",
                quantity: 3.0
            )
        ]

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Test1",
            items: items1
        ))
        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Test2",
            items: items2
        ))

        // Test
        let total = try await repository.getTotalPurchasedQuantity(for: "test-123", type: "rod")

        // Verify
        #expect(total == 8.0)
    }

    @Test("Should filter quantity by type")
    func testGetTotalPurchasedQuantityByType() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = createTestRepository(controller: controller)

        let items = [
            PurchaseRecordItemModel(
                item_stable_id: "test-123",
                type: "rod",
                quantity: 5.0
            ),
            PurchaseRecordItemModel(
                item_stable_id: "test-123",
                type: "tube",
                quantity: 3.0
            )
        ]

        _ = try await repository.createRecord(PurchaseRecordModel(
            supplier: "Test",
            items: items
        ))

        // Test
        let rodTotal = try await repository.getTotalPurchasedQuantity(for: "test-123", type: "rod")
        let tubeTotal = try await repository.getTotalPurchasedQuantity(for: "test-123", type: "tube")

        // Verify
        #expect(rodTotal == 5.0)
        #expect(tubeTotal == 3.0)
    }

    // MARK: - Helper Methods

    private func createTestRepository(controller: PersistenceController) -> CoreDataPurchaseRecordRepository {
        return CoreDataPurchaseRecordRepository(context: controller.container.viewContext)
    }
}
