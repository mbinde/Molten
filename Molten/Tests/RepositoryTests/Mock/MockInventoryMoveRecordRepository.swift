//
//  MockInventoryMoveRecordRepository.swift
//  MoltenTests
//
//  Mock implementation of InventoryMoveRecordRepository for testing.
//

import Foundation
@testable import Molten

/// Mock implementation of InventoryMoveRecordRepository for testing
@MainActor
final class MockInventoryMoveRecordRepository: InventoryMoveRecordRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var records: [UUID: InventoryMoveRecordModel] = [:]

    // MARK: - Test Configuration

    nonisolated(unsafe) var shouldThrowError: Error?
    nonisolated(unsafe) var createCallCount = 0

    // MARK: - InventoryMoveRecordRepository

    func fetchMoveRecords(matching predicate: NSPredicate?) async throws -> [InventoryMoveRecordModel] {
        if let error = shouldThrowError { throw error }
        return Array(records.values)
    }

    func fetchMoveRecords(from fromStorageLocationId: UUID) async throws -> [InventoryMoveRecordModel] {
        if let error = shouldThrowError { throw error }
        return records.values.filter { $0.fromStorageLocationId == fromStorageLocationId }
    }

    func fetchMoveRecords(to toStorageLocationId: UUID) async throws -> [InventoryMoveRecordModel] {
        if let error = shouldThrowError { throw error }
        return records.values.filter { $0.toStorageLocationId == toStorageLocationId }
    }

    func fetchMoveRecords(on date: Date) async throws -> [InventoryMoveRecordModel] {
        if let error = shouldThrowError { throw error }
        let calendar = Calendar.current
        return records.values.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func createMoveRecord(_ record: InventoryMoveRecordModel) async throws -> InventoryMoveRecordModel {
        if let error = shouldThrowError { throw error }
        createCallCount += 1
        records[record.id] = record
        return record
    }

    func findExistingMoveRecord(
        from fromStorageLocationId: UUID,
        to toStorageLocationId: UUID,
        on date: Date
    ) async throws -> InventoryMoveRecordModel? {
        if let error = shouldThrowError { throw error }
        let calendar = Calendar.current
        return records.values.first { record in
            record.fromStorageLocationId == fromStorageLocationId &&
            record.toStorageLocationId == toStorageLocationId &&
            calendar.isDate(record.date, inSameDayAs: date)
        }
    }

    func createOrUpdateMoveRecord(_ record: InventoryMoveRecordModel) async throws -> InventoryMoveRecordModel {
        if let error = shouldThrowError { throw error }

        // Check for existing record
        if let existing = try await findExistingMoveRecord(
            from: record.fromStorageLocationId,
            to: record.toStorageLocationId,
            on: record.date
        ) {
            // Update existing - increment quantities
            let updated = InventoryMoveRecordModel(
                id: existing.id,
                fromStorageLocationId: existing.fromStorageLocationId,
                toStorageLocationId: existing.toStorageLocationId,
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
        return try await createMoveRecord(record)
    }

    func deleteMoveRecord(_ record: InventoryMoveRecordModel) async throws {
        if let error = shouldThrowError { throw error }
        records.removeValue(forKey: record.id)
    }

    // MARK: - Test Helpers

    func clearAllData() {
        records.removeAll()
        createCallCount = 0
    }

    var allRecords: [InventoryMoveRecordModel] {
        Array(records.values)
    }
}
