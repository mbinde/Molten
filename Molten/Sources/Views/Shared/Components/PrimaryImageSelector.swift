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
/// Tap to view full screen, long press to set as primary
struct PrimaryImageSelector: View {
    let images: [ProjectImageModel]
    let loadedImages: [UUID: UIImage]
    let currentPrimaryImageId: UUID?
    let onSelectPrimary: (UUID?) -> Void
    let onAddImage: () -> Void

    @State private var selectedImageForViewing: UIImage?

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
        .fullScreenCover(item: Binding(
            get: { selectedImageForViewing.map { IdentifiableImage(image: $0) } },
            set: { selectedImageForViewing = $0?.image }
        )) { identifiableImage in
            ImageViewer(image: identifiableImage.image)
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
            Text("Tap to view • Long press to set as primary")
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
        .onTapGesture {
            // Tap to view full screen
            selectedImageForViewing = image
        }
        .onLongPressGesture {
            // Long press to set as primary
            onSelectPrimary(imageModel.id)
        }
    }
}

// MARK: - Supporting Types

/// Wrapper to make UIImage identifiable for sheet presentation
private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Full-screen image viewer with zoom and dismiss gestures
private struct ImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            // Reset to 1.0 if zoomed out too far
                            if scale < 1.0 {
                                withAnimation {
                                    scale = 1.0
                                    lastScale = 1.0
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    // Double tap to reset zoom
                    withAnimation {
                        scale = 1.0
                        lastScale = 1.0
                    }
                }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
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
