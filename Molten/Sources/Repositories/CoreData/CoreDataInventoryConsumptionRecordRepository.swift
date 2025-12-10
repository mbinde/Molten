//
//  CoreDataInventoryConsumptionRecordRepository.swift
//  Molten
//
//  Created by Assistant on 2025-12-04.
//
//  Core Data implementation for inventory consumption record repository.
//  Tracks consumed inventory (used up, not moved) for audit trail purposes.
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of InventoryConsumptionRecordRepository
/// Provides persistent storage for inventory consumption audit records using Core Data
class CoreDataInventoryConsumptionRecordRepository: @unchecked Sendable, InventoryConsumptionRecordRepository {

    // MARK: - Dependencies

    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "inventory-consumption-record-repository")

    // MARK: - Initialization

    /// Initialize CoreDataInventoryConsumptionRecordRepository with a managed object context
    /// - Parameter context: The NSManagedObjectContext to use for data operations
    /// - Note: In production, pass PersistenceController.shared.cloudContext (user data)
    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.backgroundContext = context
        self.backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func fetchConsumptionRecords(matching predicate: NSPredicate?) async throws -> [InventoryConsumptionRecordModel] {
        nonisolated(unsafe) let predicateCopy = predicate
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "InventoryConsumptionRecord")
            fetchRequest.predicate = predicateCopy
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "date", ascending: false)
            ]

            let coreDataItems = try context.fetch(fetchRequest)
            let records = coreDataItems.compactMap { self.convertToModel($0) }

            self.log.info("Fetched \(records.count) consumption records")
            return records
        }
    }

    func fetchConsumptionRecords(from storageLocationId: UUID) async throws -> [InventoryConsumptionRecordModel] {
        let predicate = NSPredicate(format: "storage_location_id == %@", storageLocationId as CVarArg)
        return try await fetchConsumptionRecords(matching: predicate)
    }

    func fetchConsumptionRecords(on date: Date) async throws -> [InventoryConsumptionRecordModel] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        return try await fetchConsumptionRecords(matching: predicate)
    }

    func createConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws -> InventoryConsumptionRecordModel {
        return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
            guard let entity = NSEntityDescription.entity(forEntityName: "InventoryConsumptionRecord", in: context) else {
                throw CoreDataConsumptionRecordError.entityNotFound("InventoryConsumptionRecord")
            }
            let coreDataItem = NSManagedObject(entity: entity, insertInto: context)

            self.updateCoreDataEntity(coreDataItem, with: record)

            try context.save()

            self.log.info("Created consumption record: \(record.id) from \(record.storageLocationId)")
            return record
        }
    }

    func findExistingConsumptionRecord(
        from storageLocationId: UUID,
        on date: Date
    ) async throws -> InventoryConsumptionRecordModel? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "storage_location_id == %@", storageLocationId as CVarArg),
            NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        ])

        let records = try await fetchConsumptionRecords(matching: predicate)
        return records.first
    }

    func createOrUpdateConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws -> InventoryConsumptionRecordModel {
        // Check for existing record with same (storageLocationId, date)
        if let existing = try await findExistingConsumptionRecord(
            from: record.storageLocationId,
            on: record.date
        ) {
            // Increment quantity and containerCount
            return try await CoreDataHelper.performAsync(on: backgroundContext) { context in
                guard let coreDataItem = try self.fetchCoreDataItemById(existing.id) else {
                    throw CoreDataConsumptionRecordError.itemNotFound(existing.id.uuidString)
                }

                let updatedRecord = InventoryConsumptionRecordModel(
                    id: existing.id,
                    storageLocationId: existing.storageLocationId,
                    quantity: existing.quantity + record.quantity,
                    containerCount: Self.addOptionalDoubles(existing.containerCount, record.containerCount),
                    date: existing.date
                )

                self.updateCoreDataEntity(coreDataItem, with: updatedRecord)
                try context.save()

                self.log.info("Updated consumption record: \(existing.id) - incremented quantity by \(record.quantity)")
                return updatedRecord
            }
        } else {
            // Create new record
            return try await createConsumptionRecord(record)
        }
    }

    func deleteConsumptionRecord(_ record: InventoryConsumptionRecordModel) async throws {
        try await CoreDataHelper.performAsyncVoid(on: backgroundContext) { context in
            guard let coreDataItem = try self.fetchCoreDataItemById(record.id) else {
                self.log.warning("Attempted to delete non-existent consumption record: \(record.id)")
                throw CoreDataConsumptionRecordError.itemNotFound(record.id.uuidString)
            }

            context.delete(coreDataItem)
            try context.save()

            self.log.info("Deleted consumption record: \(record.id)")
        }
    }

    // MARK: - Private Helper Methods

    private nonisolated func fetchCoreDataItemById(_ id: UUID) throws -> NSManagedObject? {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "InventoryConsumptionRecord")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        let results = try backgroundContext.fetch(fetchRequest)
        return results.first
    }

    private nonisolated func convertToModel(_ coreDataItem: NSManagedObject) -> InventoryConsumptionRecordModel? {
        guard let id = coreDataItem.value(forKey: "id") as? UUID,
              let storageLocationId = coreDataItem.value(forKey: "storage_location_id") as? UUID,
              let date = coreDataItem.value(forKey: "date") as? Date else {
            log.error("Failed to convert Core Data item to InventoryConsumptionRecordModel - missing required properties")
            return nil
        }

        let quantity = coreDataItem.value(forKey: "quantity") as? Double ?? 0.0
        let containerCount = coreDataItem.value(forKey: "container_count") as? Double
        let unitPrice = (coreDataItem.value(forKey: "unit_price") as? NSDecimalNumber) as Decimal?
        let currency = coreDataItem.value(forKey: "currency") as? String

        return InventoryConsumptionRecordModel(
            id: id,
            storageLocationId: storageLocationId,
            quantity: quantity,
            containerCount: containerCount,
            date: date,
            unitPrice: unitPrice,
            currency: currency
        )
    }

    private nonisolated func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with record: InventoryConsumptionRecordModel) {
        coreDataItem.setValue(record.id, forKey: "id")
        coreDataItem.setValue(record.storageLocationId, forKey: "storage_location_id")
        coreDataItem.setValue(record.quantity, forKey: "quantity")
        coreDataItem.setValue(record.containerCount, forKey: "container_count")
        coreDataItem.setValue(record.date, forKey: "date")
        coreDataItem.setValue(record.unitPrice as NSDecimalNumber?, forKey: "unit_price")
        coreDataItem.setValue(record.currency, forKey: "currency")
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

enum CoreDataConsumptionRecordError: Error, LocalizedError {
    case entityNotFound(String)
    case itemNotFound(String)
    case invalidData(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .itemNotFound(let identifier):
            return "Consumption record not found: \(identifier)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}
