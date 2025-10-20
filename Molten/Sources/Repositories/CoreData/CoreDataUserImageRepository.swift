//
//  CoreDataUserImageRepository.swift
//  Flameworker
//
//  Core Data implementation for user-uploaded product images
//

import Foundation
import CoreData
#if canImport(UIKit)
import UIKit

/// Core Data implementation of UserImageRepository
class CoreDataUserImageRepository: UserImageRepository {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    // MARK: - Storage Directory

    private func getImagesDirectory() throws -> URL {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw UserImageError.storageDirectoryUnavailable
        }

        let imagesPath = documentsPath.appendingPathComponent("UserImages", isDirectory: true)

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesPath.path) {
            try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
        }

        return imagesPath
    }

    // MARK: - Repository Methods

    func saveImage(_ image: UIImage, for itemNaturalKey: String, type: UserImageType) async throws -> UserImageModel {
        let imageId = UUID()
        let fileExtension = "jpg"

        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UserImageError.invalidImageData
        }

        // Get storage directory and save file
        let imagesDirectory = try getImagesDirectory()
        let fileName = "\(imageId.uuidString).\(fileExtension)"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        do {
            try imageData.write(to: fileURL)
        } catch {
            throw UserImageError.failedToSaveImage(error.localizedDescription)
        }

        // Create Core Data record
        return try await context.perform {
            // If this is a primary image, demote any existing primary image
            if type == .primary {
                let fetchRequest = UserImage.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "item_natural_key == %@ AND image_type == %@",
                    itemNaturalKey, UserImageType.primary.rawValue
                )

                let existingPrimary = try self.context.fetch(fetchRequest)
                for image in existingPrimary {
                    image.image_type = UserImageType.alternate.rawValue
                }
            }

            let entity = UserImage(context: self.context)
            entity.id = imageId
            entity.item_natural_key = itemNaturalKey
            entity.image_type = type.rawValue
            entity.file_extension = fileExtension
            entity.date_added = Date()
            entity.date_modified = Date()

            try self.context.save()

            return UserImageModel(
                id: imageId,
                itemNaturalKey: itemNaturalKey,
                imageType: type,
                fileExtension: fileExtension,
                dateAdded: entity.date_added ?? Date(),
                dateModified: entity.date_modified ?? Date()
            )
        }
    }

    func loadImage(_ model: UserImageModel) async throws -> UIImage? {
        let imagesDirectory = try getImagesDirectory()
        let fileURL = imagesDirectory.appendingPathComponent(model.fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        guard let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            throw UserImageError.failedToLoadImage("Could not decode image data")
        }

        return image
    }

    func getImages(for itemNaturalKey: String) async throws -> [UserImageModel] {
        try await context.perform {
            let fetchRequest = UserImage.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "item_natural_key == %@", itemNaturalKey)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "image_type", ascending: true), // Primary first
                NSSortDescriptor(key: "date_added", ascending: false)
            ]

            let entities = try self.context.fetch(fetchRequest)

            return entities.compactMap { entity in
                guard let id = entity.id,
                      let itemNaturalKey = entity.item_natural_key,
                      let typeString = entity.image_type,
                      let type = UserImageType(rawValue: typeString),
                      let fileExtension = entity.file_extension else {
                    return nil
                }

                return UserImageModel(
                    id: id,
                    itemNaturalKey: itemNaturalKey,
                    imageType: type,
                    fileExtension: fileExtension,
                    dateAdded: entity.date_added ?? Date(),
                    dateModified: entity.date_modified ?? Date()
                )
            }
        }
    }

    func getPrimaryImage(for itemNaturalKey: String) async throws -> UserImageModel? {
        try await context.perform {
            let fetchRequest = UserImage.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "item_natural_key == %@ AND image_type == %@",
                itemNaturalKey, UserImageType.primary.rawValue
            )
            fetchRequest.fetchLimit = 1

            guard let entity = try self.context.fetch(fetchRequest).first,
                  let id = entity.id,
                  let itemNaturalKey = entity.item_natural_key,
                  let typeString = entity.image_type,
                  let type = UserImageType(rawValue: typeString),
                  let fileExtension = entity.file_extension else {
                return nil
            }

            return UserImageModel(
                id: id,
                itemNaturalKey: itemNaturalKey,
                imageType: type,
                fileExtension: fileExtension,
                dateAdded: entity.date_added ?? Date(),
                dateModified: entity.date_modified ?? Date()
            )
        }
    }

    func deleteImage(_ id: UUID) async throws {
        try await context.perform {
            let fetchRequest = UserImage.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first else {
                throw UserImageError.imageNotFound
            }

            // Delete file from disk
            if let itemNaturalKey = entity.item_natural_key,
               let typeString = entity.image_type,
               let type = UserImageType(rawValue: typeString),
               let fileExtension = entity.file_extension {
                let model = UserImageModel(
                    id: id,
                    itemNaturalKey: itemNaturalKey,
                    imageType: type,
                    fileExtension: fileExtension
                )

                let imagesDirectory = try self.getImagesDirectory()
                let fileURL = imagesDirectory.appendingPathComponent(model.fileName)

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
            }

            // Delete Core Data record
            self.context.delete(entity)
            try self.context.save()
        }
    }

    func deleteAllImages(for itemNaturalKey: String) async throws {
        let images = try await getImages(for: itemNaturalKey)

        for image in images {
            try await deleteImage(image.id)
        }
    }

    func updateImageType(_ id: UUID, type: UserImageType) async throws {
        try await context.perform {
            let fetchRequest = UserImage.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let entity = try self.context.fetch(fetchRequest).first,
                  let itemNaturalKey = entity.item_natural_key else {
                throw UserImageError.imageNotFound
            }

            // If promoting to primary, demote existing primary
            if type == .primary {
                let primaryFetchRequest = UserImage.fetchRequest()
                primaryFetchRequest.predicate = NSPredicate(
                    format: "item_natural_key == %@ AND image_type == %@",
                    itemNaturalKey, UserImageType.primary.rawValue
                )

                let existingPrimary = try self.context.fetch(primaryFetchRequest)
                for image in existingPrimary where image.id != id {
                    image.image_type = UserImageType.alternate.rawValue
                }
            }

            entity.image_type = type.rawValue
            entity.date_modified = Date()

            try self.context.save()
        }
    }
}
#endif
