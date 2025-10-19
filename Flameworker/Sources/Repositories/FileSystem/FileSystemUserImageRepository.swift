//
//  FileSystemUserImageRepository.swift
//  Flameworker
//
//  File system implementation of UserImageRepository
//  Stores images in Application Support directory and metadata in UserDefaults
//

import Foundation
#if canImport(UIKit)
import UIKit

actor FileSystemUserImageRepository: UserImageRepository {
    private let fileManager = FileManager.default
    private let userDefaults: UserDefaults
    private let userDefaultsKey = "flameworker.userImages.metadata"

    /// Initialize with custom UserDefaults (useful for testing)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Get the directory where user images are stored
    private var storageDirectory: URL {
        get throws {
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw UserImageError.storageDirectoryUnavailable
            }

            let imagesDir = appSupport.appendingPathComponent("UserImages", isDirectory: true)

            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: imagesDir.path) {
                try fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
            }

            return imagesDir
        }
    }

    /// Load metadata from UserDefaults
    private func loadMetadata() -> [UUID: UserImageModel] {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([UUID: UserImageModel].self, from: data) else {
            return [:]
        }
        return decoded
    }

    /// Save metadata to UserDefaults
    private func saveMetadata(_ metadata: [UUID: UserImageModel]) throws {
        let encoded = try JSONEncoder().encode(metadata)
        userDefaults.set(encoded, forKey: userDefaultsKey)
        userDefaults.synchronize()  // Force immediate write to disk
    }

    func saveImage(_ image: UIImage, for itemNaturalKey: String, type: UserImageType) async throws -> UserImageModel {
        var metadata = loadMetadata()

        // If adding a primary image, demote any existing primary to alternate
        if type == .primary {
            for (id, model) in metadata where model.itemNaturalKey == itemNaturalKey && model.imageType == .primary {
                var demoted = model
                demoted = UserImageModel(
                    id: demoted.id,
                    itemNaturalKey: demoted.itemNaturalKey,
                    imageType: .alternate,
                    fileExtension: demoted.fileExtension,
                    dateAdded: demoted.dateAdded,
                    dateModified: Date()
                )
                metadata[id] = demoted
            }
        }

        // Create model
        let model = UserImageModel(
            itemNaturalKey: itemNaturalKey,
            imageType: type,
            fileExtension: "jpg"
        )

        // Save image to disk
        let imageURL = try storageDirectory.appendingPathComponent(model.fileName)

        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw UserImageError.invalidImageData
        }

        do {
            try imageData.write(to: imageURL)
        } catch {
            throw UserImageError.failedToSaveImage(error.localizedDescription)
        }

        // Save metadata
        metadata[model.id] = model
        try saveMetadata(metadata)

        return model
    }

    func loadImage(_ model: UserImageModel) async throws -> UIImage? {
        let imageURL = try storageDirectory.appendingPathComponent(model.fileName)

        guard fileManager.fileExists(atPath: imageURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: imageURL)
            return UIImage(data: data)
        } catch {
            throw UserImageError.failedToLoadImage(error.localizedDescription)
        }
    }

    func getImages(for itemNaturalKey: String) async throws -> [UserImageModel] {
        let metadata = loadMetadata()
        return metadata.values
            .filter { $0.itemNaturalKey == itemNaturalKey }
            .sorted { $0.dateAdded > $1.dateAdded }
    }

    func getPrimaryImage(for itemNaturalKey: String) async throws -> UserImageModel? {
        let metadata = loadMetadata()
        return metadata.values.first { $0.itemNaturalKey == itemNaturalKey && $0.imageType == .primary }
    }

    func deleteImage(_ id: UUID) async throws {
        var metadata = loadMetadata()

        guard let model = metadata[id] else {
            throw UserImageError.imageNotFound
        }

        // Delete file from disk
        let imageURL = try storageDirectory.appendingPathComponent(model.fileName)
        if fileManager.fileExists(atPath: imageURL.path) {
            do {
                try fileManager.removeItem(at: imageURL)
            } catch {
                throw UserImageError.failedToDeleteImage(error.localizedDescription)
            }
        }

        // Remove from metadata
        metadata.removeValue(forKey: id)
        try saveMetadata(metadata)
    }

    func deleteAllImages(for itemNaturalKey: String) async throws {
        var metadata = loadMetadata()

        let idsToDelete = metadata.values
            .filter { $0.itemNaturalKey == itemNaturalKey }
            .map { $0.id }

        for id in idsToDelete {
            if let model = metadata[id] {
                // Delete file
                let imageURL = try storageDirectory.appendingPathComponent(model.fileName)
                if fileManager.fileExists(atPath: imageURL.path) {
                    try? fileManager.removeItem(at: imageURL)
                }
                // Remove from metadata
                metadata.removeValue(forKey: id)
            }
        }

        try saveMetadata(metadata)
    }

    func updateImageType(_ id: UUID, type: UserImageType) async throws {
        var metadata = loadMetadata()

        guard var model = metadata[id] else {
            throw UserImageError.imageNotFound
        }

        // If promoting to primary, demote any existing primary
        if type == .primary {
            for (otherId, otherModel) in metadata where otherModel.itemNaturalKey == model.itemNaturalKey && otherModel.imageType == .primary && otherId != id {
                var demoted = otherModel
                demoted = UserImageModel(
                    id: demoted.id,
                    itemNaturalKey: demoted.itemNaturalKey,
                    imageType: .alternate,
                    fileExtension: demoted.fileExtension,
                    dateAdded: demoted.dateAdded,
                    dateModified: Date()
                )
                metadata[otherId] = demoted
            }
        }

        // Update this image's type
        model = UserImageModel(
            id: model.id,
            itemNaturalKey: model.itemNaturalKey,
            imageType: type,
            fileExtension: model.fileExtension,
            dateAdded: model.dateAdded,
            dateModified: Date()
        )

        metadata[id] = model
        try saveMetadata(metadata)
    }
}

// MARK: - UserImageModel Codable Conformance

extension UserImageModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, itemNaturalKey, imageType, fileExtension, dateAdded, dateModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        itemNaturalKey = try container.decode(String.self, forKey: .itemNaturalKey)
        imageType = try container.decode(UserImageType.self, forKey: .imageType)
        fileExtension = try container.decode(String.self, forKey: .fileExtension)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        dateModified = try container.decode(Date.self, forKey: .dateModified)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(itemNaturalKey, forKey: .itemNaturalKey)
        try container.encode(imageType, forKey: .imageType)
        try container.encode(fileExtension, forKey: .fileExtension)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(dateModified, forKey: .dateModified)
    }
}
#endif
