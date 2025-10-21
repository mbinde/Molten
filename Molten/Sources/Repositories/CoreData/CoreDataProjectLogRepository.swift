//
//  CoreDataProjectLogRepository.swift
//  Flameworker
//
//  Core Data implementation of ProjectLogRepository
//

import Foundation
import CoreData

/// Core Data implementation of ProjectLogRepository
actor CoreDataProjectLogRepository: ProjectLogRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
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

    private func mapModelToEntity(_ model: ProjectLogModel, entity: ProjectLog) {
        entity.id = model.id
        entity.title = model.title
        entity.date_created = model.dateCreated
        entity.date_modified = model.dateModified
        entity.project_date = model.projectDate
        entity.based_on_plan_id = model.basedOnPlanId
        entity.coe = model.coe
        entity.notes = model.notes
        entity.hero_image_id = model.heroImageId
        entity.status = model.status.rawValue
        entity.price_point = model.pricePoint as NSDecimalNumber?
        entity.sale_date = model.saleDate
        entity.buyer_info = model.buyerInfo
        entity.hours_spent = model.hoursSpent as NSDecimalNumber?
        entity.inventory_deduction_recorded = model.inventoryDeductionRecorded

        // Clear existing relationships
        if let existingTags = entity.tags as? Set<ProjectTag> {
            for tag in existingTags {
                self.context.delete(tag)
            }
        }
        if let existingTechniques = entity.techniques as? Set<ProjectTechnique> {
            for technique in existingTechniques {
                self.context.delete(technique)
            }
        }
        if let existingGlassItems = entity.glassItems as? Set<ProjectLogGlassItem> {
            for item in existingGlassItems {
                self.context.delete(item)
            }
        }

        // Create new tag entities
        for tagString in model.tags {
            let tagEntity = ProjectTag(context: self.context)
            tagEntity.id = UUID()
            tagEntity.tag = tagString
            tagEntity.dateAdded = Date()
            tagEntity.log = entity
        }

        // Create new technique entities
        if let techniques = model.techniquesUsed {
            for techniqueString in techniques {
                let techniqueEntity = ProjectTechnique(context: self.context)
                techniqueEntity.id = UUID()
                techniqueEntity.technique = techniqueString
                techniqueEntity.dateAdded = Date()
                techniqueEntity.log = entity
            }
        }

        // Create new glass item entities
        for (index, glassItem) in model.glassItems.enumerated() {
            let glassItemEntity = ProjectLogGlassItem(context: self.context)
            glassItemEntity.id = UUID()
            glassItemEntity.itemNaturalKey = glassItem.naturalKey
            glassItemEntity.quantity = Double(truncating: glassItem.quantity as NSNumber)
            glassItemEntity.notes = glassItem.notes
            glassItemEntity.orderIndex = Int32(index)
            glassItemEntity.log = entity
        }
    }

    private func mapEntityToModel(_ entity: ProjectLog) throws -> ProjectLogModel {
        guard let id = entity.id,
              let title = entity.title,
              let dateCreated = entity.date_created,
              let dateModified = entity.date_modified,
              let statusString = entity.status,
              let status = ProjectStatus(rawValue: statusString) else {
            throw ProjectRepositoryError.invalidData("Missing required fields in ProjectLog entity")
        }

        // Extract tags from relationship
        let tags: [String] = (entity.tags as? Set<ProjectTag>)?
            .compactMap { $0.tag }
            .sorted() ?? []

        // Extract techniques from relationship
        let techniquesUsed: [String]? = {
            guard let techniqueSet = entity.techniques as? Set<ProjectTechnique>,
                  !techniqueSet.isEmpty else {
                return nil
            }
            return techniqueSet.compactMap { $0.technique }.sorted()
        }()

        // Extract glass items from relationship
        let glassItems: [ProjectGlassItem] = (entity.glassItems as? Set<ProjectLogGlassItem>)?
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { glassItemEntity in
                guard let naturalKey = glassItemEntity.itemNaturalKey else { return nil }
                return ProjectGlassItem(
                    id: glassItemEntity.id ?? UUID(),
                    naturalKey: naturalKey,
                    quantity: Decimal(glassItemEntity.quantity),
                    unit: "rods", // Default unit
                    notes: glassItemEntity.notes
                )
            } ?? []

        return ProjectLogModel(
            id: id,
            title: title,
            dateCreated: dateCreated,
            dateModified: dateModified,
            projectDate: entity.project_date,
            basedOnPlanId: entity.based_on_plan_id,
            tags: tags,
            coe: entity.coe ?? "any",
            notes: entity.notes,
            techniquesUsed: techniquesUsed,
            hoursSpent: entity.hours_spent as Decimal?,
            images: [], // TODO: Fetch related ProjectImage entities
            heroImageId: entity.hero_image_id,
            glassItems: glassItems,
            pricePoint: entity.price_point as Decimal?,
            saleDate: entity.sale_date,
            buyerInfo: entity.buyer_info,
            status: status,
            inventoryDeductionRecorded: entity.inventory_deduction_recorded
        )
    }
}
