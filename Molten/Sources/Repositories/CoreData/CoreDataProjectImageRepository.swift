//
//  CoreDataProjectImageRepository.swift
//  Molten
//
//  Core Data implementation of ProjectImageRepository
//  Stores image metadata (caption, order, relationships to plans/logs)
//  Actual images stored in UserImageRepository
//

import Foundation
import CoreData

/// Core Data implementation of ProjectImageRepository
class CoreDataProjectImageRepository: ProjectImageRepository {
    private let context: NSManagedObjectContext

    nonisolated init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Create

    func createImageMetadata(_ metadata: ProjectImageModel) async throws -> ProjectImageModel {
        return try await context.perform {
            let entity = ProjectImage(context: self.context)
            self.mapModelToEntity(metadata, entity: entity)
            try self.context.save()
            return metadata
        }
    }

    // MARK: - Read

    func getImages(for projectId: UUID, type: ProjectType) async throws -> [ProjectImageModel] {
        return try await context.perform {
            let request = NSFetchRequest<ProjectImage>(entityName: "ProjectImage")

            // Filter by project type and ID
            switch type {
            case .plan:
                request.predicate = NSPredicate(format: "plan.id == %@", projectId as CVarArg)
            case .log:
                request.predicate = NSPredicate(format: "log.id == %@", projectId as CVarArg)
            }

            // Sort by order
            request.sortDescriptors = [NSSortDescriptor(key: "order_index", ascending: true)]

            let entities = try self.context.fetch(request)
            return entities.compactMap { self.mapEntityToModel($0, projectId: projectId, projectType: type) }
        }
    }

    func getHeroImage(for projectId: UUID, type: ProjectType) async throws -> ProjectImageModel? {
        return try await context.perform {
            // Get the hero image ID from the plan or log
            var heroImageId: UUID?

            switch type {
            case .plan:
                let planRequest = NSFetchRequest<ProjectPlan>(entityName: "ProjectPlan")
                planRequest.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
                planRequest.fetchLimit = 1
                if let plan = try self.context.fetch(planRequest).first {
                    heroImageId = plan.hero_image_id
                }
            case .log:
                let logRequest = NSFetchRequest<Logbook>(entityName: "Logbook")
                logRequest.predicate = NSPredicate(format: "id == %@", projectId as CVarArg)
                logRequest.fetchLimit = 1
                if let log = try self.context.fetch(logRequest).first {
                    heroImageId = log.hero_image_id
                }
            }

            guard let heroId = heroImageId else { return nil }

            // Fetch the image with that ID
            let request = NSFetchRequest<ProjectImage>(entityName: "ProjectImage")
            request.predicate = NSPredicate(format: "id == %@", heroId as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else { return nil }
            return self.mapEntityToModel(entity, projectId: projectId, projectType: type)
        }
    }

    // MARK: - Update

    func updateImageMetadata(_ metadata: ProjectImageModel) async throws {
        try await context.perform {
            let request = NSFetchRequest<ProjectImage>(entityName: "ProjectImage")
            request.predicate = NSPredicate(format: "id == %@", metadata.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else {
                throw ProjectImageRepositoryError.imageNotFound
            }

            self.mapModelToEntity(metadata, entity: entity)
            try self.context.save()
        }
    }

    func reorderImages(projectId: UUID, type: ProjectType, imageIds: [UUID]) async throws {
        try await context.perform {
            for (index, imageId) in imageIds.enumerated() {
                let request = NSFetchRequest<ProjectImage>(entityName: "ProjectImage")
                request.predicate = NSPredicate(format: "id == %@", imageId as CVarArg)
                request.fetchLimit = 1

                if let entity = try self.context.fetch(request).first {
                    entity.order_index = Int32(index)
                }
            }

            try self.context.save()
        }
    }

    // MARK: - Delete

    func deleteImageMetadata(id: UUID) async throws {
        try await context.perform {
            let request = NSFetchRequest<ProjectImage>(entityName: "ProjectImage")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else {
                throw ProjectImageRepositoryError.imageNotFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    // MARK: - Mapping Helpers

    private func mapModelToEntity(_ model: ProjectImageModel, entity: ProjectImage) {
        entity.id = model.id
        entity.caption = model.caption
        entity.date_added = model.dateAdded
        entity.file_extension = model.fileExtension
        entity.file_name = model.fileName
        entity.order_index = Int32(model.order)

        // Set the relationship based on project type
        switch model.projectType {
        case .plan:
            // Fetch the plan and set relationship
            let planRequest = NSFetchRequest<ProjectPlan>(entityName: "ProjectPlan")
            planRequest.predicate = NSPredicate(format: "id == %@", model.projectId as CVarArg)
            planRequest.fetchLimit = 1
            if let plan = try? context.fetch(planRequest).first {
                entity.plan = plan
                entity.log = nil
            }
        case .log:
            // Fetch the log and set relationship
            let logRequest = NSFetchRequest<Logbook>(entityName: "Logbook")
            logRequest.predicate = NSPredicate(format: "id == %@", model.projectId as CVarArg)
            logRequest.fetchLimit = 1
            if let log = try? context.fetch(logRequest).first {
                entity.log = log
                entity.plan = nil
            }
        }
    }

    private func mapEntityToModel(_ entity: ProjectImage, projectId: UUID, projectType: ProjectType) -> ProjectImageModel? {
        guard let id = entity.id,
              let fileExtension = entity.file_extension,
              let dateAdded = entity.date_added else {
            return nil
        }

        return ProjectImageModel(
            id: id,
            projectId: projectId,
            projectType: projectType,
            fileExtension: fileExtension,
            caption: entity.caption,
            dateAdded: dateAdded,
            order: Int(entity.order_index)
        )
    }
}

// MARK: - Errors

enum ProjectImageRepositoryError: Error {
    case imageNotFound
    case invalidProjectType
}
