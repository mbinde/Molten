//
//  ProjectThumbnail.swift
//  Molten
//
//  Displays thumbnail image for a project or logbook entry
//  Shows hero/primary image if available, otherwise shows placeholder
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// Thumbnail component for displaying project/logbook hero images in list rows
struct ProjectThumbnail: View {
    let heroImageId: UUID?
    let projectId: UUID
    let projectCategory: ProjectCategory

    @State private var thumbnailImage: UIImage?
    @State private var isLoading = false

    private let userImageRepository: UserImageRepository

    private let size: CGFloat

    init(
        heroImageId: UUID?,
        projectId: UUID,
        projectCategory: ProjectCategory,
        size: CGFloat = 60,
        userImageRepository: UserImageRepository? = nil
    ) {
        self.heroImageId = heroImageId
        self.projectId = projectId
        self.projectCategory = projectCategory
        self.size = size
        self.userImageRepository = userImageRepository ?? RepositoryFactory.createUserImageRepository()
    }

    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(DesignSystem.CornerRadius.medium)
            } else if isLoading {
                ZStack {
                    Color.gray.opacity(0.2)
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .frame(width: size, height: size)
                .cornerRadius(DesignSystem.CornerRadius.medium)
            } else {
                placeholderView
            }
        }
        .task {
            await loadThumbnail()
        }
    }

    // MARK: - Placeholder

    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.15)

            Image(systemName: projectCategory == .plan ? "doc.text" : "book.pages")
                .font(.system(size: size * 0.4))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(width: size, height: size)
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Image Loading

    private func loadThumbnail() async {
        guard let heroImageId = heroImageId else {
            return
        }

        isLoading = true

        do {
            // Load the image from UserImageRepository
            let ownerType: ImageOwnerType = projectCategory == .plan ? .projectPlan : .projectLog

            // Get all images for this owner
            let images = try await userImageRepository.getImages(
                ownerType: ownerType,
                ownerId: projectId.uuidString
            )

            // Find the image with matching heroImageId
            if let imageModel = images.first(where: { $0.id == heroImageId }),
               let image = try await userImageRepository.loadImage(imageModel) {
                await MainActor.run {
                    self.thumbnailImage = image
                }
            }
        } catch {
            print("Failed to load thumbnail for \(projectCategory.rawValue) \(projectId): \(error)")
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview("With Image") {
    HStack(spacing: DesignSystem.Spacing.md) {
        ProjectThumbnail(
            heroImageId: UUID(),
            projectId: UUID(),
            projectCategory: .plan,
            size: 60
        )

        VStack(alignment: .leading) {
            Text("Project Title")
                .font(.headline)
            Text("Sample description")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }

        Spacer()
    }
    .padding()
}

#Preview("Placeholder") {
    HStack(spacing: DesignSystem.Spacing.md) {
        ProjectThumbnail(
            heroImageId: nil,
            projectId: UUID(),
            projectCategory: .log,
            size: 60
        )

        VStack(alignment: .leading) {
            Text("Logbook Entry")
                .font(.headline)
            Text("No image")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }

        Spacer()
    }
    .padding()
}
#endif
