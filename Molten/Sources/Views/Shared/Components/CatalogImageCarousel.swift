//
//  CatalogImageCarousel.swift
//  Molten
//
//  Image carousel component for displaying multiple catalog images
//  with paging dots and fullscreen gallery support.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// Carousel component for displaying multiple catalog images
/// Shows a paged TabView with indicator dots, tap to open fullscreen gallery
struct CatalogImageCarousel: View {
    let stableId: String
    let manufacturer: String?
    let imagePaths: [String]?
    let imageThumbPaths: [String]?
    let imageUrls: [String]?
    let dominantColors: [String]?
    let maxSize: CGFloat

    @State private var selectedIndex: Int = 0
    @State private var loadedImages: [UIImage?] = []
    @State private var isLoading: Bool = true
    @State private var showFullscreenGallery: Bool = false

    /// Number of images available (from paths or URLs)
    private var imageCount: Int {
        if let paths = imagePaths, !paths.isEmpty {
            return paths.count
        } else if let urls = imageUrls, !urls.isEmpty {
            return urls.count
        }
        return 1  // Fallback to single image mode
    }

    /// Whether we have multiple images to show
    private var hasMultipleImages: Bool {
        imageCount > 1
    }

    init(
        stableId: String,
        manufacturer: String? = nil,
        imagePaths: [String]? = nil,
        imageThumbPaths: [String]? = nil,
        imageUrls: [String]? = nil,
        dominantColors: [String]? = nil,
        maxSize: CGFloat = 200
    ) {
        self.stableId = stableId
        self.manufacturer = manufacturer
        self.imagePaths = imagePaths
        self.imageThumbPaths = imageThumbPaths
        self.imageUrls = imageUrls
        self.dominantColors = dominantColors
        self.maxSize = maxSize
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if hasMultipleImages {
                // Multiple images - show carousel
                TabView(selection: $selectedIndex) {
                    ForEach(0..<imageCount, id: \.self) { index in
                        carouselImage(at: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: maxSize, height: maxSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .onTapGesture {
                    showFullscreenGallery = true
                }

                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<imageCount, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? DesignSystem.Colors.accentPrimary : Color.gray.opacity(0.4))
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                    }
                }
            } else {
                // Single image - use standard ProductImageDetail
                ProductImageDetail(
                    itemCode: stableId,
                    manufacturer: manufacturer,
                    stableId: stableId,
                    imagePath: imagePaths?.first,
                    imageThumbPath: imageThumbPaths?.first,
                    dominantColors: dominantColors,
                    maxSize: maxSize,
                    allowImageUpload: false,
                    allowFullScreen: true
                )
            }
        }
        .task {
            await loadAllImages()
        }
        .fullScreenCover(isPresented: $showFullscreenGallery) {
            FullscreenImageGallery(
                images: loadedImages.compactMap { $0 },
                startIndex: selectedIndex
            )
        }
    }

    // MARK: - Image Loading

    @ViewBuilder
    private func carouselImage(at index: Int) -> some View {
        if index < loadedImages.count, let image = loadedImages[index] {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: maxSize, maxHeight: maxSize)
        } else if isLoading {
            ProgressView()
                .frame(width: maxSize, height: maxSize)
        } else {
            // Fallback placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: maxSize, height: maxSize)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .font(.system(size: maxSize * 0.2))
                }
        }
    }

    private func loadAllImages() async {
        isLoading = true

        var images: [UIImage?] = []
        let useThumbnail = !UserSettings.shared.downloadFullSizeImages

        for i in 0..<imageCount {
            let imagePath = imagePaths?[safe: i]
            let thumbPath = imageThumbPaths?[safe: i]

            // Try to load the image
            if let image = await ImageDownloadService.loadImage(
                manufacturer: manufacturer,
                exactFilename: imagePath,
                exactThumbnailFilename: thumbPath,
                useThumbnail: useThumbnail
            ) {
                images.append(image)
            } else if let colors = dominantColors, !colors.isEmpty {
                // Fallback to gradient
                images.append(ImageHelpers.generateGradientImage(from: colors))
            } else {
                images.append(nil)
            }
        }

        loadedImages = images
        isLoading = false
    }
}

#endif
