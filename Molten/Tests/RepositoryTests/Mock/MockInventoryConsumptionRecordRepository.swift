//
//  MockInventoryConsumptionRecordRepository.swift
//  MoltenTests
//
//  Mock implementation of InventoryConsumptionRecordRepository for testing.
//

import Foundation
@testable import Molten

/// Mock implementation of InventoryConsumptionRecordRepository for testing
@MainActor
final class MockInventoryConsumptionRecordRepository: InventoryConsumptionRecordRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var records: [UUID: InventoryConsumptionRecordModel] = [:]

    // MARK: - Test Configuration

    nonisolated(unsafe) var shouldThrowError: Error?
    nonisolated(unsafe) var createCallCount = 0

    // MARK: - InventoryConsumptionRecordRepository

    func fetchConsumptionRecords(matching predicate: NSPredicate?) async throws -> [InventoryConsumptionRecordModel] {
        if let error = shouldThrowError { throw error }
        return Array(records.values)
    }

    func fetchConsumptionRecords(from storageLocationId: UUID) async throws -> [InventoryConsumptionRecordModel] {
        if let error = shouldThrowError { throw error }
        return records.values.filter { $0.storageLocationId == storageLocationId }
    }

    func fetchConsumptionRecords(on date: Date) async throws -> [InventoryConsumptionRecordModel] {
        if let error = shouldThrowError { throw error }
        let calendar = Calendar.current
        return records.values.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func createConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws -> InventoryConsumptionRecordModel {
        if let error = shouldThrowError { throw error }
        createCallCount += 1
        records[record.id] = record
        return record
    }

    func findExistingConsumptionRecord(
        from storageLocationId: UUID,
        on date: Date
    ) async throws -> InventoryConsumptionRecordModel? {
        if let error = shouldThrowError { throw error }
        let calendar = Calendar.current
        return records.values.first { record in
            record.storageLocationId == storageLocationId &&
            calendar.isDate(record.date, inSameDayAs: date)
        }
    }

    func createOrUpdateConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws -> InventoryConsumptionRecordModel {
        if let error = shouldThrowError { throw error }

        // Check for existing record
        if let existing = try await findExistingConsumptionRecord(
            from: record.storageLocationId,
            on: record.date
        ) {
            // Update existing - increment quantities
            let updated = InventoryConsumptionRecordModel(
                id: existing.id,
                storageLocationId: existing.storageLocationId,
                quantity: existing.quantity + record.quantity,
                containerCount: {
                    if let existingCount = existing.containerCount, let newCount = record.containerCount {
                        return existingCount + newCount
                    }
                    return existing.containerCount ?? record.containerCount
                }(),
                date: existing.date
            )
            records[updated.id] = updated
            return updated
        }

        // Create new record
        return try await createConsumptionRecord(record)
    }

    func deleteConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws {
        if let error = shouldThrowError { throw error }
        records.removeValue(forKey: record.id)
    }

    // MARK: - Test Helpers

    func clearAllData() {
        records.removeAll()
        createCallCount = 0
    }

    var allRecords: [InventoryConsumptionRecordModel] {
        Array(records.values)
    }
}
