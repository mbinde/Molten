//
//  PurchaseRecordRepositoryTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/19/25.
//  Tests for purchase record repository protocol using mock implementation
//

import Testing
import Foundation
@testable import Molten

/// Tests for PurchaseRecordRepository protocol using MockPurchaseRecordRepository
@Suite("Purchase Record Repository Tests")
@MainActor
struct PurchaseRecordRepositoryTests {

    // MARK: - Test Helpers

    /// Create a test purchase record
    private func createTestRecord(
        supplier: String = "Test Supplier",
        datePurchased: Date = Date(),
        subtotal: Decimal? = nil,
        tax: Decimal? = nil,
        shipping: Decimal? = nil,
        notes: String? = nil,
        items: [PurchaseRecordItemModel] = []
    ) -> PurchaseRecordModel {
        return PurchaseRecordModel(
            supplier: supplier,
            datePurchased: datePurchased,
            subtotal: subtotal,
            tax: tax,
            shipping: shipping,
            notes: notes,
            items: items
        )
    }

    /// Create a test item
    private func createTestItem(
        itemNaturalKey: String = "test-item-001",
        type: String = "rod",
        quantity: Double = 1.0,
        orderIndex: Int32 = 0
    ) -> PurchaseRecordItemModel {
        return PurchaseRecordItemModel(
            itemNaturalKey: itemNaturalKey,
            type: type,
            quantity: quantity,
            orderIndex: orderIndex
        )
    }

    // MARK: - CRUD Tests

    @Test("Can create a purchase record")
    func testCreateRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let record = createTestRecord(supplier: "Test Supplier")

        let created = try await repository.createRecord(record)

        #expect(created.id == record.id)
        #expect(created.supplier == "Test Supplier")

