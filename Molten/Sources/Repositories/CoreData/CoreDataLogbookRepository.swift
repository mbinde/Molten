//
//  CoreDataLogbookRepository.swift
//  Molten
//
//  Core Data implementation of LogbookRepository
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of LogbookRepository
class CoreDataLogbookRepository: @unchecked Sendable, LogbookRepository {
    private let context: NSManagedObjectContext
    private let imageRepository: UserImageRepository?

    nonisolated init(context: NSManagedObjectContext, imageRepository: UserImageRepository? = nil) {
        self.context = context
        self.imageRepository = imageRepository
    }

    // MARK: - CRUD Operations

    func createLog(_ log: LogbookModel) async throws -> LogbookModel {
        return try await context.perform {
            let entity = Logbook(context: self.context)
            self.mapModelToEntity(log, entity: entity)

            try CoreDataErrorHandler.save(context: self.context)
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
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    func deleteLog(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = Logbook.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.logNotFound
            }

            // Delete UserTags manually (polymorphic association, not a Core Data relationship)
            let tagFetchRequest = NSFetchRequest<UserTags>(entityName: "UserTags")
            tagFetchRequest.predicate = NSPredicate(
                format: "owner_id == %@ AND owner_type == %@",
                id.uuidString,
                TagOwnerType.logbook.rawValue
            )
            let tagsToDelete = try self.context.fetch(tagFetchRequest)
            for tag in tagsToDelete {
                self.context.delete(tag)
            }

            // Delete the logbook entity (related entities with cascade delete will be removed automatically)
            self.context.delete(entity)
            try CoreDataErrorHandler.save(context: self.context)
        }
    }

    // MARK: - Business Queries

    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        return try await context.perform {
            let fetchRequest = Logbook.fetchRequest()
            // Check if either date_started or project_date falls within the range, or if date_created does (when both are nil)
            fetchRequest.predicate = NSPredicate(
                format: "(date_started >= %@ AND date_started <= %@) OR (project_date >= %@ AND project_date <= %@) OR (date_started == nil AND project_date == nil AND date_created >= %@ AND date_created <= %@)",
                start as CVarArg, end as CVarArg,
                start as CVarArg, end as CVarArg,
                start as CVarArg, end as CVarArg
            )
            // Sort by completion date (project_date), then start date, then created date
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "project_date", ascending: false),
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

