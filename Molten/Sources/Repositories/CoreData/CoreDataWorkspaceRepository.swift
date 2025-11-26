//
//  CoreDataWorkspaceRepository.swift
//  Molten
//
//  Core Data implementation of WorkspaceRepository
//  Provides persistent storage for workspace records
//

@preconcurrency import CoreData
import Foundation
import OSLog

/// Core Data implementation of WorkspaceRepository
class CoreDataWorkspaceRepository: @unchecked Sendable, WorkspaceRepository {

    // MARK: - Dependencies

    let context: NSManagedObjectContext
    private let log = Logger(subsystem: "com.motleywoods.molten", category: "workspace-repository")

    // MARK: - Initialization

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
        self.context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    // MARK: - Basic CRUD Operations

    func fetchAllWorkspaces() async throws -> [WorkspaceModel] {
        try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Workspace")
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            let results = try context.fetch(fetchRequest)
            return results.compactMap { self.convertToWorkspaceModel($0) }
        }
    }

    func fetchWorkspace(byId id: UUID) async throws -> WorkspaceModel? {
        try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Workspace")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            let results = try context.fetch(fetchRequest)
            return results.first.flatMap { self.convertToWorkspaceModel($0) }
        }
    }

    func fetchWorkspace(byName name: String) async throws -> WorkspaceModel? {
        try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Workspace")
            fetchRequest.predicate = NSPredicate(format: "name == %@", name)
            fetchRequest.fetchLimit = 1

            let results = try context.fetch(fetchRequest)
            return results.first.flatMap { self.convertToWorkspaceModel($0) }
        }
    }

    func createWorkspace(_ workspace: WorkspaceModel) async throws -> WorkspaceModel {
        try await CoreDataHelper.performAsync(on: context) { context in
            guard let entity = NSEntityDescription.entity(forEntityName: "Workspace", in: context) else {
                throw CoreDataWorkspaceRepositoryError.entityNotFound("Workspace")
            }

            let coreDataItem = NSManagedObject(entity: entity, insertInto: context)
            self.updateCoreDataEntity(coreDataItem, with: workspace)

            try context.save()

            self.log.debug("Created workspace: \(workspace.name) (\(workspace.id))")
            return workspace
        }
    }

    func updateWorkspace(_ workspace: WorkspaceModel) async throws -> WorkspaceModel {
        try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Workspace")
            fetchRequest.predicate = NSPredicate(format: "id == %@", workspace.id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataItem = try context.fetch(fetchRequest).first else {
                throw CoreDataWorkspaceRepositoryError.workspaceNotFound(workspace.id.uuidString)
            }

            self.updateCoreDataEntity(coreDataItem, with: workspace)
            try context.save()

            return workspace
        }
    }

    func deleteWorkspace(byId id: UUID) async throws {
        try await CoreDataHelper.performAsync(on: context) { context in
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Workspace")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            guard let coreDataItem = try context.fetch(fetchRequest).first else {
                throw CoreDataWorkspaceRepositoryError.workspaceNotFound(id.uuidString)
            }

            context.delete(coreDataItem)
            try context.save()

            self.log.debug("Deleted workspace: \(id)")
        }
    }

    // MARK: - Default Workspace

    func getOrCreateDefaultWorkspace() async throws -> WorkspaceModel {
        // First try to fetch existing default workspace
        if let existing = try await fetchWorkspace(byName: WorkspaceModel.defaultWorkspaceName) {
            return existing
        }

        // Create the default workspace
        let defaultWorkspace = WorkspaceModel.createDefault()
        return try await createWorkspace(defaultWorkspace)
    }

    // MARK: - Private Helpers

    nonisolated private func convertToWorkspaceModel(_ coreDataItem: NSManagedObject) -> WorkspaceModel? {
        guard let id = coreDataItem.value(forKey: "id") as? UUID,
              let name = coreDataItem.value(forKey: "name") as? String else {
            log.error("Failed to convert Core Data item to WorkspaceModel - missing required properties")
            return nil
        }

        let date_created = coreDataItem.value(forKey: "date_created") as? Date ?? Date()
        let date_modified = coreDataItem.value(forKey: "date_modified") as? Date ?? Date()

        return WorkspaceModel(
            id: id,
            name: name,
            date_created: date_created,
            date_modified: date_modified
        )
    }

    nonisolated private func updateCoreDataEntity(_ coreDataItem: NSManagedObject, with workspace: WorkspaceModel) {
        coreDataItem.setValue(workspace.id, forKey: "id")
        coreDataItem.setValue(workspace.name, forKey: "name")
        coreDataItem.setValue(workspace.date_created, forKey: "date_created")
        coreDataItem.setValue(workspace.date_modified, forKey: "date_modified")
    }
}

// MARK: - Errors

enum CoreDataWorkspaceRepositoryError: Error, LocalizedError {
    case entityNotFound(String)
    case workspaceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entityName):
            return "Core Data entity not found: \(entityName)"
        case .workspaceNotFound(let identifier):
            return "Workspace not found: \(identifier)"
        }
    }
}
