//
//  MockUserImageRepository.swift
//  Molten
//
//  Mock implementation of UserImageRepository for testing
//

import Foundation
#if canImport(UIKit)
import UIKit

class MockUserImageRepository: @unchecked Sendable, UserImageRepository {
    nonisolated(unsafe) private var images: [UUID: (model: UserImageModel, image: UIImage)] = [:]

    nonisolated init() {}

    // MARK: - New Generic Methods

    func saveImage(_ image: UIImage, ownerType: ImageOwnerType, ownerId: String?, type: UserImageType) async throws -> UserImageModel {
        // If there's already a primary image for this owner, demote it to alternate
        if type == .primary, let ownerId = ownerId {
            let existing = images.values.filter {
                $0.model.ownerType == ownerType &&
                $0.model.ownerId == ownerId &&
                $0.model.imageType == .primary
            }
            for item in existing {
                // Demote to alternate instead of deleting
                let demoted = UserImageModel(
                    id: item.model.id,
                    ownerType: item.model.ownerType,
                    ownerId: item.model.ownerId,
                    imageType: .alternate,
                    fileExtension: item.model.fileExtension,
                    dateCreated: item.model.dateCreated,
                    dateModified: Date()
                )
                images[item.model.id] = (demoted, item.image)
            }
        }

        let model = UserImageModel(
            ownerType: ownerType,
            ownerId: ownerId,
            imageType: type,
            fileExtension: "jpg"
        )

        images[model.id] = (model, image)
        return model
    }

    func getImages(ownerType: ImageOwnerType, ownerId: String) async throws -> [UserImageModel] {
        return images.values
            .filter { $0.model.ownerType == ownerType && $0.model.ownerId == ownerId }
            .map { $0.model }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    func getPrimaryImage(ownerType: ImageOwnerType, ownerId: String) async throws -> UserImageModel? {
        return images.values
            .first {
                $0.model.ownerType == ownerType &&
                $0.model.ownerId == ownerId &&
                $0.model.imageType == .primary
            }?
            .model
    }

    func getStandaloneImages() async throws -> [UserImageModel] {
        return images.values
            .filter { $0.model.ownerType == .standalone }
            .map { $0.model }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    func deleteAllImages(ownerType: ImageOwnerType, ownerId: String) async throws {
        let idsToDelete = images.values
            .filter { $0.model.ownerType == ownerType && $0.model.ownerId == ownerId }
            .map { $0.model.id }

        for id in idsToDelete {
            images.removeValue(forKey: id)
        }
    }

    // MARK: - Common Methods

    func loadImage(_ model: UserImageModel) async throws -> UIImage? {
        return images[model.id]?.image
    }

    func deleteImage(_ id: UUID) async throws {
        guard images[id] != nil else {
            throw UserImageError.imageNotFound
        }
        images.removeValue(forKey: id)
    }

    func updateImageType(_ id: UUID, type: UserImageType) async throws {
        guard let (model, image) = images[id] else {
            throw UserImageError.imageNotFound
        }

        // If promoting to primary, demote any existing primary for the same owner
        if type == .primary, let ownerId = model.ownerId {
            let existing = images.values.filter {
                $0.model.ownerType == model.ownerType &&
                $0.model.ownerId == ownerId &&
                $0.model.imageType == .primary &&
                $0.model.id != id
            }
            for item in existing {
                let demoted = UserImageModel(
                    id: item.model.id,
                    ownerType: item.model.ownerType,
                    ownerId: item.model.ownerId,
                    imageType: .alternate,
                    fileExtension: item.model.fileExtension,
                    dateCreated: item.model.dateCreated,
                    dateModified: Date()
                )
                images[item.model.id] = (demoted, item.image)
            }
        }

        let updated = UserImageModel(
            id: model.id,
            ownerType: model.ownerType,
            ownerId: model.ownerId,
            imageType: type,
            fileExtension: model.fileExtension,
            dateCreated: model.dateCreated,
            dateModified: Date()
        )

        images[id] = (updated, image)
    }

    // MARK: - Test Helpers

    nonisolated func reset() {
        images.removeAll()
    }

    nonisolated func getImageCount() async -> Int {
        return images.count
    }
}
#endif
