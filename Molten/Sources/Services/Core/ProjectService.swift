//
//  ProjectService.swift
//  Flameworker
//
//  Service layer for project management (plans and logs)
//  Orchestrates ProjectRepository and LogbookRepository operations
//

import Foundation

/// Service for managing glass art projects (plans and logs)
/// Following the repository pattern: services orchestrate, models contain business logic
@preconcurrency
class ProjectService {

    // MARK: - Dependencies

    nonisolated(unsafe) private let projectRepository: ProjectRepository
    nonisolated(unsafe) private let logbookRepository: LogbookRepository
    nonisolated(unsafe) private let userTagsRepository: UserTagsRepository

    // MARK: - Exposed Dependencies

    /// Direct access to plan repository for advanced operations
    var planRepository: ProjectRepository {
        return projectRepository
    }

    /// Direct access to log repository for advanced operations
    var logRepository: LogbookRepository {
        return logbookRepository
    }

    /// Direct access to user tags repository for advanced operations
    var tagsRepository: UserTagsRepository {
        return userTagsRepository
    }

    // MARK: - Initialization

    nonisolated init(
        projectRepository: ProjectRepository,
        logbookRepository: LogbookRepository,
        userTagsRepository: UserTagsRepository
    ) {
        self.projectRepository = projectRepository
        self.logbookRepository = logbookRepository
        self.userTagsRepository = userTagsRepository
    }

    // MARK: - Plan Operations

    /// Get all plans with optional filtering by type and archive status
    func getAllProjects(
        type: ProjectType? = nil,
        includeArchived: Bool = false
    ) async throws -> [ProjectModel] {
        return try await projectRepository.getProjects(type: type, includeArchived: includeArchived)
    }

    /// Get active (non-archived) plans
    func getActiveProjects() async throws -> [ProjectModel] {
        return try await projectRepository.getActiveProjects()
    }

    /// Get archived plans
    func getArchivedProjects() async throws -> [ProjectModel] {
        return try await projectRepository.getArchivedProjects()
    }

    /// Get a specific plan by ID
    func getProject(id: UUID) async throws -> ProjectModel? {
        return try await projectRepository.getProject(id: id)
    }

    /// Create a new project plan
    func createProject(_ plan: ProjectModel) async throws -> ProjectModel {
        return try await projectRepository.createProject(plan)
    }

    /// Update an existing plan
    func updateProject(_ plan: ProjectModel) async throws {
        try await projectRepository.updateProject(plan)
    }

    /// Delete a plan
    func deleteProject(id: UUID) async throws {
        try await projectRepository.deleteProject(id: id)
    }

    /// Archive or unarchive a plan
    func archiveProject(id: UUID, isArchived: Bool = true) async throws {
        try await projectRepository.archiveProject(id: id, isArchived: isArchived)
    }

    /// Unarchive a plan (convenience method)
    func unarchiveProject(id: UUID) async throws {
        try await projectRepository.unarchiveProject(id: id)
    }

    // MARK: - Plan Usage Tracking

    /// Mark a plan as used (increments times used and updates last used date)
    func recordPlanUsage(id: UUID) async throws {
        guard var plan = try await projectRepository.getProject(id: id) else {
            throw ProjectRepositoryError.planNotFound
        }

        // Update usage tracking fields
        plan = ProjectModel(
            id: plan.id,
            title: plan.title,
            type: plan.type,
            dateCreated: plan.dateCreated,
            dateModified: Date(),
            isArchived: plan.isArchived,
            coe: plan.coe,
            summary: plan.summary,
            steps: plan.steps,
            estimatedTime: plan.estimatedTime,
            difficultyLevel: plan.difficultyLevel,
            proposedPriceRange: plan.proposedPriceRange,
            images: plan.images,
            heroImageId: plan.heroImageId,
            glassItems: plan.glassItems,
            referenceUrls: plan.referenceUrls,
            author: plan.author,
            timesUsed: plan.timesUsed + 1,
            lastUsedDate: Date()
        )

        try await projectRepository.updateProject(plan)
    }

    // MARK: - Plan Steps Management

    /// Add a step to a plan
    func addStep(_ step: ProjectStepModel, to projectId: UUID) async throws -> ProjectStepModel {
        return try await projectRepository.addStep(step)
    }

