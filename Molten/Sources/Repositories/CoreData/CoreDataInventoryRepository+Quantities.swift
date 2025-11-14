//
//  CoreDataInventoryRepository+Quantities.swift
//  Molten
//
//  Quantity manipulation operations (add, subtract, set)
//  Part of CoreDataInventoryRepository split to maintain <300 LOC per file
//

@preconcurrency import CoreData
import Foundation
import OSLog

// MARK: - Quantity Operations

extension CoreDataInventoryRepository {

    func getTotalQuantity(forItem item_stable_id: String) async throws -> Double {
        let inventoryRecords = try await fetchInventory(forItem: item_stable_id)
        var total = 0.0
        for record in inventoryRecords {
            total += await record.quantity
        }
        return total
    }

    func getTotalQuantity(forItem item_stable_id: String, type: String) async throws -> Double {
        let inventoryRecords = try await fetchInventory(forItem: item_stable_id, type: type)
        var total = 0.0
        for record in inventoryRecords {
            total += await record.quantity
        }
        return total
    }

    func addQuantity(_ quantity: Double, toItem item_stable_id: String, type: String) async throws -> InventoryModel {
        let cleanType = InventoryModel.cleanType(type)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel, Error>) in
            context.perform {
                do {
                    // Look for existing inventory record
                    let existingRecords = try self.fetchInventorySync(forItem: item_stable_id, type: cleanType)

                    if let existingRecord = existingRecords.first {
                        // Update existing record
                        let updatedRecord = InventoryModel(
                            id: existingRecord.id,
                            item_stable_id: existingRecord.item_stable_id,
                            type: existingRecord.type,  // Use non-optional accessor
                            quantity: existingRecord.quantity + quantity,
                            date_added: existingRecord.date_added,
                            date_modified: Date() // Set to current time on update
                        )

                        guard let coreDataItem = try self.fetchCoreDataItemSync(byId: existingRecord.id) else {
                            throw CoreDataInventoryRepositoryError.itemNotFound(existingRecord.id.uuidString)
                        }

                        self.updateCoreDataEntity(coreDataItem, with: updatedRecord)
                        try self.context.save()

                        continuation.resume(returning: updatedRecord)
                    } else {
                        // Create new record
                        let newRecord = InventoryModel(
                            item_stable_id: item_stable_id,
                            type: cleanType,
                            quantity: quantity
                        )

                        guard let entity = NSEntityDescription.entity(forEntityName: "Inventory", in: self.context) else {
                            throw CoreDataInventoryRepositoryError.entityNotFound("Inventory")
                        }
                        let coreDataItem = NSManagedObject(entity: entity, insertInto: self.context)

                        self.updateCoreDataEntity(coreDataItem, with: newRecord)
                        try self.context.save()

                        continuation.resume(returning: newRecord)
                    }

                } catch {
                    self.log.error("Failed to add quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func subtractQuantity(_ quantity: Double, fromItem item_stable_id: String, type: String) async throws -> InventoryModel? {
        let cleanType = InventoryModel.cleanType(type)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<InventoryModel?, Error>) in
            context.perform {
                do {
                    // Look for existing inventory record
                    let existingRecords = try self.fetchInventorySync(forItem: item_stable_id, type: cleanType)

                    guard let existingRecord = existingRecords.first else {
                        throw CoreDataInventoryRepositoryError.itemNotFound("No inventory found for \(item_stable_id) - \(cleanType)")
                    }

                    guard let coreDataItem = try self.fetchCoreDataItemSync(byId: existingRecord.id) else {
                        throw CoreDataInventoryRepositoryError.itemNotFound(existingRecord.id.uuidString)
                    }

                    let newQuantity = existingRecord.quantity - quantity

                    if newQuantity <= 0 {
                        // Delete the record if quantity reaches zero or below
                        self.context.delete(coreDataItem)
                        try self.context.save()
                        continuation.resume(returning: nil)
                    } else {
                        // Update the record with new quantity
                        let updatedRecord = InventoryModel(
                            id: existingRecord.id,
                            item_stable_id: existingRecord.item_stable_id,
                            type: existingRecord.type,  // Use non-optional accessor
                            quantity: newQuantity,
                            date_added: existingRecord.date_added,
                            date_modified: Date() // Set to current time on update
                        )

                        self.updateCoreDataEntity(coreDataItem, with: updatedRecord)
                        try self.context.save()
                        continuation.resume(returning: updatedRecord)
                    }

                } catch {
                    self.log.error("Failed to subtract quantity: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func setQuantity(_ quantity: Double, forItem item_stable_id: String, type: String) async throws -> InventoryModel? {
        let cleanType = InventoryModel.cleanType(type)

        if quantity <= 0 {
            // Delete any existing records for this item-type combination
            try await deleteInventory(forItem: item_stable_id, type: cleanType)
            return nil
        } else {
            // Look for existing record and update, or create new one
            let existingRecords = try await fetchInventory(forItem: item_stable_id, type: cleanType)

            if let existingRecord = existingRecords.first {
                // Update existing record
                let updatedRecord = InventoryModel(
                    id: existingRecord.id,
                    item_stable_id: existingRecord.item_stable_id,
                    type: existingRecord.type,  // Use non-optional accessor
                    quantity: quantity,
                    date_added: existingRecord.date_added,
                    date_modified: Date() // Set to current time on update
                )
                return try await updateInventory(updatedRecord)
            } else {
                // Create new record
                let newRecord = InventoryModel(
                    item_stable_id: item_stable_id,
                    type: cleanType,
                    quantity: quantity
                )
                return try await createInventory(newRecord)
            }
        }
    }
}
