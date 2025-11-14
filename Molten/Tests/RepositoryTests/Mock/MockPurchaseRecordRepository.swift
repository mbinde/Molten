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

    private var records: [UUID: PurchaseRecordModel] = [:]

    // MARK: - CRUD Operations

    func getAllRecords() async throws -> [PurchaseRecordModel] {
        return records.values
            .sorted { $0.datePurchased > $1.datePurchased }
    }

    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel] {
        return records.values
            .filter { $0.datePurchased >= startDate && $0.datePurchased <= endDate }
            .sorted { $0.datePurchased > $1.datePurchased }
    }

    func fetchRecord(byId id: UUID) async throws -> PurchaseRecordModel? {
        return records[id]
    }

    func createRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        records[record.id] = record
        return record
    }

    func updateRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        guard records[record.id] != nil else {
            throw PurchaseRecordRepositoryError.recordNotFound(record.id.uuidString)
        }
        records[record.id] = record
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
        return records.values
            .filter { record in
                record.supplier.lowercased().contains(searchText) ||
                (record.notes?.lowercased().contains(searchText) ?? false)
            }
            .sorted { $0.datePurchased > $1.datePurchased }
    }

    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel] {
        return records.values
            .filter { $0.supplier == supplier }
            .sorted { $0.datePurchased > $1.datePurchased }
    }

    // MARK: - Analytics

    func getDistinctSuppliers() async throws -> [String] {
        let suppliers = Set(records.values.map { $0.supplier })
        return suppliers.sorted()
    }

    func calculateTotalSpending(from startDate: Date, to endDate: Date) async throws -> Decimal {
        let filteredRecords = try await fetchRecords(from: startDate, to: endDate)

        var total: Decimal = 0
        for record in filteredRecords {
            if let subtotal = record.subtotal {
                total += subtotal
            }
            if let tax = record.tax {
                total += tax
            }
            if let shipping = record.shipping {
                total += shipping
            }
        }

        return total
    }

    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Decimal] {
        let filteredRecords = try await fetchRecords(from: startDate, to: endDate)

        var spendingBySupplier: [String: Decimal] = [:]

        for record in filteredRecords {
            var recordTotal: Decimal = 0

            if let subtotal = record.subtotal {
                recordTotal += subtotal
            }
            if let tax = record.tax {
                recordTotal += tax
            }
            if let shipping = record.shipping {
                recordTotal += shipping
            }

            if recordTotal > 0 {
                spendingBySupplier[record.supplier, default: 0] += recordTotal
            }
        }

        return spendingBySupplier
    }

    // MARK: - Item Operations

    func fetchItemsForGlassItem(stableId: String) async throws -> [PurchaseRecordItemModel] {
        var items: [PurchaseRecordItemModel] = []

        for record in records.values {
            let matchingItems = record.items.filter { $0.item_stable_id == stableId }
            items.append(contentsOf: matchingItems)
        }

        return items
    }

    func getTotalPurchasedQuantity(for stableId: String, type: String) async throws -> Double {
        let items = try await fetchItemsForGlassItem(stableId: stableId)
        return items
            .filter { $0.type == type }
            .reduce(0.0) { $0 + $1.quantity }
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
}
