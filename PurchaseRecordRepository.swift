//
//  PurchaseRecordRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Repository protocol for purchase record operations, following established pattern
protocol PurchaseRecordRepository {
    // Basic CRUD operations
    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel]
    func fetchRecord(byId id: String) async throws -> PurchaseRecordModel?
    func createRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel
    func updateRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel
    func deleteRecord(id: String) async throws
    
    // Search & Filter operations
    func searchRecords(text: String) async throws -> [PurchaseRecordModel]
    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel]
    func fetchRecords(withMinPrice minPrice: Double, maxPrice: Double) async throws -> [PurchaseRecordModel]
    
    // Business logic operations
    func calculateTotalSpending(from startDate: Date, to endDate: Date) async throws -> Double
    func getDistinctSuppliers() async throws -> [String]
    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Double]
}