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

            guard let plan = try self.context.fetch(fetchRequest).first,
                  let planModel = self.mapEntityToModel(plan) else {
                throw ProjectRepositoryError.planNotFound
            }

            var updatedUrls = planModel.referenceUrls
            updatedUrls.append(url)
            plan.reference_urls_data = (try? JSONEncoder().encode(updatedUrls)) as NSObject?
            plan.date_modified = Date()

            try self.context.save()
        }
    }

    func updateReferenceUrl(_ url: ProjectReferenceUrl, in planId: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", planId as CVarArg)

            guard let plan = try self.context.fetch(fetchRequest).first,
                  let planModel = self.mapEntityToModel(plan) else {
                throw ProjectRepositoryError.planNotFound
            }

            var updatedUrls = planModel.referenceUrls
            if let index = updatedUrls.firstIndex(where: { $0.id == url.id }) {
                updatedUrls[index] = url
                plan.reference_urls_data = (try? JSONEncoder().encode(updatedUrls)) as NSObject?
                plan.date_modified = Date()

                try self.context.save()
            }
        }
    }

    func deleteReferenceUrl(id: UUID, from planId: UUID) async throws {
        try await context.perform {
            let fetchRequest = ProjectPlan.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", planId as CVarArg)

            guard let plan = try self.context.fetch(fetchRequest).first,
                  let planModel = self.mapEntityToModel(plan) else {
                throw ProjectRepositoryError.planNotFound
            }

            var updatedUrls = planModel.referenceUrls
            updatedUrls.removeAll { $0.id == id }
            plan.reference_urls_data = (try? JSONEncoder().encode(updatedUrls)) as NSObject?
            plan.date_modified = Date()

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
        entity.tags = (try? JSONEncoder().encode(model.tags)) as NSObject?
        entity.estimated_time = model.estimatedTime ?? 0
        entity.difficulty_level = model.difficultyLevel?.rawValue
        entity.times_used = Int32(model.timesUsed)
        entity.last_used_date = model.lastUsedDate
        entity.date_created = model.dateCreated
        entity.date_modified = model.dateModified
        entity.hero_image_id = model.heroImageId

        // Encode glass items
        entity.glass_items_data = (try? JSONEncoder().encode(model.glassItems)) as NSObject?

        // Encode reference URLs
        entity.reference_urls_data = (try? JSONEncoder().encode(model.referenceUrls)) as NSObject?

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

        // Decode tags
        let tags: [String]
        if let tagsData = entity.tags as? Data,
           let decodedTags = try? JSONDecoder().decode([String].self, from: tagsData) {
            tags = decodedTags
        } else {
            tags = []
        }

        // Decode glass items
        let glassItems: [ProjectGlassItem]
        if let glassItemsData = entity.glass_items_data as? Data,
           let decodedItems = try? JSONDecoder().decode([ProjectGlassItem].self, from: glassItemsData) {
            glassItems = decodedItems
        } else {
            glassItems = []
        }

        // Decode reference URLs
        let referenceUrls: [ProjectReferenceUrl]
        if let urlsData = entity.reference_urls_data as? Data,
           let decodedUrls = try? JSONDecoder().decode([ProjectReferenceUrl].self, from: urlsData) {
            referenceUrls = decodedUrls
        } else {
            referenceUrls = []
        }

        // Decode steps (would need to fetch from relationship)
        let steps: [ProjectStepModel] = [] // TODO: Implement step fetching

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
