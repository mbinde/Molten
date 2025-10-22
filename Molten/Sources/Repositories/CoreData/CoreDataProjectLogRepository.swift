//
//  CoreDataProjectLogRepository.swift
//  Flameworker
//
//  Core Data implementation of ProjectLogRepository
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of ProjectLogRepository
class CoreDataProjectLogRepository: ProjectLogRepository {
    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CRUD Operations

    func createLog(_ log: ProjectLogModel) async throws -> ProjectLogModel {
        return try await context.perform {
            let entity = ProjectLog(context: self.context)
            self.mapModelToEntity(log, entity: entity)

            try self.context.save()
            return log
        }
    }

    func getLog(id: UUID) async throws -> ProjectLogModel? {
        return try await context.perform {
            let fetchRequest = ProjectLog.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return try self.mapEntityToModel(entity)
        }
    }

    func getAllLogs() async throws -> [ProjectLogModel] {
        return try await context.perform {
            let fetchRequest = ProjectLog.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func getLogs(status: ProjectStatus?) async throws -> [ProjectLogModel] {
        return try await context.perform {
            let fetchRequest = ProjectLog.fetchRequest()

            if let status = status {
                fetchRequest.predicate = NSPredicate(format: "status == %@", status.rawValue)
            }

            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func updateLog(_ log: ProjectLogModel) async throws {
        try await context.perform {
            let fetchRequest = ProjectLog.fetchRequest()
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
            let fetchRequest = ProjectLog.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.logNotFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [ProjectLogModel] {
        return try await context.perform {
            let fetchRequest = ProjectLog.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "project_date >= %@ AND project_date <= %@",
                start as CVarArg,
                end as CVarArg
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "project_date", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }
    }

    func getSoldLogs() async throws -> [ProjectLogModel] {
        return try await context.perform {
            let fetchRequest = ProjectLog.fetchRequest()
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

    private nonisolated func mapModelToEntity(_ model: ProjectLogModel, entity: ProjectLog) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.title, forKey: "title")
        entity.setValue(model.dateCreated, forKey: "date_created")
        entity.setValue(model.dateModified, forKey: "date_modified")
        entity.setValue(model.projectDate, forKey: "project_date")
        entity.setValue(model.basedOnPlanId, forKey: "based_on_plan_id")
        entity.setValue(model.coe, forKey: "coe")
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
        if let existingGlassItems = entity.value(forKey: "glassItems") as? Set<ProjectLogGlassItem> {
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
            let glassItemEntity = ProjectLogGlassItem(context: self.context)
            glassItemEntity.setValue(UUID(), forKey: "id")
            glassItemEntity.setValue(glassItem.naturalKey, forKey: "itemNaturalKey")
            glassItemEntity.setValue(Double(truncating: glassItem.quantity as NSNumber), forKey: "quantity")
            glassItemEntity.setValue(glassItem.notes, forKey: "notes")
            glassItemEntity.setValue(Int32(index), forKey: "orderIndex")
            glassItemEntity.setValue(entity, forKey: "log")
        }
    }

    private nonisolated func mapEntityToModel(_ entity: ProjectLog) throws -> ProjectLogModel {
        guard let id = entity.value(forKey: "id") as? UUID,
              let title = entity.value(forKey: "title") as? String,
              let dateCreated = entity.value(forKey: "date_created") as? Date,
              let dateModified = entity.value(forKey: "date_modified") as? Date,
              let statusString = entity.value(forKey: "status") as? String,
              let status = ProjectStatus(rawValue: statusString) else {
            throw ProjectRepositoryError.invalidData("Missing required fields in ProjectLog entity")
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
        let glassItems: [ProjectGlassItem] = (entity.value(forKey: "glassItems") as? Set<ProjectLogGlassItem>)?
            .sorted { ($0.value(forKey: "orderIndex") as? Int32 ?? 0) < ($1.value(forKey: "orderIndex") as? Int32 ?? 0) }
            .compactMap { glassItemEntity in
                guard let naturalKey = glassItemEntity.value(forKey: "itemNaturalKey") as? String else { return nil }
                return ProjectGlassItem(
                    id: (glassItemEntity.value(forKey: "id") as? UUID) ?? UUID(),
                    naturalKey: naturalKey,
                    quantity: Decimal(glassItemEntity.value(forKey: "quantity") as? Double ?? 0),
                    unit: "rods", // Default unit
                    notes: glassItemEntity.value(forKey: "notes") as? String
                )
            } ?? []

        return ProjectLogModel(
            id: id,
            title: title,
            dateCreated: dateCreated,
            dateModified: dateModified,
            projectDate: entity.value(forKey: "project_date") as? Date,
            basedOnPlanId: entity.value(forKey: "based_on_plan_id") as? UUID,
            tags: tags,
            coe: (entity.value(forKey: "coe") as? String) ?? "any",
            notes: entity.value(forKey: "notes") as? String,
            techniquesUsed: techniquesUsed,
            hoursSpent: entity.value(forKey: "hours_spent") as? Decimal,
            images: [], // TODO: Fetch related ProjectImage entities
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
