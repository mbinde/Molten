//
//  GlassItemImageSelector.swift
//  Molten
//
//  Component for selecting a primary image for glass items from user-uploaded images
//  Unlike PrimaryImageSelector, this allows deselecting all images to fall back to manufacturer default
//

import SwiftUI

#if canImport(UIKit)
/// Reusable component for selecting a primary image for glass items
/// Shows a grid of user-uploaded images with the current primary highlighted
/// Allows tapping to select a different primary or deselect to use manufacturer default
struct GlassItemImageSelector: View {
    let glassItem: GlassItemModel
    let images: [UserImageModel]
    let loadedImages: [UUID: UIImage]
    let manufacturerImage: UIImage?  // Optional manufacturer default image to show as reference
    let currentPrimaryImageId: UUID?
    let onSelectPrimary: (UUID?) -> Void  // nil = deselect all (use manufacturer default)
    let onAddImage: () -> Void
    let onDeleteImage: (UUID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with instructions
            headerSection

            if images.isEmpty && manufacturerImage == nil {
                emptyState
            } else {
                imageGrid
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            if currentPrimaryImageId == nil {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Using manufacturer default image")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                Text("Tap to select primary • Tap selected to use default")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("No custom images yet")
                .font(DesignSystem.Typography.label)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Using manufacturer default")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Button {
                onAddImage()
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "plus")
                    Text("Add Custom Images")
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
            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                // Show manufacturer default image first (non-selectable reference)
                if let mfrImage = manufacturerImage {
                    manufacturerImageCell(image: mfrImage)
                }

                // Show user-uploaded images
                ForEach(images) { imageModel in
                    if let image = loadedImages[imageModel.id] {
                        userImageCell(for: imageModel, image: image)
                    }
                }
            }

            HStack {
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

    // MARK: - Manufacturer Image Cell

    private func manufacturerImageCell(image: UIImage) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .opacity(currentPrimaryImageId == nil ? 1.0 : 0.6)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                            .stroke(
                                currentPrimaryImageId == nil ? Color.green : Color.gray.opacity(0.3),
                                lineWidth: currentPrimaryImageId == nil ? 3 : 1
                            )
                    )

                if currentPrimaryImageId == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                        )
                        .padding(4)
                }
            }

            Text("Default")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - User Image Cell

    private func userImageCell(for imageModel: UserImageModel, image: UIImage) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Button {
                // Toggle: if already primary, deselect (nil). Otherwise select this one.
                if currentPrimaryImageId == imageModel.id {
                    onSelectPrimary(nil)  // Deselect - use manufacturer default
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
            .contextMenu {
                Button(role: .destructive) {
                    onDeleteImage(imageModel.id)
                } label: {
                    Label("Delete Image", systemImage: "trash")
                }
            }

            // Show "Primary" or "Alternate" label
            Text(imageModel.imageType == .primary ? "Primary" : "Alternate")
                .font(.caption2)
                .foregroundColor(imageModel.imageType == .primary ? .blue : .secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        let sampleGlassItem = GlassItemModel(
            stable_id: "bullseye-0001-0",
            natural_key: "bullseye-0001-0",
            name: "Bullseye Red Opal",
            sku: "0001",
            manufacturer: "bullseye",
            coe: 90,
            mfr_status: "available"
        )

        // Preview with images
        GlassItemImageSelector(
            glassItem: sampleGlassItem,
            images: [
                UserImageModel(
                    id: UUID(),
                    ownerType: .glassItem,
                    ownerId: "bullseye-0001-0",
                    imageType: .primary
                ),
                UserImageModel(
                    id: UUID(),
                    ownerType: .glassItem,
                    ownerId: "bullseye-0001-0",
                    imageType: .alternate
                )
            ],
            loadedImages: [:],
            manufacturerImage: nil,
            currentPrimaryImageId: nil,
            onSelectPrimary: { _ in },
            onAddImage: {},
            onDeleteImage: { _ in }
        )

        Divider()

        // Preview empty state
        GlassItemImageSelector(
            glassItem: sampleGlassItem,
            images: [],
            loadedImages: [:],
            manufacturerImage: nil,
            currentPrimaryImageId: nil,
            onSelectPrimary: { _ in },
            onAddImage: {},
            onDeleteImage: { _ in }
        )
    }
    .padding()
}
#endif
