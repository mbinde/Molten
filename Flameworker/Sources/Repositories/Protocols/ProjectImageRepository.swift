//
//  ProjectImageRepository.swift
//  Flameworker
//
//  Protocol for ProjectImage data persistence operations (images for plans and logs)
//

import Foundation
import UIKit

protocol ProjectImageRepository {
    // MARK: - Image Operations

    func saveImage(_ image: UIImage, for projectId: UUID, type: ProjectType) async throws -> ProjectImageModel
    func loadImage(_ model: ProjectImageModel) async throws -> UIImage?
    func getImages(for projectId: UUID, type: ProjectType) async throws -> [ProjectImageModel]
    func getHeroImage(for projectId: UUID, type: ProjectType) async throws -> ProjectImageModel?
    func deleteImage(id: UUID) async throws
    func setAsHero(id: UUID, for projectId: UUID, type: ProjectType) async throws
    func reorderImages(projectId: UUID, type: ProjectType, imageIds: [UUID]) async throws
}
