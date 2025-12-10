//
//  CoreDataPurchaseRecordRepository.swift
//  Flameworker
//
//  Created by Assistant on 10/19/25.
//  Core Data implementation for purchase record operations
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of PurchaseRecordRepository
class CoreDataPurchaseRecordRepository: @unchecked Sendable, PurchaseRecordRepository {

    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Purchase Record CRUD

    func getAllRecords() async throws -> [PurchaseRecordModel] {

        return try await self.context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date_purchased", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try self.context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel] {

        return try await self.context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(
                format: "date_purchased >= %@ AND date_purchased <= %@",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "date_purchased", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try self.context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    func fetchRecord(byId id: UUID) async throws -> PurchaseRecordModel? {

        return try await self.context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            guard let entity = try self.context.fetch(request).first else {
                return nil
            }

            return self.mapToModel(entity)
        }
    }

    func createRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        return try await self.context.perform {
            let entity = PurchaseRecord(context: self.context)
            self.updateEntity(entity, from: record)

            try CoreDataErrorHandler.save(context: self.context)

            return record
        }
    }

    func updateRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        return try await self.context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else {
                throw PurchaseRecordRepositoryError.recordNotFound(record.id.uuidString)
            }

            self.updateEntity(entity, from: record)

            try CoreDataErrorHandler.save(context: self.context)

