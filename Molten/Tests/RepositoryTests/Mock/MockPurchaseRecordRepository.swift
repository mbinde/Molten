//
//  MockPurchaseRecordRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of PurchaseRecordRepository for testing
//

import Foundation
@testable import Molten

/// Mock implementation of PurchaseRecordRepository for testing
/// Stores records in memory using a dictionary
@MainActor
final class MockPurchaseRecordRepository: PurchaseRecordRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var records: [UUID: PurchaseRecordModel] = [:]

    // MARK: - CRUD Operations

    func getAllRecords() async throws -> [PurchaseRecordModel] {
        let recordsArray = Array(records.values)

        // Extract dates and pair with records for sorting
        var recordsWithDates: [(record: PurchaseRecordModel, date: Date)] = []
        for record in recordsArray {
            let date = await record.datePurchased
            recordsWithDates.append((record, date))
        }

        // Sort by date descending
        recordsWithDates.sort { $0.date > $1.date }

        return recordsWithDates.map { $0.record }
    }

    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel] {
        let recordsArray = Array(records.values)
        var filtered: [PurchaseRecordModel] = []
        for record in recordsArray {
            let datePurchased = await record.datePurchased
            if datePurchased >= startDate && datePurchased <= endDate {
                filtered.append(record)
            }
        }

        // Extract dates and pair with records for sorting
        var recordsWithDates: [(record: PurchaseRecordModel, date: Date)] = []
        for record in filtered {
            let date = await record.datePurchased
            recordsWithDates.append((record, date))
        }

        // Sort by date descending
        recordsWithDates.sort { $0.date > $1.date }

        return recordsWithDates.map { $0.record }
    }

    func fetchRecord(byId id: UUID) async throws -> PurchaseRecordModel? {
        return records[id]
    }

    func createRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        let id = await record.id
        records[id] = record
        return record
    }

    func updateRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        let id = await record.id
        guard records[id] != nil else {
            throw PurchaseRecordRepositoryError.recordNotFound(id.uuidString)
        }
        records[id] = record
        return record
    }

    func deleteRecord(id: UUID) async throws {
        guard records[id] != nil else {
            throw PurchaseRecordRepositoryError.recordNotFound(id.uuidString)
        }
        records.removeValue(forKey: id)
    }

    // MARK: - Search & Filter

    func searchRecords(text: String) async throws -> [PurchaseRecordModel] {
        let searchText = text.lowercased()
        let recordsArray = Array(records.values)
        var filtered: [PurchaseRecordModel] = []
        for record in recordsArray {
            let supplier = await record.supplier
            let notes = await record.notes
            if supplier.lowercased().contains(searchText) ||
                (notes?.lowercased().contains(searchText) ?? false) {
                filtered.append(record)
            }
        }

        // Extract dates and pair with records for sorting
        var recordsWithDates: [(record: PurchaseRecordModel, date: Date)] = []
        for record in filtered {
            let date = await record.datePurchased
            recordsWithDates.append((record, date))
        }

        // Sort by date descending
        recordsWithDates.sort { $0.date > $1.date }

        return recordsWithDates.map { $0.record }
    }

    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel] {
        let recordsArray = Array(records.values)
        var filtered: [PurchaseRecordModel] = []
        for record in recordsArray {
            let recordSupplier = await record.supplier
            if recordSupplier == supplier {
                filtered.append(record)
            }
        }

        // Extract dates and pair with records for sorting
        var recordsWithDates: [(record: PurchaseRecordModel, date: Date)] = []
        for record in filtered {
            let date = await record.datePurchased
            recordsWithDates.append((record, date))
        }

        // Sort by date descending
        recordsWithDates.sort { $0.date > $1.date }

        return recordsWithDates.map { $0.record }
    }

    // MARK: - Analytics

    func getDistinctSuppliers() async throws -> [String] {
        let recordsArray = Array(records.values)
        var suppliers: Set<String> = []
        for record in recordsArray {
            let supplier = await record.supplier
            suppliers.insert(supplier)
        }
        return suppliers.sorted()
    }

    func calculateTotalSpending(from startDate: Date, to endDate: Date) async throws -> Decimal {
        let filteredRecords = try await fetchRecords(from: startDate, to: endDate)

        var total: Decimal = 0
        for record in filteredRecords {
            let subtotal = await record.subtotal
            let tax = await record.tax
            let shipping = await record.shipping

            if let subtotal = subtotal {
                total += subtotal
            }
            if let tax = tax {
                total += tax
            }
            if let shipping = shipping {
                total += shipping
            }
        }

        return total
    }

    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Decimal] {
        let filteredRecords = try await fetchRecords(from: startDate, to: endDate)

        var spendingBySupplier: [String: Decimal] = [:]

        for record in filteredRecords {
            let subtotal = await record.subtotal
            let tax = await record.tax
            let shipping = await record.shipping
            let supplier = await record.supplier

            var recordTotal: Decimal = 0

            if let subtotal = subtotal {
                recordTotal += subtotal
            }
            if let tax = tax {
                recordTotal += tax
            }
            if let shipping = shipping {
                recordTotal += shipping
            }

            if recordTotal > 0 {
                spendingBySupplier[supplier, default: 0] += recordTotal
            }
        }

        return spendingBySupplier
    }

    // MARK: - Item Operations

    func fetchItemsForGlassItem(stableId: String) async throws -> [PurchaseRecordItemModel] {
        var items: [PurchaseRecordItemModel] = []

        let recordsArray = Array(records.values)
        for record in recordsArray {
            let recordItems = await record.items
            for item in recordItems {
                let itemStableId = await item.item_stable_id
                if itemStableId == stableId {
                    items.append(item)
                }
            }
        }

        return items
    }

    func getTotalPurchasedQuantity(for stableId: String, type: String) async throws -> Double {
        let items = try await fetchItemsForGlassItem(stableId: stableId)
        var total: Double = 0.0
        for item in items {
            let itemType = await item.type
            if itemType == type {
                let qty = await item.quantity
                total += qty
            }
        }
        return total
    }

    // MARK: - Test Helpers

    /// Get count of stored records (test helper)
    func getRecordCount() async -> Int {
        return records.count
    }

    /// Clear all records (test helper)
    func clearAll() async {
        records.removeAll()
    }

    /// Clear all data (test helper, alias for clearAll for consistency with other mocks)
    func clearAllData() {
        records.removeAll()
    }
}
