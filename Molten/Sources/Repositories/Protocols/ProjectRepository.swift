//
//  ProjectRepository.swift
//  Molten
//
//  Protocol for Project data persistence operations
//

import Foundation

nonisolated protocol ProjectRepository {
    // MARK: - CRUD Operations

    func createProject(_ project: ProjectModel) async throws -> ProjectModel
    func getProject(id: UUID) async throws -> ProjectModel?
    func getAllProjects(includeArchived: Bool) async throws -> [ProjectModel]
    func getActiveProjects() async throws -> [ProjectModel]  // Convenience: excludes archived
    func getArchivedProjects() async throws -> [ProjectModel]  // Convenience: only archived
    func getProjects(type: ProjectType?, includeArchived: Bool) async throws -> [ProjectModel]
    func updateProject(_ project: ProjectModel) async throws
    func deleteProject(id: UUID) async throws  // Permanent deletion
    func archiveProject(id: UUID, isArchived: Bool) async throws  // Toggle archive status
    func unarchiveProject(id: UUID) async throws  // Convenience: shorthand for archiveProject(id, false)

    // MARK: - Steps Management

    func addStep(_ step: ProjectStepModel) async throws -> ProjectStepModel
    func updateStep(_ step: ProjectStepModel) async throws
    func deleteStep(id: UUID) async throws
    func reorderSteps(projectId: UUID, stepIds: [UUID]) async throws

    // MARK: - Reference URLs Management

    func addReferenceUrl(_ url: ProjectReferenceUrl, to projectId: UUID) async throws
    func updateReferenceUrl(_ url: ProjectReferenceUrl, in projectId: UUID) async throws
    func deleteReferenceUrl(id: UUID, from projectId: UUID) async throws
}
