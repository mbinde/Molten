//
//  PurchaseRecordRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//  Updated for new purchase record structure on 10/19/25.
//

import Foundation

/// Repository protocol for purchase record operations with items
protocol PurchaseRecordRepository {
    // MARK: - Purchase Record CRUD

    /// Fetch all purchase records
    func getAllRecords() async throws -> [PurchaseRecordModel]

    /// Fetch purchase records within a date range
    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel]

    /// Fetch a single purchase record by ID (with items)
    func fetchRecord(byId id: UUID) async throws -> PurchaseRecordModel?

    /// Create a new purchase record with items
    func createRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel

    /// Update an existing purchase record
    func updateRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel

    /// Delete a purchase record (cascades to items)
    func deleteRecord(id: UUID) async throws

    // MARK: - Search & Filter

    /// Search records by supplier name or notes
    func searchRecords(text: String) async throws -> [PurchaseRecordModel]

    /// Fetch records from a specific supplier
    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel]

    // MARK: - Analytics

    /// Get list of distinct suppliers
    func getDistinctSuppliers() async throws -> [String]

    /// Calculate total spending in date range
    func calculateTotalSpending(from startDate: Date, to endDate: Date) async throws -> Decimal

    /// Get spending grouped by supplier
    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Decimal]

    // MARK: - Item Operations

    /// Get all items for a specific glass item (across all purchases)
    func fetchItemsForGlassItem(naturalKey: String) async throws -> [PurchaseRecordItemModel]

    /// Count total quantity purchased for a specific glass item
    func getTotalPurchasedQuantity(for naturalKey: String, type: String) async throws -> Double
}
