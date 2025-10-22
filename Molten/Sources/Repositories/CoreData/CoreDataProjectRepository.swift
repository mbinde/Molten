//
//  CoreDataProjectRepository.swift
//  Flameworker
//
//  Core Data implementation of ProjectRepository
//

import Foundation
@preconcurrency import CoreData

/// Core Data implementation of ProjectRepository
class CoreDataProjectRepository: ProjectRepository {
    private let persistenceController: PersistenceController

    nonisolated init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    // MARK: - CRUD Operations

    func createProject(_ project: ProjectModel) async throws -> ProjectModel {
        try await context.perform {
            let entity = Project(context: self.context)
            self.mapModelToEntity(plan, entity: entity)

            try self.context.save()
            return project
        }
    }

    func getProject(id: UUID) async throws -> ProjectModel? {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return self.mapEntityToModel(entity)
        }
    }

    func getAllProjects(includeArchived: Bool) async throws -> [ProjectModel] {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            if !includeArchived {
                fetchRequest.predicate = NSPredicate(format: "is_archived == NO")
            }
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func getActiveProjects() async throws -> [ProjectModel] {
        return try await getAllProjects(includeArchived: false)
    }

    func getArchivedProjects() async throws -> [ProjectModel] {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "is_archived == YES")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func getProjects(type: ProjectType?, includeArchived: Bool) async throws -> [ProjectModel] {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()

            var predicates: [NSPredicate] = []

            if let type = type {
                predicates.append(NSPredicate(format: "plan_type == %@", type.rawValue))
            }

            if !includeArchived {
                predicates.append(NSPredicate(format: "is_archived == NO"))
            }

            if !predicates.isEmpty {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }

            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func updateProject(_ project: ProjectModel) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", project.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.projectNotFound
            }

            self.mapModelToEntity(plan, entity: entity)
            entity.setValue(Date(), forKey: "date_modified")

            try self.context.save()
        }
    }

    func deleteProject(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.projectNotFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    func archiveProject(id: UUID, isArchived: Bool) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.projectNotFound
            }

            entity.setValue(isArchived, forKey: "is_archived")
            entity.setValue(Date(), forKey: "date_modified")

            try self.context.save()
        }
    }

    func unarchiveProject(id: UUID) async throws {
        try await archiveProject(id: id, isArchived: false)
    }

    // MARK: - Steps Management

    func addStep(_ step: ProjectStepModel) async throws -> ProjectStepModel {
        try await context.perform {
            // First fetch the plan to establish relationship
            let planFetch = ProjectPlan.fetchRequest()
            planFetch.predicate = NSPredicate(format: "id == %@", step.projectId as CVarArg)
            guard let project = try self.context.fetch(planFetch).first else {
                throw ProjectRepositoryError.projectNotFound
            }

            let entity = ProjectStep(context: self.context)
            entity.setValue(step.id, forKey: "id")
            entity.project = project
            entity.order_index = Int32(step.order)
            entity.setValue(step.title, forKey: "title")
            entity.step_description = step.description
            entity.estimated_minutes = Int32(step.estimatedMinutes ?? 0)

            // Add glass items if present
            if let glassItems = step.glassItemsNeeded {
                for (index, glassItem) in glassItems.enumerated() {
                    let glassEntity = ProjectStepGlassItem(context: self.context)
                    glassEntity.setValue(glassItem.id, forKey: "id")
                    glassEntity.setValue(glassItem.naturalKey, forKey: "itemNaturalKey")
                    glassEntity.setValue(glassItem.freeformDescription, forKey: "freeformDescription")
                    glassEntity.setValue(Double(truncating: glassItem.quantity as NSNumber), forKey: "quantity")
                    glassEntity.setValue(glassItem.unit, forKey: "unit")
                    glassEntity.setValue(glassItem.notes, forKey: "notes")
                    glassEntity.setValue(Int32(index), forKey: "orderIndex")
                    glassEntity.step = entity
                }
            }

            try self.context.save()
            return step
        }
    }

    func updateStep(_ step: ProjectStepModel) async throws {
        try await context.perform {
            let fetchRequest = ProjectStep.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", step.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.stepNotFound
            }

            entity.order_index = Int32(step.order)
            entity.setValue(step.title, forKey: "title")
            entity.step_description = step.description
            entity.estimated_minutes = Int32(step.estimatedMinutes ?? 0)

            // Clear existing glass items
            if let existingGlassItems = entity.value(forKey: "glassItems") as? Set<ProjectStepGlassItem> {
                for item in existingGlassItems {
                    self.context.delete(item)
                }
            }

            // Add new glass items
            if let glassItems = step.glassItemsNeeded {
                for (index, glassItem) in glassItems.enumerated() {
                    let glassEntity = ProjectStepGlassItem(context: self.context)
                    glassEntity.setValue(glassItem.id, forKey: "id")
                    glassEntity.setValue(glassItem.naturalKey, forKey: "itemNaturalKey")
                    glassEntity.setValue(glassItem.freeformDescription, forKey: "freeformDescription")
                    glassEntity.setValue(Double(truncating: glassItem.quantity as NSNumber), forKey: "quantity")
                    glassEntity.setValue(glassItem.unit, forKey: "unit")
                    glassEntity.setValue(glassItem.notes, forKey: "notes")
                    glassEntity.setValue(Int32(index), forKey: "orderIndex")
                    glassEntity.step = entity
                }
            }

            try self.context.save()
        }
    }

    func deleteStep(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectStep.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.stepNotFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    func reorderSteps(projectId: UUID, stepIds: [UUID]) async throws {
        try await context.perform {
            for (index, stepId) in stepIds.enumerated() {
                let fetchRequest = ProjectStep.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@ AND plan_id == %@", stepId as CVarArg, projectId as CVarArg)

                if let entity = try self.context.fetch(fetchRequest).first {
                    entity.order_index = Int32(index)
                }
            }

            try self.context.save()
        }
    }

    // MARK: - Reference URLs Management

    func addReferenceUrl(_ url: ProjectReferenceUrl, to projectId: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)

            guard let project = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.projectNotFound
            }

            // Get current count for order index
            let currentCount = (project.referenceUrls as? Set<ProjectPlanReferenceUrl>)?.count ?? 0

            // Create new reference URL entity
            let urlEntity = ProjectPlanReferenceUrl(context: self.context)
            urlEntity.setValue(url.id, forKey: "id")
            urlEntity.setValue(url.url, forKey: "url")
            urlEntity.setValue(url.title, forKey: "title")
            urlEntity.setValue(url.description, forKey: "urlDescription")
            urlEntity.setValue(url.dateAdded, forKey: "dateAdded")
            urlEntity.setValue(Int32(currentCount), forKey: "orderIndex")
            urlEntity.project = plan

            plan.date_modified = Date()
            try self.context.save()
        }
    }

    func updateReferenceUrl(_ url: ProjectReferenceUrl, in projectId: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlanReferenceUrl.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", url.id as CVarArg)

            guard let urlEntity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.urlNotFound
            }

            urlEntity.setValue(url.url, forKey: "url")
            urlEntity.setValue(url.title, forKey: "title")
            urlEntity.setValue(url.description, forKey: "urlDescription")

            if let project = urlEntity.project {
                plan.date_modified = Date()
            }

            try self.context.save()
        }
    }

    func deleteReferenceUrl(id: UUID, from projectId: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlanReferenceUrl.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let urlEntity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.urlNotFound
            }

            if let project = urlEntity.project {
                plan.date_modified = Date()
            }

            self.context.delete(urlEntity)
            try self.context.save()
        }
    }

    // MARK: - Mapping Functions

    private nonisolated func mapModelToEntity(_ model: ProjectModel, entity: ProjectPlan) {
        entity.setValue(model.id, forKey: "id")
        entity.setValue(model.title, forKey: "title")
        entity.setValue(model.type.rawValue, forKey: "project_type")
        entity.setValue(model.summary, forKey: "summary")
        entity.setValue(model.isArchived, forKey: "is_archived")
        entity.setValue(model.coe, forKey: "coe")
        entity.setValue(model.estimatedTime ?? 0, forKey: "estimated_time")
        entity.setValue(model.difficultyLevel?.rawValue, forKey: "difficulty_level")
        entity.setValue(Int32(model.timesUsed), forKey: "times_used")
        entity.setValue(model.lastUsedDate, forKey: "last_used_date")
        entity.setValue(model.dateCreated, forKey: "date_created")
        entity.setValue(model.dateModified, forKey: "date_modified")
        entity.setValue(model.heroImageId, forKey: "hero_image_id")

        // Clear existing relationships
        if let existingTags = entity.value(forKey: "tags") as? Set<ProjectTag> {
            for tag in existingTags {
                entity.managedObjectContext!.delete(tag)
            }
        }
        if let existingGlassItems = entity.value(forKey: "glassItems") as? Set<ProjectPlanGlassItem> {
            for item in existingGlassItems {
                entity.managedObjectContext!.delete(item)
            }
        }
        if let existingUrls = entity.value(forKey: "referenceUrls") as? Set<ProjectPlanReferenceUrl> {
            for url in existingUrls {
                entity.managedObjectContext!.delete(url)
            }
        }
        if let existingSteps = entity.value(forKey: "steps") as? Set<ProjectStep> {
            for step in existingSteps {
                entity.managedObjectContext!.delete(step)
            }
        }

        // Create new tag entities
        for tagString in model.tags {
            let tagEntity = ProjectTag(context: entity.managedObjectContext!)
            tagEntity.setValue(UUID(), forKey: "id")
            tagEntity.setValue(tagString, forKey: "tag")
            tagEntity.setValue(Date(), forKey: "dateAdded")
            tagEntity.setValue(entity, forKey: "plan")
        }

        // Create new glass item entities
        for (index, glassItem) in model.glassItems.enumerated() {
            let glassItemEntity = ProjectPlanGlassItem(context: entity.managedObjectContext!)
            glassItemEntity.setValue(UUID(), forKey: "id")
            glassItemEntity.setValue(glassItem.naturalKey, forKey: "itemNaturalKey")
            glassItemEntity.setValue(glassItem.freeformDescription, forKey: "freeformDescription")
            glassItemEntity.setValue(Double(truncating: glassItem.quantity as NSNumber), forKey: "quantity")
            glassItemEntity.setValue(glassItem.unit, forKey: "unit")
            glassItemEntity.setValue(glassItem.notes, forKey: "notes")
            glassItemEntity.setValue(Int32(index), forKey: "orderIndex")
            glassItemEntity.setValue(entity, forKey: "plan")
        }

        // Create new reference URL entities
        for (index, url) in model.referenceUrls.enumerated() {
            let urlEntity = ProjectPlanReferenceUrl(context: entity.managedObjectContext!)
            urlEntity.setValue(url.id, forKey: "id")
            urlEntity.setValue(url.url, forKey: "url")
            urlEntity.setValue(url.title, forKey: "title")
            urlEntity.setValue(url.description, forKey: "urlDescription")
            urlEntity.setValue(url.dateAdded, forKey: "dateAdded")
            urlEntity.setValue(Int32(index), forKey: "orderIndex")
            urlEntity.setValue(entity, forKey: "plan")
        }

        // Create new step entities
        for step in model.steps {
            let stepEntity = ProjectStep(context: entity.managedObjectContext!)
            stepEntity.setValue(step.id, forKey: "id")
            stepEntity.setValue(entity, forKey: "plan")
            stepEntity.setValue(Int32(step.order), forKey: "order_index")
            stepEntity.setValue(step.title, forKey: "title")
            stepEntity.setValue(step.description, forKey: "step_description")
            stepEntity.setValue(Int32(step.estimatedMinutes ?? 0), forKey: "estimated_minutes")

            // Add glass items for this step
            if let glassItems = step.glassItemsNeeded {
                for (index, glassItem) in glassItems.enumerated() {
                    let glassEntity = ProjectStepGlassItem(context: entity.managedObjectContext!)
                    glassEntity.setValue(glassItem.id, forKey: "id")
                    glassEntity.setValue(glassItem.naturalKey, forKey: "itemNaturalKey")
                    glassEntity.setValue(glassItem.freeformDescription, forKey: "freeformDescription")
                    glassEntity.setValue(Double(truncating: glassItem.quantity as NSNumber), forKey: "quantity")
                    glassEntity.setValue(glassItem.unit, forKey: "unit")
                    glassEntity.setValue(glassItem.notes, forKey: "notes")
                    glassEntity.setValue(Int32(index), forKey: "orderIndex")
                    glassEntity.setValue(stepEntity, forKey: "step")
                }
            }
        }

        // Encode price range
        if let priceRange = model.proposedPriceRange {
            if let min = priceRange.min {
                entity.setValue(NSDecimalNumber(decimal: min), forKey: "proposed_price_min")
            }
            if let max = priceRange.max {
                entity.setValue(NSDecimalNumber(decimal: max), forKey: "proposed_price_max")
            }
            entity.setValue(priceRange.currency, forKey: "price_currency")
        }
    }

    private nonisolated func mapEntityToModel(_ entity: ProjectPlan) -> ProjectModel? {
        guard let id = entity.value(forKey: "id") as? UUID,
              let title = entity.value(forKey: "title") as? String,
              let typeString = entity.value(forKey: "project_type") as? String,
              let type = ProjectType(rawValue: typeString),
              let dateCreated = entity.value(forKey: "date_created") as? Date,
              let dateModified = entity.value(forKey: "date_modified") as? Date else {
            return nil
        }

        // Extract tags from relationship
        let tags: [String] = (entity.value(forKey: "tags") as? Set<ProjectTag>)?
            .compactMap { $0.value(forKey: "tag") as? String }
            .sorted() ?? []

        // Extract glass items from relationship
        let glassItems: [ProjectGlassItem] = (entity.value(forKey: "glassItems") as? Set<ProjectPlanGlassItem>)?
            .sorted { $0.value(forKey: "orderIndex") as? Int32 ?? 0 < $1.value(forKey: "orderIndex") as? Int32 ?? 0 }
            .compactMap { glassItemEntity in
                guard let itemId = glassItemEntity.value(forKey: "id") as? UUID else { return nil }

                // Check if it's a catalog item or free-form
                if let naturalKey = glassItemEntity.value(forKey: "itemNaturalKey") as? String {
                    // Catalog item
                    return ProjectGlassItem(
                        id: itemId,
                        naturalKey: naturalKey,
                        quantity: Decimal(glassItemEntity.value(forKey: "quantity") as? Double ?? 0),
                        unit: glassItemEntity.value(forKey: "unit") as? String ?? "rods",
                        notes: glassItemEntity.value(forKey: "notes") as? String
                    )
                } else if let freeformDescription = glassItemEntity.value(forKey: "freeformDescription") as? String, !freeformDescription.isEmpty {
                    // Free-form item
                    return ProjectGlassItem(
                        id: itemId,
                        freeformDescription: freeformDescription,
                        quantity: Decimal(glassItemEntity.value(forKey: "quantity") as? Double ?? 0),
                        unit: glassItemEntity.value(forKey: "unit") as? String ?? "rods",
                        notes: glassItemEntity.value(forKey: "notes") as? String
                    )
                }
                return nil
            } ?? []

        // Extract reference URLs from relationship
        let referenceUrls: [ProjectReferenceUrl] = (entity.value(forKey: "referenceUrls") as? Set<ProjectPlanReferenceUrl>)?
            .sorted { $0.value(forKey: "orderIndex") as? Int32 ?? 0 < $1.value(forKey: "orderIndex") as? Int32 ?? 0 }
            .compactMap { urlEntity in
                guard let id = urlEntity.value(forKey: "id") as? UUID,
                      let urlString = urlEntity.value(forKey: "url") as? String else { return nil }
                return ProjectReferenceUrl(
                    id: id,
                    url: urlString,
                    title: urlEntity.value(forKey: "title") as? String,
                    description: urlEntity.value(forKey: "urlDescription") as? String,
                    dateAdded: urlEntity.value(forKey: "dateAdded") as? Date ?? Date()
                )
            } ?? []

        // Decode steps from relationship
        let steps: [ProjectStepModel] = (entity.value(forKey: "steps") as? Set<ProjectStep>)?
            .sorted { $0.value(forKey: "order_index") as? Int32 ?? 0 < $1.value(forKey: "order_index") as? Int32 ?? 0 }
            .compactMap { stepEntity -> ProjectStepModel? in
                guard let id = stepEntity.value(forKey: "id") as? UUID,
                      let title = stepEntity.value(forKey: "title") as? String else { return nil }

                // Extract glass items for this step
                let glassItems: [ProjectGlassItem]? = {
                    guard let glassSet = stepEntity.value(forKey: "glassItems") as? Set<ProjectStepGlassItem>,
                          !glassSet.isEmpty else { return nil }

                    return glassSet
                        .sorted { $0.value(forKey: "orderIndex") as? Int32 ?? 0 < $1.value(forKey: "orderIndex") as? Int32 ?? 0 }
                        .compactMap { glassEntity -> ProjectGlassItem? in
                            guard let itemId = glassEntity.value(forKey: "id") as? UUID else { return nil }

                            // Check if it's a catalog item or free-form
                            if let naturalKey = glassEntity.value(forKey: "itemNaturalKey") as? String {
                                // Catalog item
                                return ProjectGlassItem(
                                    id: itemId,
                                    naturalKey: naturalKey,
                                    quantity: Decimal(glassEntity.value(forKey: "quantity") as? Double ?? 0),
                                    unit: glassEntity.value(forKey: "unit") as? String ?? "rods",
                                    notes: glassEntity.value(forKey: "notes") as? String
                                )
                            } else if let freeformDescription = glassEntity.value(forKey: "freeformDescription") as? String, !freeformDescription.isEmpty {
                                // Free-form item (no naturalKey, uses freeformDescription)
                                return ProjectGlassItem(
                                    id: itemId,
                                    freeformDescription: freeformDescription,
                                    quantity: Decimal(glassEntity.value(forKey: "quantity") as? Double ?? 0),
                                    unit: glassEntity.value(forKey: "unit") as? String ?? "rods",
                                    notes: glassEntity.value(forKey: "notes") as? String
                                )
                            }
                            return nil
                        }
                }()

                guard let projectId = entity.value(forKey: "id") as? UUID else { return nil }
                let orderIndex = stepEntity.value(forKey: "order_index") as? Int32 ?? 0
                let estimatedMinutesValue = stepEntity.value(forKey: "estimated_minutes") as? Int32 ?? 0

                return ProjectStepModel(
                    id: id,
                    projectId: projectId,
                    order: Int(orderIndex),
                    title: title,
                    description: stepEntity.value(forKey: "step_description") as? String,
                    estimatedMinutes: estimatedMinutesValue > 0 ? Int(estimatedMinutesValue) : nil,
                    glassItemsNeeded: glassItems
                )
            } ?? []

        // Decode difficulty level
        let difficultyLevel: DifficultyLevel?
        if let diffString = entity.value(forKey: "difficulty_level") as? String {
            difficultyLevel = DifficultyLevel(rawValue: diffString)
        } else {
            difficultyLevel = nil
        }

        // Decode price range
        let priceRange: PriceRange?
        let priceMin = entity.value(forKey: "proposed_price_min") as? NSDecimalNumber
        let priceMax = entity.value(forKey: "proposed_price_max") as? NSDecimalNumber
        if priceMin != nil || priceMax != nil {
            priceRange = PriceRange(
                min: priceMin?.decimalValue,
                max: priceMax?.decimalValue,
                currency: entity.value(forKey: "price_currency") as? String ?? "USD"
            )
        } else {
            priceRange = nil
        }

        let estimatedTimeValue = entity.value(forKey: "estimated_time") as? Int ?? 0
        let timesUsedValue = entity.value(forKey: "times_used") as? Int32 ?? 0

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
                    projectType: .plan,
                    fileExtension: fileExtension,
                    caption: imageEntity.value(forKey: "caption") as? String,
                    dateAdded: dateAdded,
                    order: Int(imageEntity.value(forKey: "order_index") as? Int32 ?? 0)
                )
            } ?? []

        return ProjectModel(
            id: id,
            title: title,
            type: type,
            dateCreated: dateCreated,
            dateModified: dateModified,
            isArchived: entity.value(forKey: "is_archived") as? Bool ?? false,
            tags: tags,
            coe: entity.value(forKey: "coe") as? String ?? "any",
            summary: entity.value(forKey: "summary") as? String,
            steps: steps,
            estimatedTime: estimatedTimeValue > 0 ? TimeInterval(estimatedTimeValue) : nil,
            difficultyLevel: difficultyLevel,
            proposedPriceRange: priceRange,
            images: images,
            heroImageId: entity.value(forKey: "hero_image_id") as? UUID,
            glassItems: glassItems,
            referenceUrls: referenceUrls,
            timesUsed: Int(timesUsedValue),
            lastUsedDate: entity.value(forKey: "last_used_date") as? Date
        )
    }
}
