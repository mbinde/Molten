//
//  CoreDataUserImageRepository.swift
//  Molten
//
//  Core Data implementation of UserImageRepository
//  Stores images in Core Data with CloudKit sync support
//

import Foundation
import CoreData
#if canImport(UIKit)
import UIKit

/// Core Data implementation of UserImageRepository
/// Stores image data in Core Data with CloudKit sync
actor CoreDataUserImageRepository: UserImageRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - New Generic Methods

    func saveImage(_ image: UIImage, ownerType: ImageOwnerType, ownerId: String?, type: UserImageType) async throws -> UserImageModel {
        // Resize if needed (max 2048px)
        let resizedImage = resizeImageIfNeeded(image, maxDimension: 2048)

        // Compress image to JPEG
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.85) else {
            throw UserImageError.invalidImageData
        }

        return try await context.perform {
            // If this is a primary image, demote any existing primary image
            if type == .primary, let ownerId = ownerId {
                let fetchRequest = UserImage.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "ownerType == %@ AND ownerId == %@ AND imageType == %@",
                    ownerType.rawValue, ownerId, UserImageType.primary.rawValue
                )

                let existingPrimary = try self.context.fetch(fetchRequest)
                for existingImage in existingPrimary {
                    existingImage.imageType = UserImageType.alternate.rawValue
                    existingImage.dateModified = Date()
                }
            }

            // Create new UserImage entity
            let entity = UserImage(context: self.context)
            entity.id = UUID()
            entity.ownerType = ownerType.rawValue
            entity.ownerId = ownerId
            entity.imageType = type.rawValue
            entity.imageData = imageData
            entity.fileExtension = "jpg"
            entity.dateCreated = Date()
            entity.dateModified = Date()

            try self.context.save()

            return self.convertToModel(entity)
        }
    }

    func getImages(ownerType: ImageOwnerType, ownerId: String) async throws -> [UserImageModel] {
        try await context.perform {
            let request = UserImage.fetchRequest()
            request.predicate = NSPredicate(
                format: "ownerType == %@ AND ownerId == %@",
                ownerType.rawValue, ownerId
            )
            request.sortDescriptors = [
                NSSortDescriptor(key: "imageType", ascending: true), // Primary first
                NSSortDescriptor(key: "dateCreated", ascending: false)
            ]

            let entities = try self.context.fetch(request)
            return entities.map { self.convertToModel($0) }
        }
    }

    func getPrimaryImage(ownerType: ImageOwnerType, ownerId: String) async throws -> UserImageModel? {
        try await context.perform {
            let request = UserImage.fetchRequest()
            request.predicate = NSPredicate(
                format: "ownerType == %@ AND ownerId == %@ AND imageType == %@",
                ownerType.rawValue, ownerId, UserImageType.primary.rawValue
            )
            request.fetchLimit = 1

            let entities = try self.context.fetch(request)
            return entities.first.map { self.convertToModel($0) }
        }
    }

    func getStandaloneImages() async throws -> [UserImageModel] {
        try await context.perform {
            let request = UserImage.fetchRequest()
            request.predicate = NSPredicate(format: "ownerType == %@", ImageOwnerType.standalone.rawValue)
            request.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: false)]

            let entities = try self.context.fetch(request)
            return entities.map { self.convertToModel($0) }
        }
    }

    func deleteAllImages(ownerType: ImageOwnerType, ownerId: String) async throws {
        try await context.perform {
            let request = UserImage.fetchRequest()
            request.predicate = NSPredicate(
                format: "ownerType == %@ AND ownerId == %@",
                ownerType.rawValue, ownerId
            )

            let entities = try self.context.fetch(request)
            for entity in entities {
                self.context.delete(entity)
            }

            try self.context.save()
        }
    }

    // MARK: - Common Methods

    func loadImage(_ model: UserImageModel) async throws -> UIImage? {
        try await context.perform {
            let request = UserImage.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", model.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else {
                throw UserImageError.imageNotFound
            }

            guard let imageData = entity.imageData else {
                throw UserImageError.invalidImageData
            }

            guard let image = UIImage(data: imageData) else {
                throw UserImageError.failedToLoadImage("Could not decode image data")
            }

            return image
        }
    }

    func deleteImage(_ id: UUID) async throws {
        try await context.perform {
            let request = UserImage.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else {
                throw UserImageError.imageNotFound
            }

            self.context.delete(entity)
            try self.context.save()
        }
    }

    func updateImageType(_ id: UUID, type: UserImageType) async throws {
        try await context.perform {
            let request = UserImage.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try self.context.fetch(request).first else {
                throw UserImageError.imageNotFound
            }

            // If promoting to primary, demote existing primary for the same owner
            if type == .primary, let ownerType = entity.ownerType, let ownerId = entity.ownerId {
                let primaryRequest = UserImage.fetchRequest()
                primaryRequest.predicate = NSPredicate(
                    format: "ownerType == %@ AND ownerId == %@ AND imageType == %@ AND id != %@",
                    ownerType, ownerId, UserImageType.primary.rawValue, id as CVarArg
                )

                let existingPrimary = try self.context.fetch(primaryRequest)
                for existingImage in existingPrimary {
                    existingImage.imageType = UserImageType.alternate.rawValue
                    existingImage.dateModified = Date()
                }
            }

            entity.imageType = type.rawValue
            entity.dateModified = Date()

            try self.context.save()
        }
    }

    // MARK: - Helper Methods

    /// Convert Core Data entity to domain model
    private func convertToModel(_ entity: UserImage) -> UserImageModel {
        return UserImageModel(
            id: entity.id ?? UUID(),
            ownerType: ImageOwnerType(rawValue: entity.ownerType ?? "standalone") ?? .standalone,
            ownerId: entity.ownerId,
            imageType: UserImageType(rawValue: entity.imageType ?? "primary") ?? .primary,
            fileExtension: entity.fileExtension ?? "jpg",
            dateCreated: entity.dateCreated ?? Date(),
            dateModified: entity.dateModified ?? Date()
        )
    }

    /// Resize image if it exceeds max dimension
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Check if resize is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        let newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
#endif
