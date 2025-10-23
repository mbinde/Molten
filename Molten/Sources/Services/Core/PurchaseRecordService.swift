//
//  PurchaseRecordService.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  Updated for new purchase record structure on 10/19/25.
//

import Foundation

/// Service layer that handles purchase record business logic using repository pattern
class PurchaseRecordService {
    nonisolated(unsafe) private let repository: PurchaseRecordRepository

    nonisolated public init(repository: PurchaseRecordRepository) {
        self.repository = repository
    }

    // MARK: - Basic CRUD Operations

    /// Get all purchase records
    func getAllRecords() async throws -> [PurchaseRecordModel] {
        return try await repository.getAllRecords()
    }

    /// Get all purchase records within date range
    func getRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel] {
        return try await repository.fetchRecords(from: startDate, to: endDate)
    }

    /// Get a single record by ID
    func getRecord(byId id: UUID) async throws -> PurchaseRecordModel? {
        return try await repository.fetchRecord(byId: id)
    }

    /// Create a new purchase record
    func createRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        return try await repository.createRecord(record)
    }

    /// Update an existing purchase record
    func updateRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        return try await repository.updateRecord(record)
    }

    /// Delete a purchase record
    func deleteRecord(id: UUID) async throws {
        try await repository.deleteRecord(id: id)
    }

    // MARK: - Search & Filter Operations

    /// Search purchase records by text
    func searchRecords(searchText: String) async throws -> [PurchaseRecordModel] {
        return try await repository.searchRecords(text: searchText)
    }

    /// Get records filtered by supplier
    func getRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel] {
        return try await repository.fetchRecords(bySupplier: supplier)
    }

    // MARK: - Analytics Operations

    /// Get total spending for date range
    func getTotalSpending(from startDate: Date, to endDate: Date) async throws -> Decimal {
        return try await repository.calculateTotalSpending(from: startDate, to: endDate)
    }

    /// Get distinct suppliers
    func getDistinctSuppliers() async throws -> [String] {
        return try await repository.getDistinctSuppliers()
    }

    /// Get spending breakdown by supplier
    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Decimal] {
        return try await repository.getSpendingBySupplier(from: startDate, to: endDate)
    }

    // MARK: - Item Operations

    /// Get all purchase items for a specific glass item
    func getPurchaseHistory(for stableId: String) async throws -> [PurchaseRecordItemModel] {
        return try await repository.fetchItemsForGlassItem(stableId: stableId)
    }

    /// Get total quantity purchased for a glass item
    func getTotalPurchased(for stableId: String, type: String) async throws -> Double {
        return try await repository.getTotalPurchasedQuantity(for: stableId, type: type)
    }
}
