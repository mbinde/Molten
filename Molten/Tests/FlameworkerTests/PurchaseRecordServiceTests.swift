//
//  PurchaseRecordServiceTests.swift
//  FlameworkerTests
//
//  Tests for purchase record service functionality
//  Tests the business logic and service integration for PurchaseRecordService
//

import Testing
import Foundation
@testable import Flameworker

@Suite("PurchaseRecordService Tests")
struct PurchaseRecordServiceTests {

    // MARK: - Basic CRUD Tests

    @Test("Create purchase record")
    func testCreateRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let record = PurchaseRecordModel(
            supplier: "Frantz Art Glass",
            price: 125.50,
            notes: "Test purchase"
        )

        let created = try await service.createRecord(record)

        #expect(created.supplier == "Frantz Art Glass")
        #expect(created.price == 125.50)
        #expect(created.notes == "Test purchase")
        #expect(!created.id.isEmpty)
    }

    @Test("Create multiple purchase records")
    func testCreateMultipleRecords() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let record1 = PurchaseRecordModel(supplier: "Frantz", price: 100.0)
        let record2 = PurchaseRecordModel(supplier: "Bullseye", price: 200.0)
        let record3 = PurchaseRecordModel(supplier: "Oceanside", price: 150.0)

        _ = try await service.createRecord(record1)
        _ = try await service.createRecord(record2)
        _ = try await service.createRecord(record3)

        let allRecords = try await service.getAllRecords()
        #expect(allRecords.count == 3)
    }

    @Test("Update existing purchase record")
    func testUpdateRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let original = try await service.createRecord(
            PurchaseRecordModel(supplier: "Frantz", price: 100.0)
        )

        let updated = PurchaseRecordModel(
            id: original.id,
            supplier: "Frantz Art Glass",
            price: 125.50,
            dateAdded: original.dateAdded,
            notes: "Updated notes"
        )

        let result = try await service.updateRecord(updated)

        #expect(result.id == original.id)
        #expect(result.supplier == "Frantz Art Glass")
        #expect(result.price == 125.50)
        #expect(result.notes == "Updated notes")
    }

    @Test("Delete purchase record")
    func testDeleteRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let record = try await service.createRecord(
            PurchaseRecordModel(supplier: "Test", price: 50.0)
        )

        try await service.deleteRecord(id: record.id)

        let allRecords = try await service.getAllRecords()
        #expect(allRecords.isEmpty)
    }

    @Test("Get all records with default date range")
    func testGetAllRecordsDefaultRange() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "A", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "B", price: 200.0))

        let records = try await service.getAllRecords()
        #expect(records.count == 2)
    }

    // MARK: - Search & Filter Tests

    @Test("Search records by supplier name")
    func testSearchBySupplier() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "Frantz Art Glass", price: 100.0)
        )
        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "Bullseye Glass", price: 200.0)
        )

        let results = try await service.searchRecords(searchText: "Frantz")

        #expect(results.count == 1)
        #expect(results.first?.supplier == "Frantz Art Glass")
    }

    @Test("Search records by notes")
    func testSearchByNotes() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "Test", price: 100.0, notes: "Rods and tubes")
        )
        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "Test", price: 200.0, notes: "Frit only")
        )

        let results = try await service.searchRecords(searchText: "rods")

        #expect(results.count == 1)
        #expect(results.first?.notes?.contains("Rods") == true)
    }

    @Test("Search is case insensitive")
    func testSearchCaseInsensitive() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "Frantz Art Glass", price: 100.0)
        )

        let results1 = try await service.searchRecords(searchText: "FRANTZ")
        let results2 = try await service.searchRecords(searchText: "frantz")
        let results3 = try await service.searchRecords(searchText: "Frantz")

        #expect(results1.count == 1)
        #expect(results2.count == 1)
        #expect(results3.count == 1)
    }

    @Test("Get records by specific supplier")
    func testGetRecordsBySupplier() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 150.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Bullseye", price: 200.0))

        let frantzRecords = try await service.getRecords(bySupplier: "Frantz")

        #expect(frantzRecords.count == 2)
        #expect(frantzRecords.allSatisfy { $0.supplier == "Frantz" })
    }

    @Test("Get records within price range")
    func testGetRecordsByPriceRange() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "A", price: 50.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "B", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "C", price: 150.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "D", price: 200.0))

        let inRange = try await service.getRecords(withMinPrice: 75.0, maxPrice: 175.0)

        #expect(inRange.count == 2)
        #expect(inRange.contains { $0.price == 100.0 })
        #expect(inRange.contains { $0.price == 150.0 })
    }

    @Test("Get records with exact price boundaries")
    func testPriceRangeBoundaries() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "A", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "B", price: 200.0))

        let inRange = try await service.getRecords(withMinPrice: 100.0, maxPrice: 200.0)

        #expect(inRange.count == 2)
    }

    // MARK: - Date Range Tests

    @Test("Get records within date range")
    func testGetRecordsByDateRange() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "A", price: 100.0, dateAdded: lastWeek)
        )
        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "B", price: 200.0, dateAdded: yesterday)
        )
        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "C", price: 300.0, dateAdded: today)
        )

        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let records = try await service.getAllRecords(from: twoDaysAgo, to: today)

        #expect(records.count == 2)
    }

    // MARK: - Business Logic Tests

    @Test("Calculate total spending for all records")
    func testCalculateTotalSpending() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "A", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "B", price: 200.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "C", price: 150.0))

        let total = try await service.getTotalSpending(
            from: Date.distantPast,
            to: Date.distantFuture
        )

        #expect(total == 450.0)
    }

    @Test("Calculate total spending for date range")
    func testCalculateTotalSpendingDateRange() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "A", price: 100.0, dateAdded: lastWeek)
        )
        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "B", price: 200.0, dateAdded: yesterday)
        )
        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "C", price: 300.0, dateAdded: today)
        )

        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let total = try await service.getTotalSpending(from: twoDaysAgo, to: today)

        #expect(total == 500.0) // yesterday (200) + today (300)
    }

    @Test("Get distinct suppliers list")
    func testGetDistinctSuppliers() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Bullseye", price: 200.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 150.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Oceanside", price: 175.0))

        let suppliers = try await service.getDistinctSuppliers()

        #expect(suppliers.count == 3)
        #expect(suppliers.contains("Frantz"))
        #expect(suppliers.contains("Bullseye"))
        #expect(suppliers.contains("Oceanside"))
    }

    @Test("Suppliers list is sorted")
    func testSuppliersListSorted() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Oceanside", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 200.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Bullseye", price: 150.0))

        let suppliers = try await service.getDistinctSuppliers()

        #expect(suppliers == ["Bullseye", "Frantz", "Oceanside"])
    }

    @Test("Get spending breakdown by supplier")
    func testGetSpendingBySupplier() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 150.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Bullseye", price: 200.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Oceanside", price: 75.0))

        let spending = try await service.getSpendingBySupplier(
            from: Date.distantPast,
            to: Date.distantFuture
        )

        #expect(spending["Frantz"] == 250.0)
        #expect(spending["Bullseye"] == 200.0)
        #expect(spending["Oceanside"] == 75.0)
    }

    @Test("Spending breakdown for date range")
    func testSpendingBySupplierDateRange() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "Frantz", price: 100.0, dateAdded: lastWeek)
        )
        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "Frantz", price: 150.0, dateAdded: yesterday)
        )
        _ = try await service.createRecord(
            PurchaseRecordModel(supplier: "Bullseye", price: 200.0, dateAdded: today)
        )

        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let spending = try await service.getSpendingBySupplier(from: twoDaysAgo, to: today)

        #expect(spending["Frantz"] == 150.0) // Only yesterday's purchase
        #expect(spending["Bullseye"] == 200.0) // Today's purchase
        #expect(spending.count == 2)
    }

    @Test("Should update record detects changes")
    func testShouldUpdateRecordWithChanges() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let original = PurchaseRecordModel(
            id: "test-id",
            supplier: "Frantz",
            price: 100.0,
            notes: "Original notes"
        )

        let modified = PurchaseRecordModel(
            id: "test-id",
            supplier: "Frantz Art Glass",
            price: 100.0,
            dateAdded: original.dateAdded,
            notes: "Original notes"
        )

        let shouldUpdate = service.shouldUpdateRecord(existing: original, with: modified)
        #expect(shouldUpdate == true)
    }

    @Test("Should update record detects no changes")
    func testShouldUpdateRecordNoChanges() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let original = PurchaseRecordModel(
            id: "test-id",
            supplier: "Frantz",
            price: 100.0,
            notes: "Notes"
        )

        let identical = PurchaseRecordModel(
            id: "test-id",
            supplier: "Frantz",
            price: 100.0,
            dateAdded: original.dateAdded,
            notes: "Notes"
        )

        let shouldUpdate = service.shouldUpdateRecord(existing: original, with: identical)
        #expect(shouldUpdate == false)
    }

    // MARK: - Edge Cases

    @Test("Create record with empty notes normalizes to nil")
    func testEmptyNotesNormalization() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let record = PurchaseRecordModel(
            supplier: "Test",
            price: 100.0,
            notes: ""
        )

        let created = try await service.createRecord(record)
        #expect(created.notes == nil)
    }

    @Test("Create record trims whitespace from supplier")
    func testSupplierWhitespaceTrimming() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let record = PurchaseRecordModel(
            supplier: "  Frantz Art Glass  ",
            price: 100.0
        )

        let created = try await service.createRecord(record)
        #expect(created.supplier == "Frantz Art Glass")
    }

    @Test("Empty search returns all records")
    func testEmptySearchReturnsAll() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "A", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "B", price: 200.0))

        let results = try await service.searchRecords(searchText: "")
        #expect(results.count == 2)
    }

    @Test("Search with no matches returns empty")
    func testSearchNoMatches() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 100.0))

        let results = try await service.searchRecords(searchText: "Oceanside")
        #expect(results.isEmpty)
    }

    @Test("Price range with no matches returns empty")
    func testPriceRangeNoMatches() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "A", price: 100.0))
        _ = try await service.createRecord(PurchaseRecordModel(supplier: "B", price: 200.0))

        let results = try await service.getRecords(withMinPrice: 300.0, maxPrice: 400.0)
        #expect(results.isEmpty)
    }

    @Test("Supplier filter with no matches returns empty")
    func testSupplierFilterNoMatches() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        _ = try await service.createRecord(PurchaseRecordModel(supplier: "Frantz", price: 100.0))

        let results = try await service.getRecords(bySupplier: "Oceanside")
        #expect(results.isEmpty)
    }

    @Test("Total spending with no records returns zero")
    func testTotalSpendingNoRecords() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let total = try await service.getTotalSpending(
            from: Date.distantPast,
            to: Date.distantFuture
        )

        #expect(total == 0.0)
    }

    @Test("Distinct suppliers with no records returns empty")
    func testDistinctSuppliersNoRecords() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let suppliers = try await service.getDistinctSuppliers()
        #expect(suppliers.isEmpty)
    }

    @Test("Spending by supplier with no records returns empty")
    func testSpendingBySupplierNoRecords() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let spending = try await service.getSpendingBySupplier(
            from: Date.distantPast,
            to: Date.distantFuture
        )

        #expect(spending.isEmpty)
    }

    @Test("Update non-existent record throws error")
    func testUpdateNonExistentRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let record = PurchaseRecordModel(
            id: "non-existent-id",
            supplier: "Test",
            price: 100.0
        )

        await #expect(throws: Error.self) {
            _ = try await service.updateRecord(record)
        }
    }

    @Test("Delete non-existent record succeeds silently")
    func testDeleteNonExistentRecord() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        // Should not throw
        try await service.deleteRecord(id: "non-existent-id")

        let records = try await service.getAllRecords()
        #expect(records.isEmpty)
    }

    // MARK: - Multiple Purchases Pattern Tests

    @Test("Track monthly spending pattern")
    func testMonthlySpendingPattern() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let calendar = Calendar.current
        let now = Date()

        // Create purchases across 3 months
        for monthOffset in 0..<3 {
            let date = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
            _ = try await service.createRecord(
                PurchaseRecordModel(
                    supplier: "Frantz",
                    price: Double((monthOffset + 1) * 100),
                    dateAdded: date
                )
            )
        }

        let allRecords = try await service.getAllRecords()
        #expect(allRecords.count == 3)

        let total = try await service.getTotalSpending(
            from: Date.distantPast,
            to: Date.distantFuture
        )
        #expect(total == 600.0) // 100 + 200 + 300
    }

    @Test("Track supplier diversity")
    func testSupplierDiversity() async throws {
        let repository = MockPurchaseRecordRepository()
        let service = PurchaseRecordService(repository: repository)

        let suppliers = ["Frantz", "Bullseye", "Oceanside", "CIM", "Effetre"]

        for supplier in suppliers {
            _ = try await service.createRecord(
                PurchaseRecordModel(supplier: supplier, price: 100.0)
            )
        }

        let distinctSuppliers = try await service.getDistinctSuppliers()
        #expect(distinctSuppliers.count == 5)
    }
}
