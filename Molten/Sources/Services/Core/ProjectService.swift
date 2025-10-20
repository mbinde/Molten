//
//  ProjectService.swift
//  Flameworker
//
//  Service layer for project management (plans and logs)
//  Orchestrates ProjectPlanRepository and ProjectLogRepository operations
//

import Foundation

/// Service for managing glass art projects (plans and logs)
/// Following the repository pattern: services orchestrate, models contain business logic
class ProjectService {

    // MARK: - Dependencies

    private let projectPlanRepository: ProjectPlanRepository
    private let projectLogRepository: ProjectLogRepository

    // MARK: - Exposed Dependencies

    /// Direct access to plan repository for advanced operations
    var planRepository: ProjectPlanRepository {
        return projectPlanRepository
    }

    /// Direct access to log repository for advanced operations
    var logRepository: ProjectLogRepository {
        return projectLogRepository
    }

    // MARK: - Initialization

    init(
        projectPlanRepository: ProjectPlanRepository,
        projectLogRepository: ProjectLogRepository
    ) {
        self.projectPlanRepository = projectPlanRepository
        self.projectLogRepository = projectLogRepository
    }

    // MARK: - Plan Operations

    /// Get all plans with optional filtering by type and archive status
    func getAllPlans(
        type: ProjectPlanType? = nil,
        includeArchived: Bool = false
    ) async throws -> [ProjectPlanModel] {
        return try await projectPlanRepository.getPlans(type: type, includeArchived: includeArchived)
    }

    /// Get active (non-archived) plans
    func getActivePlans() async throws -> [ProjectPlanModel] {
        return try await projectPlanRepository.getActivePlans()
    }

    /// Get archived plans
    func getArchivedPlans() async throws -> [ProjectPlanModel] {
        return try await projectPlanRepository.getArchivedPlans()
    }

    /// Get a specific plan by ID
    func getPlan(id: UUID) async throws -> ProjectPlanModel? {
        return try await projectPlanRepository.getPlan(id: id)
    }

    /// Create a new project plan
    func createPlan(_ plan: ProjectPlanModel) async throws -> ProjectPlanModel {
        return try await projectPlanRepository.createPlan(plan)
    }

    /// Update an existing plan
    func updatePlan(_ plan: ProjectPlanModel) async throws {
        try await projectPlanRepository.updatePlan(plan)
    }

    /// Delete a plan
    func deletePlan(id: UUID) async throws {
        try await projectPlanRepository.deletePlan(id: id)
    }

    /// Archive or unarchive a plan
    func archivePlan(id: UUID, isArchived: Bool = true) async throws {
        try await projectPlanRepository.archivePlan(id: id, isArchived: isArchived)
    }

    /// Unarchive a plan (convenience method)
    func unarchivePlan(id: UUID) async throws {
        try await projectPlanRepository.unarchivePlan(id: id)
    }

    // MARK: - Plan Usage Tracking

    /// Mark a plan as used (increments times used and updates last used date)
    func recordPlanUsage(id: UUID) async throws {
        guard var plan = try await projectPlanRepository.getPlan(id: id) else {
            throw ProjectRepositoryError.planNotFound
        }

        // Update usage tracking fields
        plan = ProjectPlanModel(
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
            referenceUrls: plan.referenceUrls,
            timesUsed: plan.timesUsed + 1,
            lastUsedDate: Date()
        )

        try await projectPlanRepository.updatePlan(plan)
    }

    // MARK: - Plan Steps Management

    /// Add a step to a plan
    func addStep(_ step: ProjectStepModel, to planId: UUID) async throws -> ProjectStepModel {
        return try await projectPlanRepository.addStep(step)
    }

    /// Update a step in a plan
    func updateStep(_ step: ProjectStepModel) async throws {
        try await projectPlanRepository.updateStep(step)
    }

    /// Delete a step from a plan
    func deleteStep(id: UUID) async throws {
        try await projectPlanRepository.deleteStep(id: id)
    }

    /// Reorder steps in a plan
    func reorderSteps(planId: UUID, stepIds: [UUID]) async throws {
        try await projectPlanRepository.reorderSteps(planId: planId, stepIds: stepIds)
    }

    // MARK: - Plan Reference URLs Management

    /// Add a reference URL to a plan
    func addReferenceUrl(_ url: ProjectReferenceUrl, to planId: UUID) async throws {
        try await projectPlanRepository.addReferenceUrl(url, to: planId)
    }

    /// Update a reference URL in a plan
    func updateReferenceUrl(_ url: ProjectReferenceUrl, in planId: UUID) async throws {
        try await projectPlanRepository.updateReferenceUrl(url, in: planId)
    }

    /// Delete a reference URL from a plan
    func deleteReferenceUrl(id: UUID, from planId: UUID) async throws {
        try await projectPlanRepository.deleteReferenceUrl(id: id, from: planId)
    }

    // MARK: - Log Operations