    /// Update a step in a plan
    func updateStep(_ step: ProjectStepModel) async throws {
        try await projectRepository.updateStep(step)
    }

    /// Delete a step from a plan
    func deleteStep(id: UUID) async throws {
        try await projectRepository.deleteStep(id: id)
    }

    /// Reorder steps in a plan
    func reorderSteps(projectId: UUID, stepIds: [UUID]) async throws {
        try await projectRepository.reorderSteps(projectId: projectId, stepIds: stepIds)
    }

    // MARK: - Plan Reference URLs Management

    /// Add a reference URL to a plan
    func addReferenceUrl(_ url: ProjectReferenceUrl, to projectId: UUID) async throws {
        try await projectRepository.addReferenceUrl(url, to: projectId)
    }

    /// Update a reference URL in a plan
    func updateReferenceUrl(_ url: ProjectReferenceUrl, in projectId: UUID) async throws {
        try await projectRepository.updateReferenceUrl(url, in: projectId)
    }

    /// Delete a reference URL from a plan
    func deleteReferenceUrl(id: UUID, from projectId: UUID) async throws {
        try await projectRepository.deleteReferenceUrl(id: id, from: projectId)
    }

    // MARK: - Log Operations

    /// Get all logs with optional status filtering
    func getAllLogs(status: ProjectStatus? = nil) async throws -> [LogbookModel] {
        return try await logbookRepository.getLogs(status: status)
    }

    /// Get a specific log by ID
    func getLog(id: UUID) async throws -> LogbookModel? {
        return try await logbookRepository.getLog(id: id)
    }

    /// Create a new project log
    func createLog(_ log: LogbookModel) async throws -> LogbookModel {
        return try await logbookRepository.createLog(log)
    }

    /// Create a log from a plan (convenience method)
    func createLogFromPlan(projectId: UUID, title: String? = nil) async throws -> LogbookModel {
        guard let plan = try await projectRepository.getProject(id: projectId) else {
            throw ProjectRepositoryError.planNotFound
        }

        // Record plan usage
        try await recordPlanUsage(id: projectId)

        // Fetch tags from UserTagsRepository
        let tags = try await userTagsRepository.fetchTags(ownerType: .project, ownerId: projectId.uuidString)

        // Create log based on plan
        let log = LogbookModel(
            title: title ?? plan.title,
            basedOnProjectIds: [projectId],
            tags: tags,
            glassItems: plan.glassItems,
            status: .inProgress
        )

        return try await logbookRepository.createLog(log)
    }

    /// Update an existing log
    func updateLog(_ log: LogbookModel) async throws {
        try await logbookRepository.updateLog(log)
    }

    /// Delete a log
    func deleteLog(id: UUID) async throws {
        try await logbookRepository.deleteLog(id: id)
    }

    // MARK: - Tag Management

    /// Get tags for a specific project
    func getTags(forProject projectId: UUID) async throws -> [String] {
        return try await userTagsRepository.fetchTags(ownerType: .project, ownerId: projectId.uuidString)
    }

    /// Get tags for multiple projects (batch operation)
    func getTags(forProjects projectIds: [UUID]) async throws -> [UUID: [String]] {
        let ownerIds = projectIds.map { $0.uuidString }
        let tagsByOwnerId = try await userTagsRepository.fetchTagsForOwners(ownerType: .project, ownerIds: ownerIds)

        // Convert back to UUID keys
        var result: [UUID: [String]] = [:]
        for projectId in projectIds {
            result[projectId] = tagsByOwnerId[projectId.uuidString] ?? []
        }
        return result
    }

    /// Set tags for a project (replaces all existing tags)
    func setTags(_ tags: [String], forProject projectId: UUID) async throws {
        try await userTagsRepository.setTags(tags, ownerType: .project, ownerId: projectId.uuidString)
    }

    /// Add a tag to a project
    func addTag(_ tag: String, toProject projectId: UUID) async throws {
        try await userTagsRepository.addTag(tag, ownerType: .project, ownerId: projectId.uuidString)
    }

    /// Remove a tag from a project
    func removeTag(_ tag: String, fromProject projectId: UUID) async throws {
        try await userTagsRepository.removeTag(tag, ownerType: .project, ownerId: projectId.uuidString)
    }

