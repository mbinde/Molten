//
//  CoreDataLogbookRepository.swift
//  Molten
//
//  Core Data implementation of LogbookRepository
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of LogbookRepository
class CoreDataLogbookRepository: LogbookRepository {
    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CRUD Operations

    func createLog(_ log: LogbookModel) async throws -> LogbookModel {
        return try await context.perform {
            let entity = Logbook(context: self.context)
            self.mapModelToEntity(log, entity: entity)

            try self.context.save()
            return log
        }
    }

    func getLog(id: UUID) async throws -> LogbookModel? {
        return try await context.perform {
            let fetchRequest = Logbook.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return try self.mapEntityToModel(entity)
        }
    }

    func getAllLogs() async throws -> [LogbookModel] {
        return try await context.perform {
            let fetchRequest = Logbook.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func getLogs(status: ProjectStatus?) async throws -> [LogbookModel] {
        return try await context.perform {
            let fetchRequest = Logbook.fetchRequest()

            if let status = status {
                fetchRequest.predicate = NSPredicate(format: "status == %@", status.rawValue)
            }

            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func updateLog(_ log: LogbookModel) async throws {
        try await context.perform {
            let fetchRequest = Logbook.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", log.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.logNotFound
            }

            self.mapModelToEntity(log, entity: entity)
            try self.context.save()
        }
    }

    func deleteLog(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = Logbook.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.logNotFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        return try await context.perform {
            let fetchRequest = Logbook.fetchRequest()
            // Check if either date_started or date_completed falls within the range, or if date_created does (when both are nil)
            fetchRequest.predicate = NSPredicate(
                format: "(date_started >= %@ AND date_started <= %@) OR (date_completed >= %@ AND date_completed <= %@) OR (date_started == nil AND date_completed == nil AND date_created >= %@ AND date_created <= %@)",
                start as CVarArg, end as CVarArg,
                start as CVarArg, end as CVarArg,
                start as CVarArg, end as CVarArg
            )
            // Sort by completion date, then start date, then created date
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "date_completed", ascending: false),
                NSSortDescriptor(key: "date_started", ascending: false),
                NSSortDescriptor(key: "date_created", ascending: false)
            ]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func getSoldLogs() async throws -> [LogbookModel] {
        return try await context.perform {
            let fetchRequest = Logbook.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "status == %@", ProjectStatus.sold.rawValue)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "sale_date", ascending: false),
                NSSortDescriptor(key: "date_created", ascending: false)
            ]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func getTotalRevenue() async throws -> Decimal {
        let soldLogs = try await getSoldLogs()
        return soldLogs.reduce(Decimal(0)) { total, log in
            total + (log.pricePoint ?? 0)
        }
    }

    // MARK: - Mapping Helpers

    private nonisolated func mapModelToEntity(_ model: LogbookModel, entity: Logbook) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.title, forKey: "title")
        entity.setValue(model.dateCreated, forKey: "date_created")
        entity.setValue(model.dateModified, forKey: "date_modified")
        entity.setValue(model.startDate, forKey: "date_started")
        entity.setValue(model.completionDate, forKey: "date_completed")

        // Store project IDs as JSON array
        if !model.basedOnProjectIds.isEmpty, let jsonData = try? JSONEncoder().encode(model.basedOnProjectIds) {
            entity.setValue(jsonData, forKey: "based_on_plan_ids")
        } else {
            entity.setValue(nil, forKey: "based_on_plan_ids")
        }
        entity.setValue(model.coe, forKey: "coe")
        entity.setValue(model.techniqueType?.rawValue, forKey: "type")
        entity.setValue(model.notes, forKey: "notes")
        entity.setValue(model.heroImageId, forKey: "hero_image_id")
        entity.setValue(model.status.rawValue, forKey: "status")
        entity.setValue(model.pricePoint as NSDecimalNumber?, forKey: "price_point")
        entity.setValue(model.saleDate, forKey: "sale_date")
        entity.setValue(model.buyerInfo, forKey: "buyer_info")
        entity.setValue(model.hoursSpent as NSDecimalNumber?, forKey: "hours_spent")
        entity.setValue(model.inventoryDeductionRecorded, forKey: "inventory_deduction_recorded")

        // Clear existing relationships
        if let existingTags = entity.value(forKey: "tags") as? Set<ProjectTag> {
            for tag in existingTags {
                self.context.delete(tag)
            }
        }
        if let existingTechniques = entity.value(forKey: "techniques") as? Set<ProjectTechnique> {
            for technique in existingTechniques {
                self.context.delete(technique)
            }
        }
        if let existingGlassItems = entity.value(forKey: "glassItems") as? Set<LogbookGlassItem> {
            for item in existingGlassItems {
                self.context.delete(item)
            }
        }

        // Create new tag entities
        for tagString in model.tags {
            let tagEntity = ProjectTag(context: self.context)
            tagEntity.setValue(UUID(), forKey: "id")
            tagEntity.setValue(tagString, forKey: "tag")
            tagEntity.setValue(Date(), forKey: "dateAdded")
            tagEntity.setValue(entity, forKey: "log")
        }

        // Create new technique entities
        if let techniques = model.techniquesUsed {
            for techniqueString in techniques {
                let techniqueEntity = ProjectTechnique(context: self.context)
                techniqueEntity.setValue(UUID(), forKey: "id")
                techniqueEntity.setValue(techniqueString, forKey: "technique")
                techniqueEntity.setValue(Date(), forKey: "dateAdded")
                techniqueEntity.setValue(entity, forKey: "log")
            }
        }

        // Create new glass item entities
        for (index, glassItem) in model.glassItems.enumerated() {
            let glassItemEntity = LogbookGlassItem(context: self.context)
            glassItemEntity.setValue(UUID(), forKey: "id")
            glassItemEntity.setValue(glassItem.stableId, forKey: "itemNaturalKey")
            glassItemEntity.setValue(Double(truncating: glassItem.quantity as NSNumber), forKey: "quantity")
            glassItemEntity.setValue(glassItem.notes, forKey: "notes")
            glassItemEntity.setValue(Int32(index), forKey: "orderIndex")
            glassItemEntity.setValue(entity, forKey: "log")
        }
    }

