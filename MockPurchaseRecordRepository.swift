//
//  MockPurchaseRecordRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/12/25.
//

import Foundation

/// Mock implementation of PurchaseRecordRepository for testing
class MockPurchaseRecordRepository: PurchaseRecordRepository {
    private var records: [PurchaseRecordModel] = []
    
    // MARK: - Basic CRUD Operations
    
    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel] {
        return records.filter { record in
            record.isWithinDateRange(from: startDate, to: endDate)
        }
    }
    
    func fetchRecord(byId id: String) async throws -> PurchaseRecordModel? {
        return records.first { $0.id == id }
    }
    
    func createRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        var newRecord = record
        if newRecord.id.isEmpty {
            newRecord = PurchaseRecordModel(
                id: UUID().uuidString,
                supplier: record.supplier,
                price: record.price,
                dateAdded: record.dateAdded,
                notes: record.notes
            )
        }
        records.append(newRecord)
        return newRecord
    }
    
    func updateRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
            return record
        } else {
            throw NSError(domain: "MockRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Record not found"])
        }
    }
    
    func deleteRecord(id: String) async throws {
        records.removeAll { $0.id == id }
    }
    
    // MARK: - Search & Filter Operations
    
    func searchRecords(text: String) async throws -> [PurchaseRecordModel] {
        guard !text.isEmpty else { return records }
        return records.filter { $0.matchesSearchText(text) }
    }
    
    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel] {
        return records.filter { $0.supplier == supplier }
    }
    
    func fetchRecords(withMinPrice minPrice: Double, maxPrice: Double) async throws -> [PurchaseRecordModel] {
        return records.filter { record in
            record.price >= minPrice && record.price <= maxPrice
        }
    }
    
    // MARK: - Business Logic Operations
    
    func calculateTotalSpending(from startDate: Date, to endDate: Date) async throws -> Double {
        let filteredRecords = try await fetchRecords(from: startDate, to: endDate)
        return filteredRecords.reduce(0.0) { $0 + $1.price }
    }
    
    func getDistinctSuppliers() async throws -> [String] {
        return Array(Set(records.map { $0.supplier })).sorted()
    }
    
    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Double] {
        let filteredRecords = try await fetchRecords(from: startDate, to: endDate)
        var spendingBySupplier: [String: Double] = [:]
        
        for record in filteredRecords {
            spendingBySupplier[record.supplier, default: 0.0] += record.price
        }
        
        return spendingBySupplier
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        records.removeAll()
    }
    
    func addTestRecords(_ testRecords: [PurchaseRecordModel]) {
        records.append(contentsOf: testRecords)
    }
}