        let count = await repository.getRecordCount()
        #expect(count == 1)
    }

    @Test("Can fetch record by ID")
    func testFetchRecordById() async throws {
        let repository = MockPurchaseRecordRepository()
        let record = createTestRecord(supplier: "Test Supplier")

        _ = try await repository.createRecord(record)
        let fetched = try await repository.fetchRecord(byId: record.id)

        #expect(fetched != nil)
        #expect(fetched?.id == record.id)
        #expect(fetched?.supplier == "Test Supplier")
    }

    @Test("Fetch by ID returns nil for non-existent record")
    func testFetchByIdNotFound() async throws {
        let repository = MockPurchaseRecordRepository()
        let nonExistentId = UUID()

        let fetched = try await repository.fetchRecord(byId: nonExistentId)

        #expect(fetched == nil)
    }

    @Test("Can update a record")
    func testUpdateRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let record = createTestRecord(supplier: "Original Supplier")

        let created = try await repository.createRecord(record)

        // Update the record
        let updated = PurchaseRecordModel(
            id: created.id,
            supplier: "Updated Supplier",
            datePurchased: created.datePurchased,
            dateAdded: created.dateAdded,
            subtotal: Decimal(string: "100.00"),
            tax: nil,
            shipping: nil,
            currency: "USD",
            notes: "Updated notes",
            items: created.items
        )

        let result = try await repository.updateRecord(updated)

        #expect(result.supplier == "Updated Supplier")
        #expect(result.subtotal == Decimal(string: "100.00"))
        #expect(result.notes == "Updated notes")
    }

    @Test("Update throws error for non-existent record")
    func testUpdateNonExistentRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let record = createTestRecord(supplier: "Test")

        await #expect(throws: PurchaseRecordRepositoryError.self) {
            try await repository.updateRecord(record)
        }
    }

    @Test("Can delete a record")
    func testDeleteRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let record = createTestRecord(supplier: "Test Supplier")

        let created = try await repository.createRecord(record)

        try await repository.deleteRecord(id: created.id)

        let fetched = try await repository.fetchRecord(byId: created.id)
        #expect(fetched == nil)

        let count = await repository.getRecordCount()
        #expect(count == 0)
    }

    @Test("Delete throws error for non-existent record")
    func testDeleteNonExistentRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let nonExistentId = UUID()

        await #expect(throws: PurchaseRecordRepositoryError.self) {
            try await repository.deleteRecord(id: nonExistentId)
        }
    }

    @Test("Can fetch all records")
    func testGetAllRecords() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(supplier: "Supplier A")
        let record2 = createTestRecord(supplier: "Supplier B")

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        let allRecords = try await repository.getAllRecords()

        #expect(allRecords.count == 2)
    }

    @Test("All records are sorted by date purchased descending")
    func testGetAllRecordsSorting() async throws {
        let repository = MockPurchaseRecordRepository()

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let record1 = createTestRecord(supplier: "Oldest", datePurchased: twoDaysAgo)
        let record2 = createTestRecord(supplier: "Newest", datePurchased: today)
        let record3 = createTestRecord(supplier: "Middle", datePurchased: yesterday)

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)
        _ = try await repository.createRecord(record3)

        let allRecords = try await repository.getAllRecords()

        #expect(allRecords[0].supplier == "Newest")
        #expect(allRecords[1].supplier == "Middle")
        #expect(allRecords[2].supplier == "Oldest")
    }

    // MARK: - Date Range Tests

    @Test("Can fetch records within date range")
    func testFetchRecordsByDateRange() async throws {
        let repository = MockPurchaseRecordRepository()

        let calendar = Calendar.current
        let today = Date()
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today)!
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: today)!

        let recentRecord = createTestRecord(supplier: "Recent", datePurchased: today)
        let oldRecord = createTestRecord(supplier: "Old", datePurchased: tenDaysAgo)

        _ = try await repository.createRecord(recentRecord)
        _ = try await repository.createRecord(oldRecord)

        let records = try await repository.fetchRecords(from: fiveDaysAgo, to: today)

        #expect(records.count == 1)
        #expect(records[0].supplier == "Recent")
    }

    // MARK: - Search Tests

    @Test("Can search records by supplier name")
    func testSearchRecordsBySupplier() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(supplier: "Bullseye Glass")
        let record2 = createTestRecord(supplier: "Effetre Glass")

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        let results = try await repository.searchRecords(text: "bullseye")

        #expect(results.count == 1)
        #expect(results[0].supplier == "Bullseye Glass")
    }

    @Test("Can search records by notes")
    func testSearchRecordsByNotes() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(supplier: "Supplier A", notes: "Bought at the show")
        let record2 = createTestRecord(supplier: "Supplier B", notes: "Online order")

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        let results = try await repository.searchRecords(text: "show")

        #expect(results.count == 1)
        #expect(results[0].supplier == "Supplier A")
    }

    @Test("Search is case insensitive")
    func testSearchCaseInsensitive() async throws {
        let repository = MockPurchaseRecordRepository()

        let record = createTestRecord(supplier: "Bullseye Glass")
        _ = try await repository.createRecord(record)

        let results = try await repository.searchRecords(text: "BULLSEYE")

        #expect(results.count == 1)
    }

    @Test("Can fetch records by specific supplier")
    func testFetchRecordsBySupplier() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(supplier: "Bullseye Glass")
        let record2 = createTestRecord(supplier: "Bullseye Glass")
        let record3 = createTestRecord(supplier: "Effetre Glass")

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)
        _ = try await repository.createRecord(record3)

        let results = try await repository.fetchRecords(bySupplier: "Bullseye Glass")

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.supplier == "Bullseye Glass" })
    }

    // MARK: - Analytics Tests

    @Test("Can get distinct suppliers")
    func testGetDistinctSuppliers() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(supplier: "Bullseye Glass")
        let record2 = createTestRecord(supplier: "Effetre Glass")
        let record3 = createTestRecord(supplier: "Bullseye Glass")

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)
        _ = try await repository.createRecord(record3)

        let suppliers = try await repository.getDistinctSuppliers()

        #expect(suppliers.count == 2)
        #expect(suppliers.contains("Bullseye Glass"))
        #expect(suppliers.contains("Effetre Glass"))
    }

    @Test("Distinct suppliers are sorted")
    func testDistinctSuppliersSorted() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(supplier: "Zebra Glass")
        let record2 = createTestRecord(supplier: "Alpha Glass")

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        let suppliers = try await repository.getDistinctSuppliers()

        #expect(suppliers[0] == "Alpha Glass")
        #expect(suppliers[1] == "Zebra Glass")
    }

    @Test("Can calculate total spending in date range")
    func testCalculateTotalSpending() async throws {
        let repository = MockPurchaseRecordRepository()

        let calendar = Calendar.current
        let today = Date()
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today)!

        let record1 = createTestRecord(
            supplier: "Supplier A",
            datePurchased: today,
            subtotal: Decimal(string: "100.00"),
            tax: Decimal(string: "8.00"),
            shipping: Decimal(string: "10.00")
        )

        let record2 = createTestRecord(
            supplier: "Supplier B",
            datePurchased: today,
            subtotal: Decimal(string: "50.00"),
            tax: Decimal(string: "4.00"),
            shipping: Decimal(string: "5.00")
        )

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        let total = try await repository.calculateTotalSpending(from: fiveDaysAgo, to: today)

        // record1: 100 + 8 + 10 = 118
        // record2: 50 + 4 + 5 = 59
        // Total: 177
        #expect(total == Decimal(string: "177.00"))
    }

    @Test("Total spending excludes records without prices")
    func testTotalSpendingExcludesNoPrices() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(
            supplier: "Supplier A",
            subtotal: Decimal(string: "100.00")
        )

        let record2 = createTestRecord(
            supplier: "Supplier B"
            // No price info
        )

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        let calendar = Calendar.current
        let today = Date()
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!

        let total = try await repository.calculateTotalSpending(from: monthAgo, to: today)

        #expect(total == Decimal(string: "100.00"))
    }

    @Test("Can get spending by supplier")
    func testGetSpendingBySupplier() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(
            supplier: "Bullseye Glass",
            subtotal: Decimal(string: "100.00")
        )

        let record2 = createTestRecord(
            supplier: "Bullseye Glass",
            subtotal: Decimal(string: "50.00")
        )

        let record3 = createTestRecord(
            supplier: "Effetre Glass",
            subtotal: Decimal(string: "75.00")
        )

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)
        _ = try await repository.createRecord(record3)

        let calendar = Calendar.current
        let today = Date()
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!

        let spending = try await repository.getSpendingBySupplier(from: monthAgo, to: today)

        #expect(spending["Bullseye Glass"] == Decimal(string: "150.00"))
        #expect(spending["Effetre Glass"] == Decimal(string: "75.00"))
    }

    // MARK: - Item Operations Tests

    @Test("Can fetch items for specific glass item")
    func testFetchItemsForGlassItem() async throws {
        let repository = MockPurchaseRecordRepository()

        let items1 = [
            createTestItem(itemNaturalKey: "be-clear-001", quantity: 5.0, orderIndex: 0),
            createTestItem(itemNaturalKey: "ef-blue-002", quantity: 3.0, orderIndex: 1)
        ]

        let items2 = [
            createTestItem(itemNaturalKey: "be-clear-001", quantity: 10.0, orderIndex: 0)
        ]

        let record1 = createTestRecord(supplier: "Supplier A", items: items1)
        let record2 = createTestRecord(supplier: "Supplier B", items: items2)

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        let items = try await repository.fetchItemsForGlassItem(naturalKey: "be-clear-001")

        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.itemNaturalKey == "be-clear-001" })
    }

    @Test("Can get total purchased quantity for glass item")
    func testGetTotalPurchasedQuantity() async throws {
        let repository = MockPurchaseRecordRepository()

        let items1 = [
            createTestItem(itemNaturalKey: "be-clear-001", type: "rod", quantity: 5.0, orderIndex: 0)
        ]

        let items2 = [
            createTestItem(itemNaturalKey: "be-clear-001", type: "rod", quantity: 10.0, orderIndex: 0)
        ]

        let record1 = createTestRecord(supplier: "Supplier A", items: items1)
        let record2 = createTestRecord(supplier: "Supplier B", items: items2)

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        let total = try await repository.getTotalPurchasedQuantity(for: "be-clear-001", type: "rod")

        #expect(total == 15.0)
    }

    @Test("Total purchased quantity filters by type")
    func testGetTotalPurchasedQuantityByType() async throws {
        let repository = MockPurchaseRecordRepository()

        let items = [
            createTestItem(itemNaturalKey: "be-clear-001", type: "rod", quantity: 5.0, orderIndex: 0),
            PurchaseRecordItemModel(
                itemNaturalKey: "be-clear-001",
                type: "tube",
                quantity: 3.0,
                orderIndex: 1
            )
        ]

        let record = createTestRecord(supplier: "Supplier A", items: items)
        _ = try await repository.createRecord(record)

        let totalRods = try await repository.getTotalPurchasedQuantity(for: "be-clear-001", type: "rod")
        let totalTubes = try await repository.getTotalPurchasedQuantity(for: "be-clear-001", type: "tube")

        #expect(totalRods == 5.0)
        #expect(totalTubes == 3.0)
    }

    // MARK: - Test Helpers Tests

    @Test("Can clear all records")
    func testClearAll() async throws {
        let repository = MockPurchaseRecordRepository()

        let record1 = createTestRecord(supplier: "Supplier A")
        let record2 = createTestRecord(supplier: "Supplier B")

        _ = try await repository.createRecord(record1)
        _ = try await repository.createRecord(record2)

        await repository.clearAll()

        let count = await repository.getRecordCount()
        #expect(count == 0)
    }
}
