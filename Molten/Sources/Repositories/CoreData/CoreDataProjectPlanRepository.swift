//
//  CoreDataProjectPlanRepository.swift
//  Flameworker
//
//  Core Data implementation of ProjectPlanRepository
//

import Foundation
import CoreData

/// Core Data implementation of ProjectPlanRepository
class CoreDataProjectPlanRepository: ProjectPlanRepository {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    // MARK: - CRUD Operations

    func createPlan(_ plan: ProjectPlanModel) async throws -> ProjectPlanModel {
        try await context.perform {
            let entity = ProjectPlan(context: self.context)
            self.mapModelToEntity(plan, entity: entity)

            try self.context.save()
            return plan
        }
    }

    func getPlan(id: UUID) async throws -> ProjectPlanModel? {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                return nil
            }

            return self.mapEntityToModel(entity)
        }
    }

    func getAllPlans(includeArchived: Bool) async throws -> [ProjectPlanModel] {
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

    func getActivePlans() async throws -> [ProjectPlanModel] {
        return try await getAllPlans(includeArchived: false)
    }

    func getArchivedPlans() async throws -> [ProjectPlanModel] {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "is_archived == YES")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date_created", ascending: false)]

            let entities = try self.context.fetch(fetchRequest)
            return entities.compactMap { self.mapEntityToModel($0) }
        }
    }

    func getPlans(type: ProjectPlanType?, includeArchived: Bool) async throws -> [ProjectPlanModel] {
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

    func updatePlan(_ plan: ProjectPlanModel) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", plan.id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.planNotFound
            }

            self.mapModelToEntity(plan, entity: entity)
            entity.date_modified = Date()

            try self.context.save()
        }
    }

    func deletePlan(id: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.planNotFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    func archivePlan(id: UUID, isArchived: Bool) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.planNotFound
            }

            entity.is_archived = isArchived
            entity.date_modified = Date()

            try self.context.save()
        }
    }

    func unarchivePlan(id: UUID) async throws {
        try await archivePlan(id: id, isArchived: false)
    }

    // MARK: - Steps Management

    func addStep(_ step: ProjectStepModel) async throws -> ProjectStepModel {
        try await context.perform {
            // First fetch the plan to establish relationship
            let planFetch = ProjectPlan.fetchRequest()
            planFetch.predicate = NSPredicate(format: "id == %@", step.planId as CVarArg)
            guard let plan = try self.context.fetch(planFetch).first else {
                throw ProjectRepositoryError.planNotFound
            }

            let entity = ProjectStep(context: self.context)
            entity.id = step.id
            entity.plan = plan
            entity.order_index = Int32(step.order)
            entity.title = step.title
            entity.step_description = step.description
            entity.estimated_minutes = Int32(step.estimatedMinutes ?? 0)

            // Add glass items if present
            if let glassItems = step.glassItemsNeeded {
                for (index, glassItem) in glassItems.enumerated() {
                    let glassEntity = ProjectStepGlassItem(context: self.context)
                    glassEntity.id = glassItem.id
                    glassEntity.itemNaturalKey = glassItem.naturalKey
                    glassEntity.freeformDescription = glassItem.freeformDescription
                    glassEntity.quantity = Double(truncating: glassItem.quantity as NSNumber)
                    glassEntity.unit = glassItem.unit
                    glassEntity.notes = glassItem.notes
                    glassEntity.orderIndex = Int32(index)
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
            entity.title = step.title
            entity.step_description = step.description
            entity.estimated_minutes = Int32(step.estimatedMinutes ?? 0)

            // Clear existing glass items
            if let existingGlassItems = entity.glassItems as? Set<ProjectStepGlassItem> {
                for item in existingGlassItems {
                    self.context.delete(item)
                }
            }

            // Add new glass items
            if let glassItems = step.glassItemsNeeded {
                for (index, glassItem) in glassItems.enumerated() {
                    let glassEntity = ProjectStepGlassItem(context: self.context)
                    glassEntity.id = glassItem.id
                    glassEntity.itemNaturalKey = glassItem.naturalKey
                    glassEntity.freeformDescription = glassItem.freeformDescription
                    glassEntity.quantity = Double(truncating: glassItem.quantity as NSNumber)
                    glassEntity.unit = glassItem.unit
                    glassEntity.notes = glassItem.notes
                    glassEntity.orderIndex = Int32(index)
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

    func reorderSteps(planId: UUID, stepIds: [UUID]) async throws {
        try await context.perform {
            for (index, stepId) in stepIds.enumerated() {
                let fetchRequest = ProjectStep.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@ AND plan_id == %@", stepId as CVarArg, planId as CVarArg)

                if let entity = try self.context.fetch(fetchRequest).first {
                    entity.order_index = Int32(index)
                }
            }

            try self.context.save()
        }
    }

    // MARK: - Reference URLs Management

    func addReferenceUrl(_ url: ProjectReferenceUrl, to planId: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", planId as CVarArg)

            guard let plan = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.planNotFound
            }

            // Get current count for order index
            let currentCount = (plan.referenceUrls as? Set<ProjectPlanReferenceUrl>)?.count ?? 0

            // Create new reference URL entity
            let urlEntity = ProjectPlanReferenceUrl(context: self.context)
            urlEntity.id = url.id
            urlEntity.url = url.url
            urlEntity.title = url.title
            urlEntity.urlDescription = url.description
            urlEntity.dateAdded = url.dateAdded
            urlEntity.orderIndex = Int32(currentCount)
            urlEntity.plan = plan

            plan.date_modified = Date()
            try self.context.save()
        }
    }

    func updateReferenceUrl(_ url: ProjectReferenceUrl, in planId: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlanReferenceUrl.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", url.id as CVarArg)

            guard let urlEntity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.urlNotFound
            }

            urlEntity.url = url.url
            urlEntity.title = url.title
            urlEntity.urlDescription = url.description

            if let plan = urlEntity.plan {
                plan.date_modified = Date()
            }

            try self.context.save()
        }
    }

    func deleteReferenceUrl(id: UUID, from planId: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlanReferenceUrl.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let urlEntity = try self.context.fetch(fetchRequest).first else {
                throw ProjectRepositoryError.urlNotFound
            }

            if let plan = urlEntity.plan {
                plan.date_modified = Date()
            }

            self.context.delete(urlEntity)
            try self.context.save()
        }
    }

    // MARK: - Mapping Functions

    private func mapModelToEntity(_ model: ProjectPlanModel, entity: ProjectPlan) {
        entity.id = model.id
        entity.title = model.title
        entity.plan_type = model.planType.rawValue
        entity.summary = model.summary
        entity.is_archived = model.isArchived
        entity.coe = model.coe
        entity.estimated_time = model.estimatedTime ?? 0
        entity.difficulty_level = model.difficultyLevel?.rawValue
        entity.times_used = Int32(model.timesUsed)
        entity.last_used_date = model.lastUsedDate
        entity.date_created = model.dateCreated
        entity.date_modified = model.dateModified
        entity.hero_image_id = model.heroImageId

        // Clear existing relationships
        if let existingTags = entity.tags as? Set<ProjectTag> {
            for tag in existingTags {
                self.context.delete(tag)
            }
        }
        if let existingGlassItems = entity.glassItems as? Set<ProjectPlanGlassItem> {
            for item in existingGlassItems {
                self.context.delete(item)
            }
        }
        if let existingUrls = entity.referenceUrls as? Set<ProjectPlanReferenceUrl> {
            for url in existingUrls {
                self.context.delete(url)
            }
        }

        // Create new tag entities
        for tagString in model.tags {
            let tagEntity = ProjectTag(context: self.context)
            tagEntity.id = UUID()
            tagEntity.tag = tagString
            tagEntity.dateAdded = Date()
            tagEntity.plan = entity
        }

        // Create new glass item entities
        for (index, glassItem) in model.glassItems.enumerated() {
            let glassItemEntity = ProjectPlanGlassItem(context: self.context)
            glassItemEntity.id = UUID()
            glassItemEntity.itemNaturalKey = glassItem.naturalKey
            glassItemEntity.freeformDescription = glassItem.freeformDescription
            glassItemEntity.quantity = Double(truncating: glassItem.quantity as NSNumber)
            glassItemEntity.unit = glassItem.unit
            glassItemEntity.notes = glassItem.notes
            glassItemEntity.orderIndex = Int32(index)
            glassItemEntity.plan = entity
        }

        // Create new reference URL entities
        for (index, url) in model.referenceUrls.enumerated() {
            let urlEntity = ProjectPlanReferenceUrl(context: self.context)
            urlEntity.id = url.id
            urlEntity.url = url.url
            urlEntity.title = url.title
            urlEntity.urlDescription = url.description
            urlEntity.dateAdded = url.dateAdded
            urlEntity.orderIndex = Int32(index)
            urlEntity.plan = entity
        }

        // Encode price range
        if let priceRange = model.proposedPriceRange {
            if let min = priceRange.min {
                entity.proposed_price_min = NSDecimalNumber(decimal: min)
            }
            if let max = priceRange.max {
                entity.proposed_price_max = NSDecimalNumber(decimal: max)
            }
            entity.price_currency = priceRange.currency
        }
    }

    private func mapEntityToModel(_ entity: ProjectPlan) -> ProjectPlanModel? {
        guard let id = entity.id,
              let title = entity.title,
              let typeString = entity.plan_type,
              let planType = ProjectPlanType(rawValue: typeString),
              let dateCreated = entity.date_created,
              let dateModified = entity.date_modified else {
            return nil
        }

        // Extract tags from relationship
        let tags: [String] = (entity.tags as? Set<ProjectTag>)?
            .compactMap { $0.tag }
            .sorted() ?? []

        // Extract glass items from relationship
        let glassItems: [ProjectGlassItem] = (entity.glassItems as? Set<ProjectPlanGlassItem>)?
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { glassItemEntity in
                guard let itemId = glassItemEntity.id else { return nil }

                // Check if it's a catalog item or free-form
                if let naturalKey = glassItemEntity.itemNaturalKey {
                    // Catalog item
                    return ProjectGlassItem(
                        id: itemId,
                        naturalKey: naturalKey,
                        quantity: Decimal(glassItemEntity.quantity),
                        unit: glassItemEntity.unit ?? "rods",
                        notes: glassItemEntity.notes
                    )
                } else if let freeformDescription = glassItemEntity.freeformDescription, !freeformDescription.isEmpty {
                    // Free-form item
                    return ProjectGlassItem(
                        id: itemId,
                        freeformDescription: freeformDescription,
                        quantity: Decimal(glassItemEntity.quantity),
                        unit: glassItemEntity.unit ?? "rods",
                        notes: glassItemEntity.notes
                    )
                }
                return nil
            } ?? []

        // Extract reference URLs from relationship
        let referenceUrls: [ProjectReferenceUrl] = (entity.referenceUrls as? Set<ProjectPlanReferenceUrl>)?
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { urlEntity in
                guard let id = urlEntity.id,
                      let urlString = urlEntity.url else { return nil }
                return ProjectReferenceUrl(
                    id: id,
                    url: urlString,
                    title: urlEntity.title,
                    description: urlEntity.urlDescription,
                    dateAdded: urlEntity.dateAdded ?? Date()
                )
            } ?? []

        // Decode steps from relationship
        let steps: [ProjectStepModel] = (entity.steps as? Set<ProjectStep>)?
            .sorted { $0.order_index < $1.order_index }
            .compactMap { stepEntity -> ProjectStepModel? in
                guard let id = stepEntity.id,
                      let title = stepEntity.title else { return nil }

                // Extract glass items for this step
                let glassItems: [ProjectGlassItem]? = {
                    guard let glassSet = stepEntity.glassItems as? Set<ProjectStepGlassItem>,
                          !glassSet.isEmpty else { return nil }

                    return glassSet
                        .sorted { $0.orderIndex < $1.orderIndex }
                        .compactMap { glassEntity -> ProjectGlassItem? in
                            guard let itemId = glassEntity.id else { return nil }

                            // Check if it's a catalog item or free-form
                            if let naturalKey = glassEntity.itemNaturalKey {
                                // Catalog item
                                return ProjectGlassItem(
                                    id: itemId,
                                    naturalKey: naturalKey,
                                    quantity: Decimal(glassEntity.quantity),
                                    unit: glassEntity.unit ?? "rods",
                                    notes: glassEntity.notes
                                )
                            } else if let freeformDescription = glassEntity.freeformDescription, !freeformDescription.isEmpty {
                                // Free-form item (no naturalKey, uses freeformDescription)
                                return ProjectGlassItem(
                                    id: itemId,
                                    freeformDescription: freeformDescription,
                                    quantity: Decimal(glassEntity.quantity),
                                    unit: glassEntity.unit ?? "rods",
                                    notes: glassEntity.notes
                                )
                            }
                            return nil
                        }
                }()

                return ProjectStepModel(
                    id: id,
                    planId: entity.id!,
                    order: Int(stepEntity.order_index),
                    title: title,
                    description: stepEntity.step_description,
                    estimatedMinutes: stepEntity.estimated_minutes > 0 ? Int(stepEntity.estimated_minutes) : nil,
                    glassItemsNeeded: glassItems
                )
            } ?? []

        // Decode difficulty level
        let difficultyLevel: DifficultyLevel?
        if let diffString = entity.difficulty_level {
            difficultyLevel = DifficultyLevel(rawValue: diffString)
        } else {
            difficultyLevel = nil
        }

        // Decode price range
        let priceRange: PriceRange?
        if entity.proposed_price_min != nil || entity.proposed_price_max != nil {
            priceRange = PriceRange(
                min: entity.proposed_price_min?.decimalValue,
                max: entity.proposed_price_max?.decimalValue,
                currency: entity.price_currency ?? "USD"
            )
        } else {
            priceRange = nil
        }

        return ProjectPlanModel(
            id: id,
            title: title,
            planType: planType,
            dateCreated: dateCreated,
            dateModified: dateModified,
            isArchived: entity.is_archived,
            tags: tags,
            coe: entity.coe ?? "any",
            summary: entity.summary,
            steps: steps,
            estimatedTime: entity.estimated_time > 0 ? entity.estimated_time : nil,
            difficultyLevel: difficultyLevel,
            proposedPriceRange: priceRange,
            images: [], // TODO: Implement image fetching
            heroImageId: entity.hero_image_id,
            glassItems: glassItems,
            referenceUrls: referenceUrls,
            timesUsed: Int(entity.times_used),
            lastUsedDate: entity.last_used_date
        )
    }
}