            return record
        }
    }

    func deleteRecord(id: UUID) async throws {
        try await self.context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else {
                throw PurchaseRecordRepositoryError.recordNotFound(id.uuidString)
            }

            self.context.delete(entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    // MARK: - Search & Filter

    func searchRecords(text: String) async throws -> [PurchaseRecordModel] {

        return try await self.context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(
                format: "supplier CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
                text, text
            )
            request.sortDescriptors = [NSSortDescriptor(key: "date_purchased", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try self.context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel] {

        return try await self.context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "supplier ==[cd] %@", supplier)
            request.sortDescriptors = [NSSortDescriptor(key: "date_purchased", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try self.context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    // MARK: - Analytics

    func getDistinctSuppliers() async throws -> [String] {

        return try await self.context.perform {
            let request = NSFetchRequest<NSDictionary>(entityName: "PurchaseRecord")
            request.resultType = .dictionaryResultType
            request.returnsDistinctResults = true
            request.propertiesToFetch = ["supplier"]

            let results = try self.context.fetch(request)
            let suppliers = results.compactMap { $0["supplier"] as? String }
            return suppliers.sorted()
        }
    }

    func calculateTotalSpending(from startDate: Date, to endDate: Date) async throws -> Decimal {
        let records = try await fetchRecords(from: startDate, to: endDate)
        return records.compactMap { $0.totalPrice }.reduce(Decimal(0), +)
    }

    func getSpendingBySupplier(from startDate: Date, to endDate: Date) async throws -> [String: Decimal] {
        let records = try await fetchRecords(from: startDate, to: endDate)

        var spendingBySupplier: [String: Decimal] = [:]
        for record in records {
            if let total = record.totalPrice {
                spendingBySupplier[record.supplier, default: 0] += total
            }
        }

        return spendingBySupplier
    }

    // MARK: - Item Operations

    func fetchItemsForGlassItem(stableId: String) async throws -> [PurchaseRecordItemModel] {

        return try await self.context.perform {
            let request = PurchaseRecordItem.fetchRequest()
            request.predicate = NSPredicate(format: "item_stable_id == %@", stableId)
            request.sortDescriptors = [NSSortDescriptor(key: "order_index", ascending: true)]

            let entities = try self.context.fetch(request)
            return entities.compactMap { self.mapItemToModel($0) }
        }
    }

    func getTotalPurchasedQuantity(for stableId: String, type: String) async throws -> Double {

        return try await self.context.perform {
            let request = PurchaseRecordItem.fetchRequest()
            request.predicate = NSPredicate(
                format: "item_stable_id == %@ AND type == %@",
                stableId, type
            )

            let entities = try self.context.fetch(request)
            return entities.reduce(0.0) { $0 + $1.quantity }
        }
    }

    // MARK: - Mapping Helpers

    /// Convert Core Data entity to domain model using KVC to avoid MainActor isolation issues
    nonisolated private func mapToModel(_ entity: PurchaseRecord) -> PurchaseRecordModel? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let supplier = entity.value(forKey: "supplier") as? String,
              let datePurchased = entity.value(forKey: "date_purchased") as? Date,
              let dateAdded = entity.value(forKey: "date_added") as? Date,
              let currency = entity.value(forKey: "currency") as? String else {
            return nil
        }

        let items = (entity.value(forKey: "purchaserecorditem") as? NSSet)?.allObjects as? [PurchaseRecordItem] ?? []
        let mappedItems = items.compactMap { mapItemToModel($0) }
            .sorted { $0.orderIndex < $1.orderIndex }

        return PurchaseRecordModel(
            id: id,
            supplier: supplier,
            datePurchased: datePurchased,
            dateAdded: dateAdded,
            subtotal: (entity.value(forKey: "subtotal") as? NSDecimalNumber) as Decimal?,
            tax: (entity.value(forKey: "tax") as? NSDecimalNumber) as Decimal?,
            shipping: (entity.value(forKey: "shipping") as? NSDecimalNumber) as Decimal?,
            currency: currency,
            notes: entity.value(forKey: "notes") as? String,
            items: mappedItems,
            emailReceiptId: entity.value(forKey: "email_receipt_id") as? String,
            senderEmail: entity.value(forKey: "sender_email") as? String,
            orderNumber: entity.value(forKey: "order_number") as? String
        )
    }

    /// Convert Core Data purchase item to domain model using KVC
    nonisolated private func mapItemToModel(_ entity: PurchaseRecordItem) -> PurchaseRecordItemModel? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let item_stable_id = entity.value(forKey: "item_stable_id") as? String,
              let type = entity.value(forKey: "type") as? String else {
            return nil
        }

        return PurchaseRecordItemModel(
            id: id,
            item_stable_id: item_stable_id,
            type: type,
            subtype: entity.value(forKey: "subtype") as? String,
            subsubtype: entity.value(forKey: "subsubtype") as? String,
            quantity: (entity.value(forKey: "quantity") as? Double) ?? 0.0,
            totalPrice: (entity.value(forKey: "total_price") as? NSDecimalNumber) as Decimal?,
            orderIndex: Int32((entity.value(forKey: "order_index") as? Int16) ?? 0),
            unitPrice: (entity.value(forKey: "unit_price") as? NSDecimalNumber) as Decimal?,
            currency: entity.value(forKey: "currency") as? String
        )
    }

    // MARK: - Receipt Import Deduplication

    func fetchRecord(byEmailReceiptId emailReceiptId: String) async throws -> PurchaseRecordModel? {
        return try await self.context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "email_receipt_id == %@", emailReceiptId)
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            guard let entity = try self.context.fetch(request).first else {
                return nil
            }

            return self.mapToModel(entity)
        }
    }

    func fetchRecords(byOrderNumber orderNumber: String, supplier: String, on date: Date) async throws -> [PurchaseRecordModel] {
        return try await self.context.perform {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "order_number == %@", orderNumber),
                NSPredicate(format: "supplier ==[cd] %@", supplier),
                NSPredicate(format: "date_purchased >= %@ AND date_purchased < %@", startOfDay as NSDate, endOfDay as NSDate)
            ])
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try self.context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    func fetchRecords(bySenderEmail senderEmail: String, on date: Date) async throws -> [PurchaseRecordModel] {
        return try await self.context.perform {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "sender_email ==[cd] %@", senderEmail),
                NSPredicate(format: "date_purchased >= %@ AND date_purchased < %@", startOfDay as NSDate, endOfDay as NSDate)
            ])
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try self.context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    // MARK: - Mapping Helpers

    /// Update Core Data entity using KVC to avoid MainActor isolation issues
    nonisolated private func updateEntity(_ entity: PurchaseRecord, from model: PurchaseRecordModel) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.supplier, forKey: "supplier")
        entity.setValue(model.datePurchased, forKey: "date_purchased")
        entity.setValue(model.dateAdded, forKey: "date_added")
        entity.setValue(model.subtotal as NSDecimalNumber?, forKey: "subtotal")
        entity.setValue(model.tax as NSDecimalNumber?, forKey: "tax")
        entity.setValue(model.shipping as NSDecimalNumber?, forKey: "shipping")
        entity.setValue(model.currency, forKey: "currency")
        entity.setValue(model.notes, forKey: "notes")
        entity.setValue(model.emailReceiptId, forKey: "email_receipt_id")
        entity.setValue(model.senderEmail, forKey: "sender_email")
        entity.setValue(model.orderNumber, forKey: "order_number")

        // Remove existing items using KVC
        if let existingItems = entity.value(forKey: "purchaserecorditem") as? NSSet {
            for item in existingItems {
                entity.managedObjectContext?.delete(item as! NSManagedObject)
            }
        }

        // Add new items
        guard let context = entity.managedObjectContext else { return }

        for (index, itemModel) in model.items.enumerated() {
            let itemEntity = PurchaseRecordItem(context: context)
            itemEntity.setValue(itemModel.id, forKey: "id")
            itemEntity.setValue(itemModel.item_stable_id, forKey: "item_stable_id")
            itemEntity.setValue(itemModel.type, forKey: "type")
            itemEntity.setValue(itemModel.subtype, forKey: "subtype")
            itemEntity.setValue(itemModel.subsubtype, forKey: "subsubtype")
            itemEntity.setValue(itemModel.quantity, forKey: "quantity")
            itemEntity.setValue(itemModel.totalPrice as NSDecimalNumber?, forKey: "total_price")
            itemEntity.setValue(itemModel.unitPrice as NSDecimalNumber?, forKey: "unit_price")
            itemEntity.setValue(itemModel.currency, forKey: "currency")
            // Preserve order by using array index
            itemEntity.setValue(Int16(index), forKey: "order_index")
            itemEntity.setValue(entity, forKey: "purchaserecord")
        }
    }
}
