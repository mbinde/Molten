//
//  ProjectPlanRepository.swift
//  Flameworker
//
//  Protocol for ProjectPlan data persistence operations
//

import Foundation

nonisolated protocol ProjectPlanRepository {
    // MARK: - CRUD Operations

    func createPlan(_ plan: ProjectPlanModel) async throws -> ProjectPlanModel
    func getPlan(id: UUID) async throws -> ProjectPlanModel?
    func getAllPlans(includeArchived: Bool) async throws -> [ProjectPlanModel]
    func getActivePlans() async throws -> [ProjectPlanModel]  // Convenience: excludes archived
    func getArchivedPlans() async throws -> [ProjectPlanModel]  // Convenience: only archived
    func getPlans(type: ProjectPlanType?, includeArchived: Bool) async throws -> [ProjectPlanModel]
    func updatePlan(_ plan: ProjectPlanModel) async throws
    func deletePlan(id: UUID) async throws  // Permanent deletion
    func archivePlan(id: UUID, isArchived: Bool) async throws  // Toggle archive status
    func unarchivePlan(id: UUID) async throws  // Convenience: shorthand for archivePlan(id, false)

    // MARK: - Steps Management

    func addStep(_ step: ProjectStepModel) async throws -> ProjectStepModel
    func updateStep(_ step: ProjectStepModel) async throws
    func deleteStep(id: UUID) async throws
    func reorderSteps(planId: UUID, stepIds: [UUID]) async throws

    // MARK: - Reference URLs Management

    func addReferenceUrl(_ url: ProjectReferenceUrl, to planId: UUID) async throws
    func updateReferenceUrl(_ url: ProjectReferenceUrl, in planId: UUID) async throws
    func deleteReferenceUrl(id: UUID, from planId: UUID) async throws
}
