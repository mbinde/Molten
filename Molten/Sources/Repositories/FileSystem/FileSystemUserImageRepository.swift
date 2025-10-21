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

class FileSystemUserImageRepository: UserImageRepository {
    private let fileManager = FileManager.default
    private let userDefaults: UserDefaults
    private let userDefaultsKey = "flameworker.userImages.metadata"

    /// Initialize with custom UserDefaults (useful for testing)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - New Generic Methods (required by protocol)

    func saveImage(_ image: UIImage, ownerType: ImageOwnerType, ownerId: String?, type: UserImageType) async throws -> UserImageModel {
        // For backward compatibility with file system storage, convert to legacy format
        // Note: This implementation only supports glassItem owner type properly
        guard ownerType == .glassItem, let ownerId = ownerId else {
            throw UserImageError.failedToSaveImage("FileSystemUserImageRepository only supports glassItem owner type")
        }

        var metadata = loadMetadata()

        // If adding a primary image, demote any existing primary to alternate
        if type == .primary {
            for (id, model) in metadata where model.ownerType == ownerType && model.ownerId == ownerId && model.imageType == .primary {
                var demoted = model
                demoted = UserImageModel(
                    id: demoted.id,
                    ownerType: demoted.ownerType,
                    ownerId: demoted.ownerId,
                    imageType: .alternate,
                    fileExtension: demoted.fileExtension,
                    dateCreated: demoted.dateCreated,
                    dateModified: Date()
                )
                metadata[id] = demoted
            }
        }

        // Create model with new structure
        let model = UserImageModel(
            ownerType: ownerType,
            ownerId: ownerId,
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

    func getImages(ownerType: ImageOwnerType, ownerId: String) async throws -> [UserImageModel] {
        let metadata = loadMetadata()
        return metadata.values
            .filter { $0.ownerType == ownerType && $0.ownerId == ownerId }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    func getPrimaryImage(ownerType: ImageOwnerType, ownerId: String) async throws -> UserImageModel? {
        let metadata = loadMetadata()
        return metadata.values.first {
            $0.ownerType == ownerType && $0.ownerId == ownerId && $0.imageType == .primary
        }
    }

    func getStandaloneImages() async throws -> [UserImageModel] {
        let metadata = loadMetadata()
        return metadata.values
            .filter { $0.ownerType == .standalone }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    func deleteAllImages(ownerType: ImageOwnerType, ownerId: String) async throws {
        var metadata = loadMetadata()

        let idsToDelete = metadata.values
            .filter { $0.ownerType == ownerType && $0.ownerId == ownerId }
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

    func updateImageType(_ id: UUID, type: UserImageType) async throws {
        var metadata = loadMetadata()

        guard let model = metadata[id] else {
            throw UserImageError.imageNotFound
        }

        // If promoting to primary, demote any existing primary
        if type == .primary, let ownerId = model.ownerId {
            for (otherId, otherModel) in metadata where otherModel.ownerType == model.ownerType && otherModel.ownerId == ownerId && otherModel.imageType == .primary && otherId != id {
                let demoted = UserImageModel(
                    id: otherModel.id,
                    ownerType: otherModel.ownerType,
                    ownerId: otherModel.ownerId,
                    imageType: .alternate,
                    fileExtension: otherModel.fileExtension,
                    dateCreated: otherModel.dateCreated,
                    dateModified: Date()
                )
                metadata[otherId] = demoted
            }
        }

        // Update this image's type
        let updated = UserImageModel(
            id: model.id,
            ownerType: model.ownerType,
            ownerId: model.ownerId,
            imageType: type,
            fileExtension: model.fileExtension,
            dateCreated: model.dateCreated,
            dateModified: Date()
        )

        metadata[id] = updated
        try saveMetadata(metadata)
    }
}

// MARK: - UserImageModel Codable Conformance (for FileSystem storage)

extension UserImageModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, ownerType, ownerId, imageType, fileExtension, dateCreated, dateModified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.ownerType = try container.decode(ImageOwnerType.self, forKey: .ownerType)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId)
        self.imageType = try container.decode(UserImageType.self, forKey: .imageType)
        self.fileExtension = try container.decode(String.self, forKey: .fileExtension)
        self.dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        self.dateModified = try container.decode(Date.self, forKey: .dateModified)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ownerType, forKey: .ownerType)
        try container.encodeIfPresent(ownerId, forKey: .ownerId)
        try container.encode(imageType, forKey: .imageType)
        try container.encode(fileExtension, forKey: .fileExtension)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encode(dateModified, forKey: .dateModified)
    }
}
#endif
