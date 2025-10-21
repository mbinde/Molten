//
//  MockPurchaseRecordRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  Updated for new purchase record structure on 10/19/25.
//

import Foundation

/// Mock implementation of PurchaseRecordRepository for testing
class MockPurchaseRecordRepository: @unchecked Sendable, PurchaseRecordRepository {

    // In-memory storage
    nonisolated(unsafe) private var records: [UUID: PurchaseRecordModel] = [:]

    // MARK: - Initialization

    nonisolated init() {}

    // MARK: - Purchase Record CRUD

    func getAllRecords() async throws -> [PurchaseRecordModel] {
        return Array(records.values).sorted { $0.datePurchased > $1.datePurchased }
    }

    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel] {
        return records.values
            .filter { $0.isWithinDateRange(from: startDate, to: endDate) }
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
        return records.values
            .filter { $0.matchesSearchText(text) }
            .sorted { $0.datePurchased > $1.datePurchased }
    }

    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel] {
        return records.values
            .filter { $0.supplier.lowercased() == supplier.lowercased() }
            .sorted { $0.datePurchased > $1.datePurchased }
    }

    // MARK: - Analytics

    func getDistinctSuppliers() async throws -> [String] {
        let suppliers = Set(records.values.map { $0.supplier })
        return Array(suppliers).sorted()
    }

    func calculateTotalSpending(from startDate: Date, to endDate: Date) async throws -> Decimal {
        let filteredRecords = records.values.filter { $0.isWithinDateRange(from: startDate, to: endDate) }
        return filteredRecords.compactMap { $0.totalPrice }.reduce(0, +)
    }

    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Decimal] {
        let filteredRecords = records.values.filter { $0.isWithinDateRange(from: startDate, to: endDate) }

        var spendingBySupplier: [String: Decimal] = [:]
        for record in filteredRecords {
            if let total = record.totalPrice {
                spendingBySupplier[record.supplier, default: 0] += total
            }
        }

        return spendingBySupplier
    }

    // MARK: - Item Operations

    func fetchItemsForGlassItem(naturalKey: String) async throws -> [PurchaseRecordItemModel] {
        var allItems: [PurchaseRecordItemModel] = []

        for record in records.values {
            let matchingItems = record.items.filter { $0.itemNaturalKey == naturalKey }
            allItems.append(contentsOf: matchingItems)
        }

        return allItems
    }

    func getTotalPurchasedQuantity(for naturalKey: String, type: String) async throws -> Double {
        var total: Double = 0

        for record in records.values {
            let matchingItems = record.items.filter {
                $0.itemNaturalKey == naturalKey && $0.type == type
            }
            total += matchingItems.reduce(0) { $0 + $1.quantity }
        }

        return total
    }

    // MARK: - Test Helpers

    /// Clear all records (for testing)
    nonisolated func clearAll() async {
        records.removeAll()
    }

    /// Get count of records (for testing)
    nonisolated func getRecordCount() async -> Int {
        return records.count
    }
}

/// Errors specific to purchase record repository
enum PurchaseRecordRepositoryError: Error, LocalizedError {
    case recordNotFound(String)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .recordNotFound(let id):
            return "Purchase record not found with ID: \(id)"
        case .invalidData:
            return "Invalid purchase record data"
        }
    }
}
