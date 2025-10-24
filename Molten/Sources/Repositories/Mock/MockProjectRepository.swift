//
//  MockProjectRepository.swift
//  Molten
//
//  Mock implementation of ProjectRepository for testing
//

import Foundation

/// Mock implementation of ProjectRepository for testing
class MockProjectRepository: @unchecked Sendable, ProjectRepository {
    nonisolated(unsafe) private var projects: [UUID: ProjectModel] = [:]
    nonisolated(unsafe) private var steps: [UUID: ProjectStepModel] = [:]
    nonisolated(unsafe) private var imageRepository: UserImageRepository?

    nonisolated init(imageRepository: UserImageRepository? = nil) {
        self.imageRepository = imageRepository
    }

    // MARK: - CRUD Operations

    func createProject(_ project: ProjectModel) async throws -> ProjectModel {
        projects[project.id] = project
        return project
    }

    func getProject(id: UUID) async throws -> ProjectModel? {
        return projects[id]
    }

    func getAllProjects(includeArchived: Bool) async throws -> [ProjectModel] {
        if includeArchived {
            return Array(projects.values).sorted { $0.dateCreated > $1.dateCreated }
        } else {
            let values = Array(projects.values); return values.filter { !$0.isArchived }.sorted { $0.dateCreated > $1.dateCreated }
        }
    }

    func getActiveProjects() async throws -> [ProjectModel] {
        let values = Array(projects.values); return values.filter { !$0.isArchived }.sorted { $0.dateCreated > $1.dateCreated }
    }

    func getArchivedProjects() async throws -> [ProjectModel] {
        let values = Array(projects.values); return values.filter { $0.isArchived }.sorted { $0.dateCreated > $1.dateCreated }
    }

    func getProjects(type: ProjectType?, includeArchived: Bool) async throws -> [ProjectModel] {
        var filtered = Array(projects.values)

        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }

        if !includeArchived {
            filtered = filtered.filter { !$0.isArchived }
        }

