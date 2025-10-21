//
//  MockProjectPlanRepository.swift
//  Flameworker
//
//  Mock implementation of ProjectPlanRepository for testing
//

import Foundation

/// Mock implementation of ProjectPlanRepository for testing
class MockProjectPlanRepository: ProjectPlanRepository {
    private var plans: [UUID: ProjectPlanModel] = [:]
    private var steps: [UUID: ProjectStepModel] = [:]

    nonisolated init() {}

    // MARK: - CRUD Operations

    func createPlan(_ plan: ProjectPlanModel) async throws -> ProjectPlanModel {
        plans[plan.id] = plan
        return plan
    }

    func getPlan(id: UUID) async throws -> ProjectPlanModel? {
        return plans[id]
    }

    func getAllPlans(includeArchived: Bool) async throws -> [ProjectPlanModel] {
        if includeArchived {
            return Array(plans.values).sorted { $0.dateCreated > $1.dateCreated }
        } else {
            return plans.values.filter { !$0.isArchived }.sorted { $0.dateCreated > $1.dateCreated }
        }
    }

    func getActivePlans() async throws -> [ProjectPlanModel] {
        return plans.values.filter { !$0.isArchived }.sorted { $0.dateCreated > $1.dateCreated }
    }

    func getArchivedPlans() async throws -> [ProjectPlanModel] {
        return plans.values.filter { $0.isArchived }.sorted { $0.dateCreated > $1.dateCreated }
    }

    func getPlans(type: ProjectPlanType?, includeArchived: Bool) async throws -> [ProjectPlanModel] {
        var filtered = Array(plans.values)

        if let type = type {
            filtered = filtered.filter { $0.planType == type }
        }

        if !includeArchived {
            filtered = filtered.filter { !$0.isArchived }
        }

        return filtered.sorted { $0.dateCreated > $1.dateCreated }
    }

    func updatePlan(_ plan: ProjectPlanModel) async throws {
        guard plans[plan.id] != nil else {
            throw ProjectRepositoryError.planNotFound
        }
        plans[plan.id] = plan
    }

    func deletePlan(id: UUID) async throws {
        guard plans[id] != nil else {
            throw ProjectRepositoryError.planNotFound
        }
        plans.removeValue(forKey: id)
    }

    func archivePlan(id: UUID, isArchived: Bool) async throws {
        guard let plan = plans[id] else {
            throw ProjectRepositoryError.planNotFound
        }
        // Create a new instance with the updated isArchived value
        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: plan.title,
            planType: plan.planType,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: isArchived,
            tags: plan.tags,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )
        plans[id] = updatedPlan
    }

    func unarchivePlan(id: UUID) async throws {
        try await archivePlan(id: id, isArchived: false)
    }

    // MARK: - Steps Management

    func addStep(_ step: ProjectStepModel) async throws -> ProjectStepModel {
        steps[step.id] = step
        return step
    }

    func updateStep(_ step: ProjectStepModel) async throws {
        guard steps[step.id] != nil else {
            throw ProjectRepositoryError.stepNotFound
        }
        steps[step.id] = step
    }

    func deleteStep(id: UUID) async throws {
        guard steps[id] != nil else {
            throw ProjectRepositoryError.stepNotFound
        }
        steps.removeValue(forKey: id)
    }

    func reorderSteps(planId: UUID, stepIds: [UUID]) async throws {
        // In mock, we don't need to do anything special for reordering
        // The order is maintained by the stepIds array passed in
    }

    // MARK: - Reference URLs Management

    func addReferenceUrl(_ url: ProjectReferenceUrl, to planId: UUID) async throws {
        guard let plan = plans[planId] else {
            throw ProjectRepositoryError.planNotFound
        }
        var updatedUrls = plan.referenceUrls
        updatedUrls.append(url)

        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: plan.title,
            planType: plan.planType,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            tags: plan.tags,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: updatedUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )
        plans[planId] = updatedPlan
    }

    func updateReferenceUrl(_ url: ProjectReferenceUrl, in planId: UUID) async throws {
        guard let plan = plans[planId] else {
            throw ProjectRepositoryError.planNotFound
        }
        var updatedUrls = plan.referenceUrls
        if let index = updatedUrls.firstIndex(where: { $0.id == url.id }) {
            updatedUrls[index] = url

            let updatedPlan = ProjectPlanModel(
                id: plan.id,
                title: plan.title,
                planType: plan.planType,
                dateCreated: plan.dateCreated,
                dateModified: Date(),
                isArchived: plan.isArchived,
                tags: plan.tags,
                summary: plan.summary,
                steps: plan.steps,
                estimatedTime: plan.estimatedTime,
                difficultyLevel: plan.difficultyLevel,
                proposedPriceRange: plan.proposedPriceRange,
                images: plan.images,
                heroImageId: plan.heroImageId,
                glassItems: plan.glassItems,
                referenceUrls: updatedUrls,
                timesUsed: plan.timesUsed,
                lastUsedDate: plan.lastUsedDate
            )
            plans[planId] = updatedPlan
        }
    }

    func deleteReferenceUrl(id: UUID, from planId: UUID) async throws {
        guard let plan = plans[planId] else {
            throw ProjectRepositoryError.planNotFound
        }
        var updatedUrls = plan.referenceUrls
        updatedUrls.removeAll { $0.id == id }

        let updatedPlan = ProjectPlanModel(
            id: plan.id,
            title: plan.title,
            planType: plan.planType,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            tags: plan.tags,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: updatedUrls,
            timesUsed: plan.timesUsed,
            lastUsedDate: plan.lastUsedDate
        )
        plans[planId] = updatedPlan
    }

    // MARK: - Test Helpers

    func reset() {
        plans.removeAll()
        steps.removeAll()
    }

    func getPlanCount() -> Int {
        return plans.count
    }
}
