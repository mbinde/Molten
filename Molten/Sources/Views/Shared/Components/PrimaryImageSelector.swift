//
//  PrimaryImageSelector.swift
//  Molten
//
//  Created by Assistant on 10/22/25.
//

import SwiftUI

#if canImport(UIKit)
/// Reusable component for selecting a primary/hero image from uploaded images
/// Shows a grid of images with the current primary image highlighted
/// Allows tapping to select a different image as primary
struct PrimaryImageSelector: View {
    let images: [ProjectImageModel]
    let loadedImages: [UUID: UIImage]
    let currentPrimaryImageId: UUID?
    let onSelectPrimary: (UUID?) -> Void
    let onAddImage: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if images.isEmpty {
                emptyState
            } else {
                imageGrid
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("No images yet")
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Button {
                onAddImage()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus")
                    Text("Add Images")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Padding.standard)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.medium)
    }

    // MARK: - Image Grid

    private var imageGrid: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Select Primary Image")
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                ForEach(images) { imageModel in
                    if let image = loadedImages[imageModel.id] {
                        imageCell(for: imageModel, image: image)
                    }
                }
            }

            HStack {
                if currentPrimaryImageId != nil {
                    Button {
                        onSelectPrimary(nil)
                    } label: {
                        Label("Clear Primary", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button {
                    onAddImage()
                } label: {
                    Label("Add More Images", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Image Cell

    private func imageCell(for imageModel: ProjectImageModel, image: UIImage) -> some View {
        Button {
            if currentPrimaryImageId == imageModel.id {
                onSelectPrimary(nil)  // Deselect
            } else {
                onSelectPrimary(imageModel.id)  // Select as primary
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(
                                currentPrimaryImageId == imageModel.id ? Color.blue : Color.clear,
                                lineWidth: currentPrimaryImageId == imageModel.id ? 3 : 0
                            )
                    )

                if currentPrimaryImageId == imageModel.id {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                        )
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        // Preview with images
        PrimaryImageSelector(
            images: [
                ProjectImageModel(
                    id: UUID(),
                    projectId: UUID(),
                    projectCategory: .log,
                    fileExtension: "jpg"
                )
            ],
            loadedImages: [:],
            currentPrimaryImageId: nil,
            onSelectPrimary: { _ in },
            onAddImage: {}
        )

        Divider()

        // Preview empty state
        PrimaryImageSelector(
            images: [],
            loadedImages: [:],
            currentPrimaryImageId: nil,
            onSelectPrimary: { _ in },
            onAddImage: {}
        )
    }
    .padding()
}
#endif
