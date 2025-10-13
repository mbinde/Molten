//
//  PurchaseRecordService.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Service layer that handles purchase record business logic using repository pattern
class PurchaseRecordService {
    private let repository: PurchaseRecordRepository
    
    public init(repository: PurchaseRecordRepository) {
        self.repository = repository
    }
    
    // MARK: - Basic CRUD Operations
    
    /// Get all purchase records within date range
    func getAllRecords(from startDate: Date = Date.distantPast, to endDate: Date = Date.distantFuture) async throws -> [PurchaseRecordModel] {
        return try await repository.fetchRecords(from: startDate, to: endDate)
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
    func deleteRecord(id: String) async throws {
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
    
    /// Get records within price range
    func getRecords(withMinPrice minPrice: Double, maxPrice: Double) async throws -> [PurchaseRecordModel] {
        return try await repository.fetchRecords(withMinPrice: minPrice, maxPrice: maxPrice)
    }
    
    // MARK: - Business Logic Operations
    
    /// Get total spending for date range
    func getTotalSpending(from startDate: Date, to endDate: Date) async throws -> Double {
        return try await repository.calculateTotalSpending(from: startDate, to: endDate)
    }
    
    /// Get distinct suppliers
    func getDistinctSuppliers() async throws -> [String] {
        return try await repository.getDistinctSuppliers()
    }
    
    /// Get spending breakdown by supplier
    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Double] {
        return try await repository.getSpendingBySupplier(from: startDate, to: endDate)
    }
    
    /// Determine if an existing record should be updated with new data
    func shouldUpdateRecord(existing: PurchaseRecordModel, with new: PurchaseRecordModel) -> Bool {
        return PurchaseRecordModel.hasChanges(existing: existing, new: new)
    }
}