    /// Get all distinct tags used in projects
    func getAllProjectTags() async throws -> [String] {
        return try await userTagsRepository.getAllTags(forOwnerType: .project)
    }

    /// Get projects that have a specific tag
    func getProjects(withTag tag: String) async throws -> [ProjectModel] {
        let ownerIds = try await userTagsRepository.fetchOwners(withTag: tag, ownerType: .project)
        let uuids = ownerIds.compactMap { UUID(uuidString: $0) }

        var projects: [ProjectModel] = []
        for uuid in uuids {
            if let project = try await projectRepository.getProject(id: uuid) {
                projects.append(project)
            }
        }
        return projects
    }

    // MARK: - Log Business Queries

    /// Get logs within a date range
    func getLogsByDateRange(start: Date, end: Date) async throws -> [LogbookModel] {
        return try await logbookRepository.getLogsByDateRange(start: start, end: end)
    }

    /// Get all sold logs (sorted by sale date)
    func getSoldLogs() async throws -> [LogbookModel] {
        return try await logbookRepository.getSoldLogs()
    }

    /// Calculate total revenue from sold projects
    func getTotalRevenue() async throws -> Decimal {
        return try await logbookRepository.getTotalRevenue()
    }

    /// Get revenue for a specific date range
    func getRevenueForDateRange(start: Date, end: Date) async throws -> Decimal {
        let logs = try await logbookRepository.getLogsByDateRange(start: start, end: end)
        let soldLogs = logs.filter { $0.status == .sold }
        return soldLogs.reduce(Decimal(0)) { total, log in
            total + (log.pricePoint ?? 0)
        }
    }

    // MARK: - Analytics and Reporting

    /// Get project statistics
    func getProjectStatistics() async throws -> ProjectStatistics {
        let allProjects = try await projectRepository.getAllProjects(includeArchived: true)
        let activeProjects = allProjects.filter { !$0.isArchived }
        let archivedProjects = allProjects.filter { $0.isArchived }

        let allLogs = try await logbookRepository.getAllLogs()
        let inProgressLogs = allLogs.filter { $0.status == .inProgress }
        let completedLogs = allLogs.filter { $0.status == .completed }
        let soldLogs = allLogs.filter { $0.status == .sold }

        let totalRevenue = try await logbookRepository.getTotalRevenue()

        return ProjectStatistics(
            totalProjects: allProjects.count,
            activeProjects: activeProjects.count,
            archivedProjects: archivedProjects.count,
            totalLogs: allLogs.count,
            inProgressProjects: inProgressLogs.count,
            completedProjects: completedLogs.count,
            soldProjects: soldLogs.count,
            totalRevenue: totalRevenue
        )
    }

    /// Get most used plans
    func getMostUsedPlans(limit: Int = 10) async throws -> [ProjectModel] {
        let allProjects = try await projectRepository.getActiveProjects()
        return allProjects
            .filter { $0.timesUsed > 0 }
            .sorted { $0.timesUsed > $1.timesUsed }
            .prefix(limit)
            .map { $0 }
    }

    /// Get logs based on a specific plan
    func getLogsBasedOnPlan(projectId: UUID) async throws -> [LogbookModel] {
        let allLogs = try await logbookRepository.getAllLogs()
        return allLogs.filter { $0.basedOnProjectIds.contains(projectId) }
    }

    /// Get plans that have never been used
    func getUnusedPlans() async throws -> [ProjectModel] {
        let allProjects = try await projectRepository.getActiveProjects()
        return allProjects.filter { $0.timesUsed == 0 }
    }
}

// MARK: - Supporting Models

/// Statistics about the project system
nonisolated struct ProjectStatistics {
    let totalProjects: Int
    let activeProjects: Int
    let archivedProjects: Int
    let totalLogs: Int
    let inProgressProjects: Int
    let completedProjects: Int
    let soldProjects: Int
    let totalRevenue: Decimal

    nonisolated var averageRevenuePerSale: Decimal {
        guard soldProjects > 0 else { return 0 }
        return totalRevenue / Decimal(soldProjects)
    }

    nonisolated var completionRate: Double {
        guard totalLogs > 0 else { return 0 }
        return Double(completedProjects + soldProjects) / Double(totalLogs)
    }
}