    private func mapModelToEntity(_ model: LogbookModel, entity: Logbook) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.title, forKey: "title")
        entity.setValue(model.dateCreated, forKey: "date_created")
        entity.setValue(model.dateModified, forKey: "date_modified")
        entity.setValue(model.startDate, forKey: "date_started")
        // NOTE: Core Data entity has 'project_date', not 'date_completed'
        entity.setValue(model.completionDate, forKey: "project_date")

        // NOTE: Core Data entity has 'based_on_plan_id' (singular UUID), not 'based_on_plan_ids' (Data)
        // Store only the first project ID. Multiple IDs not supported by current schema.
        // TODO: Consider adding a relationship for multiple plan IDs or migrating to Data field
        if let firstPlanId = model.basedOnProjectIds.first {
            entity.setValue(firstPlanId, forKey: "based_on_plan_id")
        } else {
            entity.setValue(nil, forKey: "based_on_plan_id")
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

        // Set kiln schedule relationship (optional, may not be available in test contexts)
        // NOTE: Logbook entity does not have a kilnSchedule relationship in Core Data model
        // kilnScheduleId is stored as an attribute (UUID) for cross-store reference lookup
        // The relationship was planned but never added to the model - keeping attribute-based reference

        // Clear existing relationships
        // NOTE: Tags use UserTags with polymorphic association (owner_id + owner_type), not relationships
        // Delete existing tags for this logbook
        let tagFetchRequest = NSFetchRequest<UserTags>(entityName: "UserTags")
        tagFetchRequest.predicate = NSPredicate(
            format: "owner_id == %@ AND owner_type == %@",
            model.id.uuidString,
            TagOwnerType.logbook.rawValue
        )
        if let existingTags = try? self.context.fetch(tagFetchRequest) {
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
        // Clear images relationship (managed through UserImageRepository)
        // Use try? to safely handle if relationship doesn't exist or is inaccessible
        if let existingImages = try? entity.value(forKey: "images") as? Set<NSManagedObject> {
            for image in existingImages {
                self.context.delete(image)
            }
        }

        // Create new UserTags entries for this logbook
        for tagString in model.tags {
            let tagEntity = UserTags(context: self.context)
            tagEntity.setValue(model.id.uuidString, forKey: "owner_id")
            tagEntity.setValue(TagOwnerType.logbook.rawValue, forKey: "owner_type")
            tagEntity.setValue(tagString, forKey: "tag")
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
            glassItemEntity.setValue(glassItem.stableId, forKey: "item_stable_id")
            glassItemEntity.setValue(Double(truncating: glassItem.quantity as NSNumber), forKey: "quantity")
            glassItemEntity.setValue(glassItem.notes, forKey: "notes")
            glassItemEntity.setValue(Int32(index), forKey: "orderIndex")
            glassItemEntity.setValue(entity, forKey: "log")
        }
    }

    private func mapEntityToModel(_ entity: Logbook) throws -> LogbookModel {
        guard let id = entity.value(forKey: "id") as? UUID,
              let title = entity.value(forKey: "title") as? String,
              let dateCreated = entity.value(forKey: "date_created") as? Date,
              let dateModified = entity.value(forKey: "date_modified") as? Date,
              let statusString = entity.value(forKey: "status") as? String,
              let status = ProjectStatus(rawValue: statusString) else {
            throw ProjectRepositoryError.invalidData("Missing required fields in Logbook entity")
        }

        // Extract tags from UserTags (polymorphic association)
        let tags: [String] = {
            let tagFetchRequest = NSFetchRequest<UserTags>(entityName: "UserTags")
            tagFetchRequest.predicate = NSPredicate(
                format: "owner_id == %@ AND owner_type == %@",
                id.uuidString,
                TagOwnerType.logbook.rawValue
            )
            guard let userTags = try? self.context.fetch(tagFetchRequest) else {
                return []
            }
            return userTags.compactMap { $0.value(forKey: "tag") as? String }.sorted()
        }()

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
                guard let naturalKey = glassItemEntity.value(forKey: "item_stable_id") as? String else { return nil }
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

        // NOTE: Core Data entity has 'based_on_plan_id' (singular UUID), not 'based_on_plan_ids' (Data)
        // Read single project ID and return as array for compatibility with model
        let basedOnProjectIds: [UUID] = {
            guard let singleId = entity.value(forKey: "based_on_plan_id") as? UUID else {
                return []
            }
            return [singleId]
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
            completionDate: entity.value(forKey: "project_date") as? Date,
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
            kilnScheduleId: nil,  // Logbook entity has no kilnSchedule relationship
            pricePoint: entity.value(forKey: "price_point") as? Decimal,
            saleDate: entity.value(forKey: "sale_date") as? Date,
            buyerInfo: entity.value(forKey: "buyer_info") as? String,
            status: status,
            inventoryDeductionRecorded: entity.value(forKey: "inventory_deduction_recorded") as? Bool ?? false
        )
    }

    // MARK: - Search

    func searchLogs(query: String) async throws -> [LogbookModel] {
        // Search in logbook text fields using Core Data predicates
        let textModels = try await context.perform {
            let textPredicates: [NSPredicate] = [
                NSPredicate(format: "title CONTAINS[cd] %@", query),
                NSPredicate(format: "notes CONTAINS[cd] %@", query),
            ]
            let textPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: textPredicates)

            // Fetch matching logbooks
            let fetchRequest = Logbook.fetchRequest()
            fetchRequest.predicate = textPredicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return try entities.compactMap { try self.mapEntityToModel($0) }
        }

        var matchingIds = Set(textModels.map { $0.id })

        // Add OCR text search if imageRepository is available
        if let imageRepository = self.imageRepository {
            let allLogs = try await self.getAllLogs()
            for log in allLogs {
                // Skip if already matched by text search
                if matchingIds.contains(log.id) { continue }

                // Search OCR text from log images
                let ocrText = try? await imageRepository.getOCRText(
                    ownerType: .projectLog,
                    ownerId: log.id.uuidString
                )

                if let ocrText = ocrText, !ocrText.isEmpty,
                   ocrText.lowercased().contains(query.lowercased()) {
                    matchingIds.insert(log.id)
                }
            }

            // Return all matching logs
            return allLogs.filter { matchingIds.contains($0.id) }
        }

        // No image repository, just return text matches
        return textModels
    }
}
