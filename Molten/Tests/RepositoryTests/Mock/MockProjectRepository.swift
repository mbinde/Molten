//
//  MockProjectRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of ProjectRepository for testing
//

import Foundation

/// Mock implementation of ProjectRepository for testing
/// Stores projects in memory using dictionaries
final class MockProjectRepository: ProjectRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var projects: [UUID: ProjectModel] = [:]
    nonisolated(unsafe) private var steps: [UUID: ProjectStepModel] = [:]

    // MARK: - CRUD Operations

    func createProject(_ project: ProjectModel) async throws -> ProjectModel {
        projects[project.id] = project
        // Also store all steps
        for step in project.steps {
            steps[step.id] = step
        }
        return project
    }

    func getProject(id: UUID) async throws -> ProjectModel? {
        return projects[id]
    }

    func getAllProjects(includeArchived: Bool) async throws -> [ProjectModel] {
        if includeArchived {
            return Array(projects.values)
        } else {
            return projects.values.filter { !$0.isArchived }
        }
    }

    func getActiveProjects() async throws -> [ProjectModel] {
        return projects.values.filter { !$0.isArchived }
    }

    func getArchivedProjects() async throws -> [ProjectModel] {
        return projects.values.filter { $0.isArchived }
    }

    func getProjects(type: ProjectType?, includeArchived: Bool) async throws -> [ProjectModel] {
        var filtered = Array(projects.values)

        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }

        if !includeArchived {
            filtered = filtered.filter { !$0.isArchived }
        }

        return filtered
    }

    func updateProject(_ project: ProjectModel) async throws {
        guard projects[project.id] != nil else {
            throw NSError(domain: "MockProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        projects[project.id] = project
        // Also update all steps
        for step in project.steps {
            steps[step.id] = step
        }
    }

    func deleteProject(id: UUID) async throws {
        // Remove project and all its steps
        if let project = projects[id] {
            for step in project.steps {
                steps.removeValue(forKey: step.id)
            }
        }
        projects.removeValue(forKey: id)
    }

    func archiveProject(id: UUID, isArchived: Bool) async throws {
        guard let project = projects[id] else {
            throw NSError(domain: "MockProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        // Create updated project with new archived status
        let updated = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            dateModified: Date(),
            isArchived: isArchived,
            coe: project.coe,
            techniqueType: project.techniqueType,
            summary: project.summary,
            steps: project.steps,
            estimatedTime: project.estimatedTime,
            difficultyLevel: project.difficultyLevel,
            proposedPriceRange: project.proposedPriceRange,
            images: project.images,
            heroImageId: project.heroImageId,
            glassItems: project.glassItems,
            referenceUrls: project.referenceUrls,
            kilnScheduleId: project.kilnScheduleId,
            author: project.author,
            timesUsed: project.timesUsed,
            lastUsedDate: project.lastUsedDate
        )
        projects[id] = updated
    }

    func unarchiveProject(id: UUID) async throws {
        try await archiveProject(id: id, isArchived: false)
    }

    // MARK: - Steps Management

    func addStep(_ step: ProjectStepModel) async throws -> ProjectStepModel {
        steps[step.id] = step
        // Add step to its project
        let projectId = step.projectId
        if let project = projects[projectId] {
            var updatedSteps = project.steps
            updatedSteps.append(step)
            let updated = ProjectModel(
                id: project.id,
                title: project.title,
                type: project.type,
                dateCreated: project.dateCreated,
                dateModified: Date(),
                isArchived: project.isArchived,
                coe: project.coe,
                techniqueType: project.techniqueType,
                summary: project.summary,
                steps: updatedSteps,
                estimatedTime: project.estimatedTime,
                difficultyLevel: project.difficultyLevel,
                proposedPriceRange: project.proposedPriceRange,
                images: project.images,
                heroImageId: project.heroImageId,
                glassItems: project.glassItems,
                referenceUrls: project.referenceUrls,
                kilnScheduleId: project.kilnScheduleId,
                author: project.author,
                timesUsed: project.timesUsed,
                lastUsedDate: project.lastUsedDate
            )
            projects[projectId] = updated
        }
        return step
    }

    func updateStep(_ step: ProjectStepModel) async throws {
        guard steps[step.id] != nil else {
            throw NSError(domain: "MockProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Step not found"])
        }
        steps[step.id] = step
        // Update step in its project
        let projectId = step.projectId
        if let project = projects[projectId] {
            var updatedSteps = project.steps
            if let index = updatedSteps.firstIndex(where: { $0.id == step.id }) {
                updatedSteps[index] = step
            }
            let updated = ProjectModel(
                id: project.id,
                title: project.title,
                type: project.type,
                dateCreated: project.dateCreated,
                dateModified: Date(),
                isArchived: project.isArchived,
                coe: project.coe,
                techniqueType: project.techniqueType,
                summary: project.summary,
                steps: updatedSteps,
                estimatedTime: project.estimatedTime,
                difficultyLevel: project.difficultyLevel,
                proposedPriceRange: project.proposedPriceRange,
                images: project.images,
                heroImageId: project.heroImageId,
                glassItems: project.glassItems,
                referenceUrls: project.referenceUrls,
                kilnScheduleId: project.kilnScheduleId,
                author: project.author,
                timesUsed: project.timesUsed,
                lastUsedDate: project.lastUsedDate
            )
            projects[projectId] = updated
        }
    }

    func deleteStep(id: UUID) async throws {
        guard let step = steps[id] else {
            throw NSError(domain: "MockProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Step not found"])
        }
        steps.removeValue(forKey: id)
        // Remove step from its project
        let projectId = step.projectId
        if let project = projects[projectId] {
            let updatedSteps = project.steps.filter { $0.id != id }
            let updated = ProjectModel(
                id: project.id,
                title: project.title,
                type: project.type,
                dateCreated: project.dateCreated,
                dateModified: Date(),
                isArchived: project.isArchived,
                coe: project.coe,
                techniqueType: project.techniqueType,
                summary: project.summary,
                steps: updatedSteps,
                estimatedTime: project.estimatedTime,
                difficultyLevel: project.difficultyLevel,
                proposedPriceRange: project.proposedPriceRange,
                images: project.images,
                heroImageId: project.heroImageId,
                glassItems: project.glassItems,
                referenceUrls: project.referenceUrls,
                kilnScheduleId: project.kilnScheduleId,
                author: project.author,
                timesUsed: project.timesUsed,
                lastUsedDate: project.lastUsedDate
            )
            projects[projectId] = updated
        }
    }

    func reorderSteps(projectId: UUID, stepIds: [UUID]) async throws {
        guard let project = projects[projectId] else {
            throw NSError(domain: "MockProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        // Reorder steps according to stepIds
        var reorderedSteps: [ProjectStepModel] = []
        for stepId in stepIds {
            if let step = project.steps.first(where: { $0.id == stepId }) {
                reorderedSteps.append(step)
            }
        }
        let updated = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            dateModified: Date(),
            isArchived: project.isArchived,
            coe: project.coe,
            techniqueType: project.techniqueType,
            summary: project.summary,
            steps: reorderedSteps,
            estimatedTime: project.estimatedTime,
            difficultyLevel: project.difficultyLevel,
            proposedPriceRange: project.proposedPriceRange,
            images: project.images,
            heroImageId: project.heroImageId,
            glassItems: project.glassItems,
            referenceUrls: project.referenceUrls,
            kilnScheduleId: project.kilnScheduleId,
            author: project.author,
            timesUsed: project.timesUsed,
            lastUsedDate: project.lastUsedDate
        )
        projects[projectId] = updated
    }

    // MARK: - Reference URLs Management

    func addReferenceUrl(_ url: ProjectReferenceUrl, to projectId: UUID) async throws {
        guard let project = projects[projectId] else {
            throw NSError(domain: "MockProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        var updatedUrls = project.referenceUrls
        updatedUrls.append(url)
        let updated = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            dateModified: Date(),
            isArchived: project.isArchived,
            coe: project.coe,
            techniqueType: project.techniqueType,
            summary: project.summary,
            steps: project.steps,
            estimatedTime: project.estimatedTime,
            difficultyLevel: project.difficultyLevel,
            proposedPriceRange: project.proposedPriceRange,
            images: project.images,
            heroImageId: project.heroImageId,
            glassItems: project.glassItems,
            referenceUrls: updatedUrls,
            kilnScheduleId: project.kilnScheduleId,
            author: project.author,
            timesUsed: project.timesUsed,
            lastUsedDate: project.lastUsedDate
        )
        projects[projectId] = updated
    }

    func updateReferenceUrl(_ url: ProjectReferenceUrl, in projectId: UUID) async throws {
        guard let project = projects[projectId] else {
            throw NSError(domain: "MockProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        var updatedUrls = project.referenceUrls
        if let index = updatedUrls.firstIndex(where: { $0.id == url.id }) {
            updatedUrls[index] = url
        }
        let updated = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            dateModified: Date(),
            isArchived: project.isArchived,
            coe: project.coe,
            techniqueType: project.techniqueType,
            summary: project.summary,
            steps: project.steps,
            estimatedTime: project.estimatedTime,
            difficultyLevel: project.difficultyLevel,
            proposedPriceRange: project.proposedPriceRange,
            images: project.images,
            heroImageId: project.heroImageId,
            glassItems: project.glassItems,
            referenceUrls: updatedUrls,
            kilnScheduleId: project.kilnScheduleId,
            author: project.author,
            timesUsed: project.timesUsed,
            lastUsedDate: project.lastUsedDate
        )
        projects[projectId] = updated
    }

    func deleteReferenceUrl(id: UUID, from projectId: UUID) async throws {
        guard let project = projects[projectId] else {
            throw NSError(domain: "MockProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        let updatedUrls = project.referenceUrls.filter { $0.id != id }
        let updated = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            dateModified: Date(),
            isArchived: project.isArchived,
            coe: project.coe,
            techniqueType: project.techniqueType,
            summary: project.summary,
            steps: project.steps,
            estimatedTime: project.estimatedTime,
            difficultyLevel: project.difficultyLevel,
            proposedPriceRange: project.proposedPriceRange,
            images: project.images,
            heroImageId: project.heroImageId,
            glassItems: project.glassItems,
            referenceUrls: updatedUrls,
            kilnScheduleId: project.kilnScheduleId,
            author: project.author,
            timesUsed: project.timesUsed,
            lastUsedDate: project.lastUsedDate
        )
        projects[projectId] = updated
    }

    // MARK: - Search

    func searchProjects(query: String, includeArchived: Bool) async throws -> [ProjectModel] {
        let queryLower = query.lowercased()
        var results = projects.values.filter { project in
            // Search in title
            if project.title.lowercased().contains(queryLower) {
                return true
            }
            // Search in summary
            if let summary = project.summary, summary.lowercased().contains(queryLower) {
                return true
            }
            // Search in steps
            for step in project.steps {
                if step.title.lowercased().contains(queryLower) {
                    return true
                }
                if let description = step.description, description.lowercased().contains(queryLower) {
                    return true
                }
            }
            return false
        }

        if !includeArchived {
            results = results.filter { !$0.isArchived }
        }

        return results
    }
}
