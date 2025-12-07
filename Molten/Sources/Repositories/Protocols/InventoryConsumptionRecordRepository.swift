//
//  InventoryConsumptionRecordRepository.swift
//  Molten
//
//  Created by Assistant on 2025-12-04.
//
//  Repository protocol for inventory consumption audit records.
//  Tracks consumed inventory (used up, not moved) for audit trail purposes.
//

import Foundation

/// Repository protocol for inventory consumption record persistence operations.
/// These records are append-only audit logs tracking inventory consumption.
protocol InventoryConsumptionRecordRepository: Sendable {

    // MARK: - Basic CRUD Operations

    /// Fetch all consumption records matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of InventoryConsumptionRecordModel instances
    func fetchConsumptionRecords(matching predicate: NSPredicate?) async throws -> [InventoryConsumptionRecordModel]

    /// Fetch consumption records for a specific storage location
    /// - Parameter storageLocationId: The UUID of the StorageLocation
    /// - Returns: Array of InventoryConsumptionRecordModel instances from this location
    func fetchConsumptionRecords(from storageLocationId: UUID) async throws -> [InventoryConsumptionRecordModel]

    /// Fetch consumption records on a specific date
    /// - Parameter date: The date to filter by (time component is ignored)
    /// - Returns: Array of InventoryConsumptionRecordModel instances on that date
    func fetchConsumptionRecords(on date: Date) async throws -> [InventoryConsumptionRecordModel]

    /// Create a new consumption record
    /// - Parameter record: The InventoryConsumptionRecordModel to create
    /// - Returns: The created InventoryConsumptionRecordModel
    func createConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws -> InventoryConsumptionRecordModel

    /// Find existing consumption record for deduplication
    /// Same (storageLocationId, date) should increment quantity instead of creating new record.
    /// - Parameters:
    ///   - storageLocationId: Storage location UUID
    ///   - date: Date of consumption (time component is ignored for matching)
    /// - Returns: Existing record if found, nil otherwise
    func findExistingConsumptionRecord(
        from storageLocationId: UUID,
        on date: Date
    ) async throws -> InventoryConsumptionRecordModel?

    /// Create or update a consumption record (handles deduplication)
    /// If a record exists for the same (storageLocationId, date), increments quantity/containerCount.
    /// Otherwise creates a new record.
    /// - Parameter record: The InventoryConsumptionRecordModel to create or merge
    /// - Returns: The created or updated InventoryConsumptionRecordModel
    func createOrUpdateConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws -> InventoryConsumptionRecordModel

    /// Delete a consumption record
    /// Note: Consumption records are typically append-only audit logs, so deletion should be rare.
    /// - Parameter record: The InventoryConsumptionRecordModel to delete
    func deleteConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws
}