    private nonisolated func mapEntityToModel(_ entity: Logbook) throws -> LogbookModel {
        guard let id = entity.value(forKey: "id") as? UUID,
              let title = entity.value(forKey: "title") as? String,
              let dateCreated = entity.value(forKey: "date_created") as? Date,
              let dateModified = entity.value(forKey: "date_modified") as? Date,
              let statusString = entity.value(forKey: "status") as? String,
              let status = ProjectStatus(rawValue: statusString) else {
            throw ProjectRepositoryError.invalidData("Missing required fields in Logbook entity")
        }

        // Extract tags from relationship
        let tags: [String] = (entity.value(forKey: "tags") as? Set<ProjectTag>)?
            .compactMap { $0.value(forKey: "tag") as? String }
            .sorted() ?? []

        // Extract techniques from relationship
        let techniquesUsed: [String]? = {
            guard let techniqueSet = entity.value(forKey: "techniques") as? Set<ProjectTechnique>,
                  !techniqueSet.isEmpty else {
                return nil
            }
            return techniqueSet.compactMap { $0.value(forKey: "technique") as? String }.sorted()
        }()

        // Extract glass items from relationship
        let glassItems: [ProjectGlassItem] = (entity.value(forKey: "glassItems") as? Set<LogbookGlassItem>)?
            .sorted { ($0.value(forKey: "orderIndex") as? Int32 ?? 0) < ($1.value(forKey: "orderIndex") as? Int32 ?? 0) }
            .compactMap { glassItemEntity in
                guard let naturalKey = glassItemEntity.value(forKey: "itemNaturalKey") as? String else { return nil }
                return ProjectGlassItem(
                    id: (glassItemEntity.value(forKey: "id") as? UUID) ?? UUID(),
                    stableId: naturalKey,
                    quantity: Decimal(glassItemEntity.value(forKey: "quantity") as? Double ?? 0),
                    unit: "rods", // Default unit
                    notes: glassItemEntity.value(forKey: "notes") as? String
                )
            } ?? []

        // Extract ProjectImage metadata from relationship
        let images: [ProjectImageModel] = (entity.value(forKey: "images") as? Set<ProjectImage>)?
            .sorted { ($0.value(forKey: "order_index") as? Int32 ?? 0) < ($1.value(forKey: "order_index") as? Int32 ?? 0) }
            .compactMap { imageEntity in
                guard let imageId = imageEntity.value(forKey: "id") as? UUID,
                      let fileExtension = imageEntity.value(forKey: "file_extension") as? String,
                      let dateAdded = imageEntity.value(forKey: "date_added") as? Date else {
                    return nil
                }
                return ProjectImageModel(
                    id: imageId,
                    projectId: id,
                    projectCategory: .log,
                    fileExtension: fileExtension,
                    caption: imageEntity.value(forKey: "caption") as? String,
                    dateAdded: dateAdded,
                    order: Int(imageEntity.value(forKey: "order_index") as? Int32 ?? 0)
                )
            } ?? []

        // Decode project IDs from JSON
        let basedOnProjectIds: [UUID] = {
            guard let jsonData = entity.value(forKey: "based_on_plan_ids") as? Data,
                  let ids = try? JSONDecoder().decode([UUID].self, from: jsonData) else {
                return []
            }
            return ids
        }()

        // Decode technique type
        let techniqueType: TechniqueType? = {
            guard let typeString = entity.value(forKey: "type") as? String else { return nil }
            return TechniqueType(rawValue: typeString)
        }()

        return LogbookModel(
            id: id,
            title: title,
            dateCreated: dateCreated,
            dateModified: dateModified,
            startDate: entity.value(forKey: "date_started") as? Date,
            completionDate: entity.value(forKey: "date_completed") as? Date,
            basedOnProjectIds: basedOnProjectIds,
            tags: tags,
            coe: (entity.value(forKey: "coe") as? String) ?? "96",
            techniqueType: techniqueType,
            notes: entity.value(forKey: "notes") as? String,
            techniquesUsed: techniquesUsed,
            hoursSpent: entity.value(forKey: "hours_spent") as? Decimal,
            images: images,
            heroImageId: entity.value(forKey: "hero_image_id") as? UUID,
            glassItems: glassItems,
            pricePoint: entity.value(forKey: "price_point") as? Decimal,
            saleDate: entity.value(forKey: "sale_date") as? Date,
            buyerInfo: entity.value(forKey: "buyer_info") as? String,
            status: status,
            inventoryDeductionRecorded: entity.value(forKey: "inventory_deduction_recorded") as? Bool ?? false
        )
    }
}
