//
//  MockUserImageRepository.swift
//  RepositoryTests
//
//  In-memory mock implementation of UserImageRepository for testing
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
@testable import Molten

#if canImport(UIKit)
/// Mock implementation of UserImageRepository for testing
/// Stores images in memory using dictionaries
final class MockUserImageRepository: UserImageRepository {

    // MARK: - Storage

    nonisolated(unsafe) private var images: [UUID: UserImageModel] = [:]
    nonisolated(unsafe) private var imageData: [UUID: UIImage] = [:]

    // MARK: - New Generic Methods

    func saveImage(_ image: UIImage, ownerType: ImageOwnerType, ownerId: String?, type: UserImageType) async throws -> UserImageModel {
        // If saving a primary image, demote existing primary to alternate
        if type == .primary, let ownerId = ownerId {
            let existing = images.values.filter {
                $0.ownerType == ownerType &&
                $0.ownerId == ownerId &&
                $0.imageType == .primary
            }
            for existingPrimary in existing {
                try await updateImageType(existingPrimary.id, type: .alternate)
            }
        }

        let model = UserImageModel(
            id: UUID(),
            ownerType: ownerType,
            ownerId: ownerId,
            imageType: type,
            fileExtension: "jpg",
            dateCreated: Date(),
            dateModified: Date(),
            ocrText: nil
        )
        images[model.id] = model
        imageData[model.id] = image
        return model
    }

    func getImages(ownerType: ImageOwnerType, ownerId: String) async throws -> [UserImageModel] {
        return images.values
            .filter { $0.ownerType == ownerType && $0.ownerId == ownerId }
            .sorted { $0.dateCreated > $1.dateCreated }  // Sort by date created descending (newest first)
    }

    func getPrimaryImage(ownerType: ImageOwnerType, ownerId: String) async throws -> UserImageModel? {
        return images.values.first {
            $0.ownerType == ownerType &&
            $0.ownerId == ownerId &&
            $0.imageType == .primary
        }
    }

    func getStandaloneImages() async throws -> [UserImageModel] {
        return images.values
            .filter { $0.ownerType == .standalone }
            .sorted { $0.dateCreated > $1.dateCreated }  // Sort by date created descending (newest first)
    }

    func deleteAllImages(ownerType: ImageOwnerType, ownerId: String) async throws {
        let imagesToDelete = images.values.filter {
            $0.ownerType == ownerType && $0.ownerId == ownerId
        }
        for image in imagesToDelete {
            images.removeValue(forKey: image.id)
            imageData.removeValue(forKey: image.id)
        }
    }

    // MARK: - Common Methods

    func loadImage(_ model: UserImageModel) async throws -> UIImage? {
        return imageData[model.id]
    }

    func deleteImage(_ id: UUID) async throws {
        guard images[id] != nil else {
            throw UserImageError.imageNotFound
        }
        images.removeValue(forKey: id)
        imageData.removeValue(forKey: id)
    }

    func updateImageType(_ id: UUID, type: UserImageType) async throws {
        guard var model = images[id] else {
            throw UserImageError.imageNotFound
        }

        // If promoting to primary, demote existing primary to alternate
        if type == .primary, let ownerId = model.ownerId {
            let existing = images.values.filter {
                $0.ownerType == model.ownerType &&
                $0.ownerId == ownerId &&
                $0.imageType == .primary &&
                $0.id != id  // Don't demote ourselves
            }
            for existingPrimary in existing {
                let demoted = UserImageModel(
                    id: existingPrimary.id,
                    ownerType: existingPrimary.ownerType,
                    ownerId: existingPrimary.ownerId,
                    imageType: .alternate,
                    fileExtension: existingPrimary.fileExtension,
                    dateCreated: existingPrimary.dateCreated,
                    dateModified: Date(),
                    ocrText: existingPrimary.ocrText
                )
                images[existingPrimary.id] = demoted
            }
        }

        // Create updated model with new type
        let updated = UserImageModel(
            id: model.id,
            ownerType: model.ownerType,
            ownerId: model.ownerId,
            imageType: type,
            fileExtension: model.fileExtension,
            dateCreated: model.dateCreated,
            dateModified: Date(),
            ocrText: model.ocrText
        )
        images[id] = updated
    }

    // MARK: - OCR Search

    func getOCRText(ownerType: ImageOwnerType, ownerId: String) async throws -> String {
        let ownerImages = try await getImages(ownerType: ownerType, ownerId: ownerId)
        let ocrTexts = ownerImages.compactMap { $0.ocrText }
        return ocrTexts.joined(separator: " ")
    }

    // MARK: - Test Helpers

    func reset() {
        images.removeAll()
        imageData.removeAll()
    }

    func getImageCount() -> Int {
        return images.count
    }
}
#endif
