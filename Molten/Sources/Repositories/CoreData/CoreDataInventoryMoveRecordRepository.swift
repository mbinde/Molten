//
//  CoreDataInventoryMoveRecordRepository.swift
//  Molten
//
//  Created by Assistant on 2025-12-04.
//
//  Core Data implementation for inventory move record repository.
//  Tracks moves between storage locations for audit trail purposes.
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of InventoryMoveRecordRepository
/// Provides persistent storage for inventory move audit records using Core Data
class CoreDataInventoryMoveRecordRepository: @unchecked Sendable, InventoryMoveRecordRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "inventory-move-record-repository")

    // MARK: - Initialization

    /// Initialize CoreDataInventoryMoveRecordRepository with a managed object context
    /// - Parameter context: The NSManagedObjectContext to use for data operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext (user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func fetchMoveRecords(matching predicate: NSPredicate?) async throws -> [InventoryMoveRecordModel] {
        nonisolated(unsafe) let predicateCopy = predicate
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "InventoryMoveRecord")
            fetchRequest.predicate = predicateCopy
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "date", ascending: false)
            ]

            let coreDataItems = try context.fetch(fetchRequest)
            let records = coreDataItems.compactMap { self.convertToModel($0) }

            self.log.info("Fetched \(records.count) move records")
            return records
        }
    }

    func fetchMoveRecords(from fromStorageLocationId: UUID) async throws -> [InventoryMoveRecordModel] {
        let predicate = NSPredicate(format: "from_storage_location_id == %@", fromStorageLocationId as CVarArg)
        return try await fetchMoveRecords(matching: predicate)
    }

    func fetchMoveRecords(to toStorageLocationId: UUID) async throws -> [InventoryMoveRecordModel] {
        let predicate = NSPredicate(format: "to_storage_location_id == %@", toStorageLocationId as CVarArg)
        return try await fetchMoveRecords(matching: predicate)
    }

    func fetchMoveRecords(on date: Date) async throws -> [InventoryMoveRecordModel] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        return try await fetchMoveRecords(matching: predicate)
    }

    func createMoveRecord(_ record: InventoryMoveRecordModel) async throws -> InventoryMoveRecordModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryMoveRecord", in: context) else {
                throw CoreDataMoveRecordError.entityNotFound("InventoryMoveRecord")
            }
            let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

            self.updateCoreDataEntity(coreDataItem, with: record)

            try context.save()

            self.log.info("Created move record: \(record.id) from \(record.fromStorageLocationId) to \(record.toStorageLocationId)")
            return record
        }
    }

    func findExistingMoveRecord(
        from fromStorageLocationId: UUID,
        to toStorageLocationId: UUID,
        on date: Date
    ) async throws -> InventoryMoveRecordModel? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "from_storage_location_id == %@", fromStorageLocationId as CVarArg),
            NSPredicate(format: "to_storage_location_id == %@", toStorageLocationId as CVarArg),
            NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        ])

        let records = try await fetchMoveRecords(matching: predicate)
        return records.first
    }

    func createOrUpdateMoveRecord(_ record: InventoryMoveRecordModel) async throws -> InventoryMoveRecordModel {
        // Check for existing record with same (from, to, date)
        if let existing = try await findExistingMoveRecord(
            from: record.fromStorageLocationId,
            to: record.toStorageLocationId,
            on: record.date
        ) {
            // Increment quantity and containerCount
            return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                guard let coreDataItem = try self.fetchCoreDataItemById(existing.id) else {
                    throw CoreDataMoveRecordError.itemNotFound(existing.id.uuidString)
                }

                let updatedRecord = InventoryMoveRecordModel(
                    id: existing.id,
                    fromStorageLocationId: existing.fromStorageLocationId,
                    toStorageLocationId: existing.toStorageLocationId,
                    quantity: existing.quantity + record.quantity,
                    containerCount: Self.addOptionalDoubles(existing.containerCount, record.containerCount),
                    date: existing.date
                )

                self.updateCoreDataEntity(coreDataItem, with: updatedRecord)
                try context.save()

                self.log.info("Updated move record: \(existing.id) - incremented quantity by \(record.quantity)")
                return updatedRecord
            }
        } else {
            // Create new record
            return try await createMoveRecord(record)
        }
    }

    func deleteMoveRecord(_ record: InventoryMoveRecordModel) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            guard let coreDataItem = try self.fetchCoreDataItemById(record.id) else {
                self.log.warning("Attempted to delete non-existent move record: \(record.id)")
                throw CoreDataMoveRecordError.itemNotFound(record.id.uuidString)
            }

            context.delete(coreDataItem)
            try context.save()

            self.log.info("Deleted move record: \(record.id)")
        }
    }

    // MARK: - Private Helper Methods

    private nonisolated func fetchCoreDataItemById(_ id: UUID) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "InventoryMoveRecord")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private nonisolated func convertToModel(_ coreDataItem: NSManagedObject) -> InventoryMoveRecordModel? {
        guard let id = coreDataItem.value(forKey: "id") as? UUID,
              let fromStorageLocationId = coreDataItem.value(forKey: "from_storage_location_id") as? UUID,
              let toStorageLocationId = coreDataItem.value(forKey: "to_storage_location_id") as? UUID,
              let date = coreDataItem.value(forKey: "date") as? Date else {
            log.error("Failed to convert Core Data item to InventoryMoveRecordModel - missing required properties")
            return nil
        }

        let quantity = coreDataItem.value(forKey: "quantity") as? Double ?? 0.0
        let containerCount = coreDataItem.value(forKey: "container_count") as? Double

        return InventoryMoveRecordModel(
            id: id,
            fromStorageLocationId: fromStorageLocationId,
            toStorageLocationId: toStorageLocationId,
            quantity: quantity,
            containerCount: containerCount,
            date: date
        )
    }

    private nonisolated func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with record: InventoryMoveRecordModel) {
        coreDataItem.setValue(record.id, forKey: "id")
        coreDataItem.setValue(record.fromStorageLocationId, forKey: "from_storage_location_id")
        coreDataItem.setValue(record.toStorageLocationId, forKey: "to_storage_location_id")
        coreDataItem.setValue(record.quantity, forKey: "quantity")
        coreDataItem.setValue(record.containerCount, forKey: "container_count")
        coreDataItem.setValue(record.date, forKey: "date")
    }

    /// Helper to add two optional Doubles, returning nil only if both are nil
    private nonisolated static func addOptionalDoubles(_ a: Double?, _ b: Double?) -> Double? {
        switch (a, b) {
        case (.some(let aVal), .some(let bVal)):
            return aVal + bVal
        case (.some(let aVal), .none):
            return aVal
        case (.none, .some(let bVal)):
            return bVal
        case (.none, .none):
            return nil
        }
    }
}

// MARK: - Errors

enum CoreDataMoveRecordError: Error, LocalizedError {
    case entityNotFound(String)
    case itemNotFound(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .itemNotFound(let identifier):
            return "Move record not found: \(identifier)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
