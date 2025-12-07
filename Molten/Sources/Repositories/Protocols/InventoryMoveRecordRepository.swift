//
//  InventoryMoveRecordRepository.swift
//  Molten
//
//  Created by Assistant on 2025-12-04.
//
//  Repository protocol for inventory move audit records.
//  Tracks moves between storage locations for audit trail purposes.
//

import Foundation

/// Repository protocol for inventory move record persistence operations.
/// These records are append-only audit logs tracking inventory moves between locations.
protocol InventoryMoveRecordRepository: Sendable {

    // MARK: - Basic CRUD Operations

    /// Fetch all move records matching the given predicate
    /// - Parameter predicate: Optional predicate for filtering
    /// - Returns: Array of InventoryMoveRecordModel instances
    func fetchMoveRecords(matching predicate: NSPredicate?) async throws -> [InventoryMoveRecordModel]

    /// Fetch move records for a specific source storage location
    /// - Parameter fromStorageLocationId: The UUID of the source StorageLocation
    /// - Returns: Array of InventoryMoveRecordModel instances from this location
    func fetchMoveRecords(from fromStorageLocationId: UUID) async throws -> [InventoryMoveRecordModel]

    /// Fetch move records for a specific destination storage location
    /// - Parameter toStorageLocationId: The UUID of the destination StorageLocation
    /// - Returns: Array of InventoryMoveRecordModel instances to this location
    func fetchMoveRecords(to toStorageLocationId: UUID) async throws -> [InventoryMoveRecordModel]

    /// Fetch move records on a specific date
    /// - Parameter date: The date to filter by (time component is ignored)
    /// - Returns: Array of InventoryMoveRecordModel instances on that date
    func fetchMoveRecords(on date: Date) async throws -> [InventoryMoveRecordModel]

    /// Create a new move record
    /// - Parameter record: The InventoryMoveRecordModel to create
    /// - Returns: The created InventoryMoveRecordModel
    func createMoveRecord(_ record: InventoryMoveRecordModel) async throws -> InventoryMoveRecordModel

    /// Find existing move record for deduplication
    /// Same (fromStorageLocationId, toStorageLocationId, date) should increment quantity instead of creating new record.
    /// - Parameters:
    ///   - fromStorageLocationId: Source storage location UUID
    ///   - toStorageLocationId: Destination storage location UUID
    ///   - date: Date of move (time component is ignored for matching)
    /// - Returns: Existing record if found, nil otherwise
    func findExistingMoveRecord(
        from fromStorageLocationId: UUID,
        to toStorageLocationId: UUID,
        on date: Date
    ) async throws -> InventoryMoveRecordModel?

    /// Create or update a move record (handles deduplication)
    /// If a record exists for the same (from, to, date), increments quantity/containerCount.
    /// Otherwise creates a new record.
    /// - Parameter record: The InventoryMoveRecordModel to create or merge
    /// - Returns: The created or updated InventoryMoveRecordModel
    func createOrUpdateMoveRecord(_ record: InventoryMoveRecordModel) async throws -> InventoryMoveRecordModel

    /// Delete a move record
    /// Note: Move records are typically append-only audit logs, so deletion should be rare.
    /// - Parameter record: The InventoryMoveRecordModel to delete
    func deleteMoveRecord(_ record: InventoryMoveRecordModel) async throws
}