        return filtered.sorted { $0.dateCreated > $1.dateCreated }
    }

    func updateProject(_ project: ProjectModel) async throws {
        guard projects[project.id] != nil else {
            throw ProjectRepositoryError.planNotFound
        }
        projects[project.id] = project
    }

    func deleteProject(id: UUID) async throws {
        guard projects[id] != nil else {
            throw ProjectRepositoryError.planNotFound
        }
        projects.removeValue(forKey: id)
    }

    func archiveProject(id: UUID, isArchived: Bool) async throws {
        guard let project = projects[id] else {
            throw ProjectRepositoryError.planNotFound
        }
        // Create a new instance with the updated isArchived value
        let updatedProject = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            dateModified: Date(),
            isArchived: isArchived,
            coe: project.coe,
            summary: project.summary,
            steps: project.steps,
            estimatedTime: project.estimatedTime,
            difficultyLevel: project.difficultyLevel,
            proposedPriceRange: project.proposedPriceRange,
            images: project.images,
            heroImageId: project.heroImageId,
            glassItems: project.glassItems,
            referenceUrls: project.referenceUrls,
            author: project.author,
            timesUsed: project.timesUsed,
            lastUsedDate: project.lastUsedDate
        )
        projects[id] = updatedProject
    }

    func unarchiveProject(id: UUID) async throws {
        try await archiveProject(id: id, isArchived: false)
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

    func reorderSteps(projectId: UUID, stepIds: [UUID]) async throws {
        // In mock, we don't need to do anything special for reordering
        // The order is maintained by the stepIds array passed in
    }

    // MARK: - Reference URLs Management

    func addReferenceUrl(_ url: ProjectReferenceUrl, to projectId: UUID) async throws {
        guard let project = projects[projectId] else {
            throw ProjectRepositoryError.planNotFound
        }
        var updatedUrls = project.referenceUrls
        updatedUrls.append(url)

        let updatedProject = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            dateModified: Date(),
            isArchived: project.isArchived,
            coe: project.coe,
            summary: project.summary,
            steps: project.steps,
            estimatedTime: project.estimatedTime,
            difficultyLevel: project.difficultyLevel,
            proposedPriceRange: project.proposedPriceRange,
            images: project.images,
            heroImageId: project.heroImageId,
            glassItems: project.glassItems,
            referenceUrls: updatedUrls,
            author: project.author,
            timesUsed: project.timesUsed,
            lastUsedDate: project.lastUsedDate
        )
        projects[projectId] = updatedProject
    }

    func updateReferenceUrl(_ url: ProjectReferenceUrl, in projectId: UUID) async throws {
        guard let project = projects[projectId] else {
            throw ProjectRepositoryError.planNotFound
        }
        var updatedUrls = project.referenceUrls
        if let index = updatedUrls.firstIndex(where: { $0.id == url.id }) {
            updatedUrls[index] = url

            let updatedProject = ProjectModel(
                id: project.id,
                title: project.title,
                type: project.type,
                dateCreated: project.dateCreated,
                dateModified: Date(),
                isArchived: project.isArchived,
                coe: project.coe,
                summary: project.summary,
                steps: project.steps,
                estimatedTime: project.estimatedTime,
                difficultyLevel: project.difficultyLevel,
                proposedPriceRange: project.proposedPriceRange,
                images: project.images,
                heroImageId: project.heroImageId,
                glassItems: project.glassItems,
                referenceUrls: updatedUrls,
                timesUsed: project.timesUsed,
                lastUsedDate: project.lastUsedDate
            )
            projects[projectId] = updatedProject
        }
    }

    func deleteReferenceUrl(id: UUID, from projectId: UUID) async throws {
        guard let project = projects[projectId] else {
            throw ProjectRepositoryError.planNotFound
        }
        var updatedUrls = project.referenceUrls
        updatedUrls.removeAll { $0.id == id }

        let updatedProject = ProjectModel(
            id: project.id,
            title: project.title,
            type: project.type,
            dateCreated: project.dateCreated,
            dateModified: Date(),
            isArchived: project.isArchived,
            coe: project.coe,
            summary: project.summary,
            steps: project.steps,
            estimatedTime: project.estimatedTime,
            difficultyLevel: project.difficultyLevel,
            proposedPriceRange: project.proposedPriceRange,
            images: project.images,
            heroImageId: project.heroImageId,
            glassItems: project.glassItems,
            referenceUrls: updatedUrls,
            author: project.author,
            timesUsed: project.timesUsed,
            lastUsedDate: project.lastUsedDate
        )
        projects[projectId] = updatedProject
    }

    // MARK: - Search

    func searchProjects(query: String, includeArchived: Bool) async throws -> [ProjectModel] {
        let lowercaseQuery = query.lowercased()

        var filtered = Array(projects.values)

        if !includeArchived {
            filtered = filtered.filter { !$0.isArchived }
        }

        // Search in project fields
        let matches = filtered.filter { project in
            // Search title
            if project.title.lowercased().contains(lowercaseQuery) {
                return true
            }

            // Search summary
            if let summary = project.summary, summary.lowercased().contains(lowercaseQuery) {
                return true
            }

            // Search steps
            for step in project.steps {
                if step.title.lowercased().contains(lowercaseQuery) {
                    return true
                }
                if let description = step.description, description.lowercased().contains(lowercaseQuery) {
                    return true
                }
            }

            return false
        }

        // Add OCR text search if imageRepository is available
        var matchesWithOCR = Set(matches.map { $0.id })

        if let imageRepository = imageRepository {
            for project in filtered {
                // Search OCR text from project images
                let ocrText = try? await imageRepository.getOCRText(
                    ownerType: .projectPlan,
                    ownerId: project.id.uuidString
                )

                if let ocrText = ocrText, !ocrText.isEmpty, ocrText.lowercased().contains(lowercaseQuery) {
                    matchesWithOCR.insert(project.id)
                }
            }
        }

        // Combine matches and return sorted
        let finalMatches = filtered.filter { matchesWithOCR.contains($0.id) }
        return finalMatches.sorted { $0.dateCreated > $1.dateCreated }
    }

    // MARK: - Test Helpers

    nonisolated func reset() {
        projects.removeAll()
        steps.removeAll()
    }

    nonisolated func getProjectCount() -> Int {
        return projects.count
    }
}