    /// Get all logs with optional status filtering
    func getAllLogs(status: ProjectStatus? = nil) async throws -> [ProjectLogModel] {
        return try await projectLogRepository.getLogs(status: status)
    }

    /// Get a specific log by ID
    func getLog(id: UUID) async throws -> ProjectLogModel? {
        return try await projectLogRepository.getLog(id: id)
    }

    /// Create a new project log
    func createLog(_ log: ProjectLogModel) async throws -> ProjectLogModel {
        return try await projectLogRepository.createLog(log)
    }

    /// Create a log from a plan (convenience method)
    func createLogFromPlan(planId: UUID, title: String? = nil) async throws -> ProjectLogModel {
        guard let plan = try await projectPlanRepository.getPlan(id: planId) else {
            throw ProjectRepositoryError.planNotFound
        }

        // Record plan usage
        try await recordPlanUsage(id: planId)

        // Create log based on plan
        let log = ProjectLogModel(
            title: title ?? plan.title,
            basedOnPlanId: planId,
            tags: plan.tags,
            glassItems: plan.glassItems,
            status: .inProgress
        )

        return try await projectLogRepository.createLog(log)
    }

    /// Update an existing log
    func updateLog(_ log: ProjectLogModel) async throws {
        try await projectLogRepository.updateLog(log)
    }

    /// Delete a log
    func deleteLog(id: UUID) async throws {
        try await projectLogRepository.deleteLog(id: id)
    }

    // MARK: - Log Business Queries

    /// Get logs within a date range
    func getLogsByDateRange(start: Date, end: Date) async throws -> [ProjectLogModel] {
        return try await projectLogRepository.getLogsByDateRange(start: start, end: end)
    }

    /// Get all sold logs (sorted by sale date)
    func getSoldLogs() async throws -> [ProjectLogModel] {
        return try await projectLogRepository.getSoldLogs()
    }

    /// Calculate total revenue from sold projects
    func getTotalRevenue() async throws -> Decimal {
        return try await projectLogRepository.getTotalRevenue()
    }

    /// Get revenue for a specific date range
    func getRevenueForDateRange(start: Date, end: Date) async throws -> Decimal {
        let logs = try await projectLogRepository.getLogsByDateRange(start: start, end: end)
        let soldLogs = logs.filter { $0.status == .sold }
        return soldLogs.reduce(Decimal(0)) { total, log in
            total + (log.pricePoint ?? 0)
        }
    }

    // MARK: - Analytics and Reporting

    /// Get project statistics
    func getProjectStatistics() async throws -> ProjectStatistics {
        let allPlans = try await projectPlanRepository.getAllPlans(includeArchived: true)
        let activePlans = allPlans.filter { !$0.isArchived }
        let archivedPlans = allPlans.filter { $0.isArchived }

        let allLogs = try await projectLogRepository.getAllLogs()
        let inProgressLogs = allLogs.filter { $0.status == .inProgress }
        let completedLogs = allLogs.filter { $0.status == .completed }
        let soldLogs = allLogs.filter { $0.status == .sold }

        let totalRevenue = try await projectLogRepository.getTotalRevenue()

        return ProjectStatistics(
            totalPlans: allPlans.count,
            activePlans: activePlans.count,
            archivedPlans: archivedPlans.count,
            totalLogs: allLogs.count,
            inProgressProjects: inProgressLogs.count,
            completedProjects: completedLogs.count,
            soldProjects: soldLogs.count,
            totalRevenue: totalRevenue
        )
    }

    /// Get most used plans
    func getMostUsedPlans(limit: Int = 10) async throws -> [ProjectPlanModel] {
        let allPlans = try await projectPlanRepository.getActivePlans()
        return allPlans
            .filter { $0.timesUsed > 0 }
            .sorted { $0.timesUsed > $1.timesUsed }
            .prefix(limit)
            .map { $0 }
    }

    /// Get logs based on a specific plan
    func getLogsBasedOnPlan(planId: UUID) async throws -> [ProjectLogModel] {
        let allLogs = try await projectLogRepository.getAllLogs()
        return allLogs.filter { $0.basedOnPlanId == planId }
    }

    /// Get plans that have never been used
    func getUnusedPlans() async throws -> [ProjectPlanModel] {
        let allPlans = try await projectPlanRepository.getActivePlans()
        return allPlans.filter { $0.timesUsed == 0 }
    }
}

// MARK: - Supporting Models

/// Statistics about the project system
struct ProjectStatistics {
    let totalPlans: Int
    let activePlans: Int
    let archivedPlans: Int
    let totalLogs: Int
    let inProgressProjects: Int
    let completedProjects: Int
    let soldProjects: Int
    let totalRevenue: Decimal

    var averageRevenuePerSale: Decimal {
        guard soldProjects > 0 else { return 0 }
        return totalRevenue / Decimal(soldProjects)
    }

    var completionRate: Double {
        guard totalLogs > 0 else { return 0 }
        return Double(completedProjects + soldProjects) / Double(totalLogs)
    }
}
