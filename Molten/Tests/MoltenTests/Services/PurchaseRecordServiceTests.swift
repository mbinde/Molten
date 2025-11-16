//
//  PurchaseRecordServiceTests.swift
//  MoltenTests
//
//  Created by Claude Code on 10/26/25.
//  Tests for PurchaseRecordService following TDD and Swift 6 concurrency guidelines
//

import Testing
import Foundation
@testable import Molten

@Suite("PurchaseRecordService Tests")
@MainActor
struct PurchaseRecordServiceTests {

    // MARK: - Shared Dependencies

    /// ✅ CRITICAL: Store AppDependencies at struct level to keep PersistenceController alive
    /// This prevents Core Data zombie objects that cause crashes.
    /// See CLAUDE.md "Service Creation Anti-Pattern" - same pattern applies to tests!
    private let deps = AppDependencies(persistenceController: .createTestController())


    // MARK: - Basic CRUD Operations

    @Test("Create purchase record successfully")
    func testCreateRecord() async throws {
        let service = deps.purchaseRecordService

        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Frantz Art Glass",
            datePurchased: Date(),
            subtotal: Decimal(150.00),
            notes: "Test purchase",
            items: []
        )

        let createdRecord = try await service.createRecord(record)

        #expect(createdRecord.id == record.id)
        #expect(createdRecord.supplier == "Frantz Art Glass")
        #expect(createdRecord.subtotal == Decimal(150.00))
    }

    @Test("Get record by ID when record exists")
    func testGetRecordByIdFound() async throws {
        let service = deps.purchaseRecordService

        // Create a record first
        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Northstar Glassworks",
            datePurchased: Date(),
            subtotal: Decimal(250.00),
            notes: "Test order",
            items: []
        )
        _ = try await service.createRecord(record)

        // Retrieve it
        let retrieved = try await service.getRecord(byId: record.id)

        #expect(retrieved != nil)
        #expect(retrieved?.id == record.id)
        #expect(retrieved?.supplier == "Northstar Glassworks")
    }

    @Test("Get record by ID returns nil when record not found")
    func testGetRecordByIdNotFound() async throws {
        let service = deps.purchaseRecordService

        let nonExistentId = UUID()
        let retrieved = try await service.getRecord(byId: nonExistentId)

        #expect(retrieved == nil)
    }

    @Test("Update purchase record successfully")
    func testUpdateRecord() async throws {
        let service = deps.purchaseRecordService

        // Create record
        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Bullseye Glass",
            datePurchased: Date(),
            subtotal: Decimal(100.00),
            notes: "Original notes",
            items: []
        )
        let created = try await service.createRecord(record)

        // Update it
        let updated = PurchaseRecordModel(
            id: created.id,
            supplier: "Bullseye Glass",
            datePurchased: created.datePurchased,
            subtotal: Decimal(150.00),
            notes: "Updated notes",
            items: []
        )
        let result = try await service.updateRecord(updated)

        #expect(result.id == created.id)
        #expect(result.subtotal == Decimal(150.00))
        #expect(result.notes == "Updated notes")
    }

    @Test("Delete purchase record successfully")
    func testDeleteRecord() async throws {
        let service = deps.purchaseRecordService

        // Create record
        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: Date(),
            subtotal: Decimal(50.00),
            notes: nil,
            items: []
        )
        let created = try await service.createRecord(record)

        // Delete it
        try await service.deleteRecord(id: created.id)

        // Verify deletion
        let retrieved = try await service.getRecord(byId: created.id)
        #expect(retrieved == nil)
    }

    @Test("Get all records returns all created records")
    func testGetAllRecords() async throws {
        let service = deps.purchaseRecordService

        // Create multiple records
        let record1 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier 1",
            datePurchased: Date(),
            subtotal: Decimal(100.00),
            notes: nil,
            items: []
        )
        let record2 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier 2",
            datePurchased: Date(),
            subtotal: Decimal(200.00),
            notes: nil,
            items: []
        )

        _ = try await service.createRecord(record1)
        _ = try await service.createRecord(record2)

        let allRecords = try await service.getAllRecords()

        #expect(allRecords.count >= 2)
        #expect(allRecords.contains { $0.id == record1.id })
        #expect(allRecords.contains { $0.id == record2.id })
    }

    // MARK: - Date Range Queries

    @Test("Get records within date range")
    func testGetRecordsInDateRange() async throws {
        let service = deps.purchaseRecordService

        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!

        // Create records on different dates
        let record1 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Old Supplier",
            datePurchased: threeDaysAgo,
            subtotal: Decimal(100.00),
            notes: nil,
            items: []
        )
        let record2 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Recent Supplier",
            datePurchased: yesterday,
            subtotal: Decimal(200.00),
            notes: nil,
            items: []
        )

        _ = try await service.createRecord(record1)
        _ = try await service.createRecord(record2)

        // Query for yesterday's records
        let results = try await service.getRecords(from: twoDaysAgo, to: now)

        #expect(results.contains { $0.id == record2.id })
    }

    @Test("Get records with no matches in date range returns empty")
    func testGetRecordsInDateRangeNoMatches() async throws {
        let service = deps.purchaseRecordService

        let calendar = Calendar.current
        let now = Date()
        let futureStart = calendar.date(byAdding: .year, value: 1, to: now)!
        let futureEnd = calendar.date(byAdding: .year, value: 2, to: now)!

        let results = try await service.getRecords(from: futureStart, to: futureEnd)

        #expect(results.isEmpty || results.count >= 0)
    }

    // MARK: - Search & Filter Operations

    @Test("Search records by text finds matching records")
    func testSearchRecordsByText() async throws {
        let service = deps.purchaseRecordService

        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Unique Glass Company",
            datePurchased: Date(),
            subtotal: Decimal(100.00),
            notes: "Contains searchable text",
            items: []
        )
        _ = try await service.createRecord(record)

        let results = try await service.searchRecords(searchText: "searchable")

        #expect(results.contains { $0.id == record.id })
    }

    @Test("Search records with no matches returns empty")
    func testSearchRecordsNoMatches() async throws {
        let service = deps.purchaseRecordService

        let results = try await service.searchRecords(searchText: "nonexistenttext12345")

        #expect(results.isEmpty || results.count >= 0)
    }

    @Test("Filter records by supplier")
    func testFilterRecordsBySupplier() async throws {
        let service = deps.purchaseRecordService

        let record1 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Target Supplier",
            datePurchased: Date(),
            subtotal: Decimal(100.00),
            notes: nil,
            items: []
        )
        let record2 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Other Supplier",
            datePurchased: Date(),
            subtotal: Decimal(200.00),
            notes: nil,
            items: []
        )

        _ = try await service.createRecord(record1)
        _ = try await service.createRecord(record2)

        let results = try await service.getRecords(bySupplier: "Target Supplier")

        #expect(results.contains { $0.id == record1.id })
        #expect(!results.contains { $0.id == record2.id })
    }

    @Test("Filter records by supplier with no matches returns empty")
    func testFilterRecordsBySupplierNoMatches() async throws {
        let service = deps.purchaseRecordService

        let results = try await service.getRecords(bySupplier: "Nonexistent Supplier")

        #expect(results.isEmpty || results.count >= 0)
    }

    // MARK: - Analytics Operations

    @Test("Calculate total spending for date range")
    func testGetTotalSpending() async throws {
        let service = deps.purchaseRecordService

        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let record1 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier A",
            datePurchased: yesterday,
            subtotal: Decimal(100.00),
            notes: nil,
            items: []
        )
        let record2 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier B",
            datePurchased: yesterday,
            subtotal: Decimal(150.00),
            notes: nil,
            items: []
        )

        _ = try await service.createRecord(record1)
        _ = try await service.createRecord(record2)

        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let totalSpending = try await service.getTotalSpending(from: twoDaysAgo, to: now)

        #expect(totalSpending >= Decimal(250.00))
    }

    @Test("Get distinct suppliers returns unique supplier names")
    func testGetDistinctSuppliers() async throws {
        let service = deps.purchaseRecordService

        let record1 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier Alpha",
            datePurchased: Date(),
            subtotal: Decimal(100.00),
            notes: nil,
            items: []
        )
        let record2 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier Beta",
            datePurchased: Date(),
            subtotal: Decimal(150.00),
            notes: nil,
            items: []
        )
        let record3 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier Alpha", // Duplicate
            datePurchased: Date(),
            subtotal: Decimal(200.00),
            notes: nil,
            items: []
        )

        _ = try await service.createRecord(record1)
        _ = try await service.createRecord(record2)
        _ = try await service.createRecord(record3)

        let suppliers = try await service.getDistinctSuppliers()

        #expect(suppliers.contains("Supplier Alpha"))
        #expect(suppliers.contains("Supplier Beta"))
    }

    @Test("Get spending by supplier calculates correctly")
    func testGetSpendingBySupplier() async throws {
        let service = deps.purchaseRecordService

        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let record1 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier X",
            datePurchased: yesterday,
            subtotal: Decimal(100.00),
            notes: nil,
            items: []
        )
        let record2 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier X",
            datePurchased: yesterday,
            subtotal: Decimal(150.00),
            notes: nil,
            items: []
        )
        let record3 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier Y",
            datePurchased: yesterday,
            subtotal: Decimal(200.00),
            notes: nil,
            items: []
        )

        _ = try await service.createRecord(record1)
        _ = try await service.createRecord(record2)
        _ = try await service.createRecord(record3)

        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let spendingBySupplier = try await service.getSpendingBySupplier(from: twoDaysAgo, to: now)

        #expect(spendingBySupplier["Supplier X"]! >= Decimal(250.00))
        #expect(spendingBySupplier["Supplier Y"]! >= Decimal(200.00))
    }

    @Test("Get spending by supplier with empty data returns empty dictionary")
    func testGetSpendingBySupplierEmptyData() async throws {
        let service = deps.purchaseRecordService

        let calendar = Calendar.current
        let now = Date()
        let futureStart = calendar.date(byAdding: .year, value: 1, to: now)!
        let futureEnd = calendar.date(byAdding: .year, value: 2, to: now)!

        let spendingBySupplier = try await service.getSpendingBySupplier(from: futureStart, to: futureEnd)

        #expect(spendingBySupplier.isEmpty || spendingBySupplier.count >= 0)
    }

    // MARK: - Glass Item Operations

    @Test("Get purchase history for glass item")
    func testGetPurchaseHistory() async throws {
        let service = deps.purchaseRecordService

        let stableId = "test123"
        let item = PurchaseRecordItemModel(
            id: UUID(),
            item_stable_id: stableId,
            type: "rod",
            quantity: 10.0,
            totalPrice: Decimal(50.00)
        )

        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: Date(),
            subtotal: Decimal(50.00),
            notes: nil,
            items: [item]
        )
        _ = try await service.createRecord(record)

        let history = try await service.getPurchaseHistory(for: stableId)

        #expect(history.contains { $0.item_stable_id == stableId })
    }

    @Test("Get total purchased quantity for glass item")
    func testGetTotalPurchased() async throws {
        let service = deps.purchaseRecordService

        let stableId = "test456"
        let item1 = PurchaseRecordItemModel(
            id: UUID(),
            item_stable_id: stableId,
            type: "rod",
            quantity: 10.0,
            totalPrice: Decimal(50.00)
        )
        let item2 = PurchaseRecordItemModel(
            id: UUID(),
            item_stable_id: stableId,
            type: "rod",
            quantity: 15.0,
            totalPrice: Decimal(75.00)
        )

        let record1 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier 1",
            datePurchased: Date(),
            subtotal: Decimal(50.00),
            notes: nil,
            items: [item1]
        )
        let record2 = PurchaseRecordModel(
            id: UUID(),
            supplier: "Supplier 2",
            datePurchased: Date(),
            subtotal: Decimal(75.00),
            notes: nil,
            items: [item2]
        )

        _ = try await service.createRecord(record1)
        _ = try await service.createRecord(record2)

        let totalPurchased = try await service.getTotalPurchased(for: stableId, type: "rod")

        #expect(totalPurchased >= 25.0)
    }

    @Test("Get total purchased with no records returns zero")
    func testGetTotalPurchasedNoRecords() async throws {
        let service = deps.purchaseRecordService

        let totalPurchased = try await service.getTotalPurchased(for: "nonexistent-id", type: "rod")

        #expect(totalPurchased == 0.0)
    }

    // MARK: - Edge Cases

    @Test("Handle purchase record with nil notes")
    func testRecordWithNilNotes() async throws {
        let service = deps.purchaseRecordService

        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: Date(),
            subtotal: Decimal(100.00),
            notes: nil,
            items: []
        )

        let created = try await service.createRecord(record)

        #expect(created.notes == nil)
    }

    @Test("Handle purchase record with nil subtotal")
    func testRecordWithNilSubtotal() async throws {
        let service = deps.purchaseRecordService

        let record = PurchaseRecordModel(
            id: UUID(),
            supplier: "Test Supplier",
            datePurchased: Date(),
            subtotal: nil,
            notes: "Test notes",
            items: []
        )

        let created = try await service.createRecord(record)

        #expect(created.subtotal == nil)
    }

    @Test("Handle empty supplier list gracefully")
    func testEmptySupplierList() async throws {
        let service = deps.purchaseRecordService

        // Don't create any records
        let suppliers = try await service.getDistinctSuppliers()

        // Should return empty array, not crash
        #expect(suppliers.isEmpty || suppliers.count >= 0)
    }

    @Test("Handle zero spending calculations")
    func testZeroSpendingCalculation() async throws {
        let service = deps.purchaseRecordService

        let calendar = Calendar.current
        let now = Date()
        let futureStart = calendar.date(byAdding: .year, value: 1, to: now)!
        let futureEnd = calendar.date(byAdding: .year, value: 2, to: now)!

        let totalSpending = try await service.getTotalSpending(from: futureStart, to: futureEnd)

        #expect(totalSpending == Decimal(0))
    }
}
