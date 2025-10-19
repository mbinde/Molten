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
        entity.notes = model.notes
        entity.hero_image_id = model.heroImageId
        entity.status = model.status.rawValue
        entity.price_point = model.pricePoint as NSDecimalNumber?
        entity.sale_date = model.saleDate
        entity.buyer_info = model.buyerInfo
        entity.hours_spent = model.hoursSpent as NSDecimalNumber?
        entity.inventory_deduction_recorded = model.inventoryDeductionRecorded

        // Encode arrays as JSON
        entity.tags = (try? JSONEncoder().encode(model.tags)) as NSObject?
        entity.techniques_used = (try? JSONEncoder().encode(model.techniquesUsed)) as NSObject?
        entity.glass_items_data = (try? JSONEncoder().encode(model.glassItems)) as NSObject?
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

        // Decode arrays from JSON
        var tags: [String] = []
        if let tagsData = entity.tags as? Data {
            tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        }

        var techniquesUsed: [String]?
        if let techniquesData = entity.techniques_used as? Data {
            techniquesUsed = try? JSONDecoder().decode([String].self, from: techniquesData)
        }

        var glassItems: [ProjectGlassItem] = []
        if let glassItemsData = entity.glass_items_data as? Data {
            glassItems = (try? JSONDecoder().decode([ProjectGlassItem].self, from: glassItemsData)) ?? []
        }

        return ProjectLogModel(
            id: id,
            title: title,
            dateCreated: dateCreated,
            dateModified: dateModified,
            projectDate: entity.project_date,
            basedOnPlanId: entity.based_on_plan_id,
            tags: tags,
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
