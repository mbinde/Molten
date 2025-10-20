//
//  MockUserImageRepository.swift
//  Flameworker
//
//  Mock implementation of UserImageRepository for testing
//

import Foundation
#if canImport(UIKit)
import UIKit

actor MockUserImageRepository: UserImageRepository {
    private var images: [UUID: (model: UserImageModel, image: UIImage)] = [:]

    func saveImage(_ image: UIImage, for itemNaturalKey: String, type: UserImageType) async throws -> UserImageModel {
        // If there's already a primary image and we're adding another primary, remove the old one
        if type == .primary {
            let existing = images.values.filter { $0.model.itemNaturalKey == itemNaturalKey && $0.model.imageType == .primary }
            for item in existing {
                images.removeValue(forKey: item.model.id)
            }
        }

        let model = UserImageModel(
            itemNaturalKey: itemNaturalKey,
            imageType: type,
            fileExtension: "jpg"
        )

        images[model.id] = (model, image)
        return model
    }

    func loadImage(_ model: UserImageModel) async throws -> UIImage? {
        return images[model.id]?.image
    }

    func getImages(for itemNaturalKey: String) async throws -> [UserImageModel] {
        return images.values
            .filter { $0.model.itemNaturalKey == itemNaturalKey }
            .map { $0.model }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    func getPrimaryImage(for itemNaturalKey: String) async throws -> UserImageModel? {
        return images.values
            .first { $0.model.itemNaturalKey == itemNaturalKey && $0.model.imageType == .primary }?
            .model
    }

    func deleteImage(_ id: UUID) async throws {
        guard images[id] != nil else {
            throw UserImageError.imageNotFound
        }
        images.removeValue(forKey: id)
    }

    func deleteAllImages(for itemNaturalKey: String) async throws {
        let idsToDelete = images.values
            .filter { $0.model.itemNaturalKey == itemNaturalKey }
            .map { $0.model.id }

        for id in idsToDelete {
            images.removeValue(forKey: id)
        }
    }

    func updateImageType(_ id: UUID, type: UserImageType) async throws {
        guard let (model, image) = images[id] else {
            throw UserImageError.imageNotFound
        }

        // If promoting to primary, demote any existing primary
        if type == .primary {
            let existing = images.values.filter {
                $0.model.itemNaturalKey == model.itemNaturalKey && $0.model.imageType == .primary && $0.model.id != id
            }
            for item in existing {
                let demoted = UserImageModel(
                    id: item.model.id,
                    itemNaturalKey: item.model.itemNaturalKey,
                    imageType: .alternate,
                    fileExtension: item.model.fileExtension,
                    dateAdded: item.model.dateAdded,
                    dateModified: Date()
                )
                images[item.model.id] = (demoted, item.image)
            }
        }

        let updated = UserImageModel(
            id: model.id,
            itemNaturalKey: model.itemNaturalKey,
            imageType: type,
            fileExtension: model.fileExtension,
            dateAdded: model.dateAdded,
            dateModified: Date()
        )

        images[id] = (updated, image)
    }

    // Test helpers
    func reset() {
        images.removeAll()
    }

    func getImageCount() async -> Int {
        return images.count
    }
}
#endif
