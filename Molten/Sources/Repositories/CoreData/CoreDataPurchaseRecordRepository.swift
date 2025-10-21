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
class CoreDataPurchaseRecordRepository: PurchaseRecordRepository {

    private let persistenceController: PersistenceController

    nonisolated init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    // MARK: - Purchase Record CRUD

    func getAllRecords() async throws -> [PurchaseRecordModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date_purchased", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    func fetchRecords(from startDate: Date, to endDate: Date) async throws -> [PurchaseRecordModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(
                format: "date_purchased >= %@ AND date_purchased <= %@",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "date_purchased", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    func fetchRecord(byId id: UUID) async throws -> PurchaseRecordModel? {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            return self.mapToModel(entity)
        }
    }

    func createRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        let context = persistenceController.container.newBackgroundContext()

        return try await context.perform {
            let entity = PurchaseRecord(context: context)
            self.updateEntity(entity, from: record)

            try context.save()

            return record
        }
    }

    func updateRecord(_ record: PurchaseRecordModel) async throws -> PurchaseRecordModel {
        let context = persistenceController.container.newBackgroundContext()

        return try await context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", record.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw PurchaseRecordRepositoryError.recordNotFound(record.id.uuidString)
            }

            self.updateEntity(entity, from: record)

            try context.save()

            return record
        }
    }

    func deleteRecord(id: UUID) async throws {
        let context = persistenceController.container.newBackgroundContext()

        try await context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw PurchaseRecordRepositoryError.recordNotFound(id.uuidString)
            }

            context.delete(entity)
            try context.save()
        }
    }

    // MARK: - Search & Filter

    func searchRecords(text: String) async throws -> [PurchaseRecordModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(
                format: "supplier CONTAINS[cd] %@ OR notes CONTAINS[cd] %@",
                text, text
            )
            request.sortDescriptors = [NSSortDescriptor(key: "date_purchased", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    func fetchRecords(bySupplier supplier: String) async throws -> [PurchaseRecordModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = PurchaseRecord.fetchRequest()
            request.predicate = NSPredicate(format: "supplier ==[cd] %@", supplier)
            request.sortDescriptors = [NSSortDescriptor(key: "date_purchased", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["purchaserecorditem"]

            let entities = try context.fetch(request)
            return entities.compactMap { self.mapToModel($0) }
        }
    }

    // MARK: - Analytics

    func getDistinctSuppliers() async throws -> [String] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = NSFetchRequest<NSDictionary>(entityName: "PurchaseRecord")
            request.resultType = .dictionaryResultType
            request.returnsDistinctResults = true
            request.propertiesToFetch = ["supplier"]

            let results = try context.fetch(request)
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

    func fetchItemsForGlassItem(naturalKey: String) async throws -> [PurchaseRecordItemModel] {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = PurchaseRecordItem.fetchRequest()
            request.predicate = NSPredicate(format: "item_natural_key == %@", naturalKey)
            request.sortDescriptors = [NSSortDescriptor(key: "order_index", ascending: true)]

            let entities = try context.fetch(request)
            return entities.compactMap { self.mapItemToModel($0) }
        }
    }

    func getTotalPurchasedQuantity(for naturalKey: String, type: String) async throws -> Double {
        let context = persistenceController.container.viewContext

        return try await context.perform {
            let request = PurchaseRecordItem.fetchRequest()
            request.predicate = NSPredicate(
                format: "item_natural_key == %@ AND type == %@",
                naturalKey, type
            )

            let entities = try context.fetch(request)
            return entities.reduce(0.0) { $0 + $1.quantity }
        }
    }

    // MARK: - Mapping Helpers

    private func mapToModel(_ entity: PurchaseRecord) -> PurchaseRecordModel? {
        guard let id = entity.id,
              let supplier = entity.supplier,
              let datePurchased = entity.date_purchased,
              let dateAdded = entity.date_added,
              let currency = entity.currency else {
            return nil
        }

        let items = (entity.purchaserecorditem?.allObjects as? [PurchaseRecordItem] ?? [])
            .compactMap { mapItemToModel($0) }
            .sorted { $0.orderIndex < $1.orderIndex }

        return PurchaseRecordModel(
            id: id,
            supplier: supplier,
            datePurchased: datePurchased,
            dateAdded: dateAdded,
            subtotal: entity.subtotal as Decimal?,
            tax: entity.tax as Decimal?,
            shipping: entity.shipping as Decimal?,
            currency: currency,
            notes: entity.notes,
            items: items
        )
    }

    private func mapItemToModel(_ entity: PurchaseRecordItem) -> PurchaseRecordItemModel? {
        guard let id = entity.id,
              let itemNaturalKey = entity.item_natural_key,
              let type = entity.type else {
            return nil
        }

        return PurchaseRecordItemModel(
            id: id,
            itemNaturalKey: itemNaturalKey,
            type: type,
            subtype: entity.subtype,
            subsubtype: entity.subsubtype,
            quantity: entity.quantity,
            totalPrice: entity.total_price as Decimal?,
            orderIndex: entity.order_index
        )
    }

    private func updateEntity(_ entity: PurchaseRecord, from model: PurchaseRecordModel) {
        entity.id = model.id
        entity.supplier = model.supplier
        entity.date_purchased = model.datePurchased
        entity.date_added = model.dateAdded
        entity.subtotal = model.subtotal as NSDecimalNumber?
        entity.tax = model.tax as NSDecimalNumber?
        entity.shipping = model.shipping as NSDecimalNumber?
        entity.currency = model.currency
        entity.notes = model.notes

        // Remove existing items
        if let existingItems = entity.purchaserecorditem {
            for item in existingItems {
                entity.managedObjectContext?.delete(item as! NSManagedObject)
            }
        }

        // Add new items
        guard let context = entity.managedObjectContext else { return }

        for itemModel in model.items {
            let itemEntity = PurchaseRecordItem(context: context)
            itemEntity.id = itemModel.id
            itemEntity.item_natural_key = itemModel.itemNaturalKey
            itemEntity.type = itemModel.type
            itemEntity.subtype = itemModel.subtype
            itemEntity.subsubtype = itemModel.subsubtype
            itemEntity.quantity = itemModel.quantity
            itemEntity.total_price = itemModel.totalPrice as NSDecimalNumber?
            itemEntity.order_index = itemModel.orderIndex
            itemEntity.purchaserecord = entity
        }
    }
}
