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
        let sorted = recordsArray.sorted { (a: PurchaseRecordModel, b: PurchaseRecordModel) in
            let aDate = a.datePurchased
            let bDate = b.datePurchased
            return aDate > bDate
        }
        return sorted
    }

    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel] {
        let recordsArray = Array(records.values)
        let filtered = recordsArray.filter { (record: PurchaseRecordModel) in
            let datePurchased = record.datePurchased
            return datePurchased >= startDate && datePurchased <= endDate
        }
        let sorted = filtered.sorted { (a: PurchaseRecordModel, b: PurchaseRecordModel) in
            let aDate = a.datePurchased
            let bDate = b.datePurchased
            return aDate > bDate
        }
        return sorted
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
        let filtered = recordsArray.filter { (record: PurchaseRecordModel) in
            let supplier = await record.supplier
            let notes = await record.notes
            return supplier.lowercased().contains(searchText) ||
                (notes?.lowercased().contains(searchText) ?? false)
        }
        let sorted = filtered.sorted { (a: PurchaseRecordModel, b: PurchaseRecordModel) in
            let aDate = a.datePurchased
            let bDate = b.datePurchased
            return aDate > bDate
        }
        return sorted
    }

    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel] {
        let recordsArray = Array(records.values)
        let filtered = recordsArray.filter { (record: PurchaseRecordModel) in
            let recordSupplier = record.supplier
            return recordSupplier == supplier
        }
        let sorted = filtered.sorted { (a: PurchaseRecordModel, b: PurchaseRecordModel) in
            let aDate = a.datePurchased
            let bDate = b.datePurchased
            return aDate > bDate
        }
        return sorted
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
            let matchingItems = recordItems.filter { (item: PurchaseRecordItemModel) in
                let itemStableId = item.item_stable_id
                return itemStableId == stableId
            }
            items.append(contentsOf: matchingItems)
        }

        return items
    }

    func getTotalPurchasedQuantity(for stableId: String, type: String) async throws -> Double {
        let items = try await fetchItemsForGlassItem(stableId: stableId)
        return items
            .filter { (item: PurchaseRecordItemModel) in
                let itemType = item.type
                return itemType == type
            }
            .reduce(0.0) { (sum, item: PurchaseRecordItemModel) in
                let qty = item.quantity
                return sum + qty
            }
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
