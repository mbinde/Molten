//
//  HeroHeader.swift
//  Molten
//
//  Large hero-style header with product image and overlaid title
//  Inspired by the "Luminous Precision" design mockups
//

import SwiftUI

/// Hero-style header with large product image and overlaid item name
/// Used at the top of detail views for visual impact
/// Supports multiple images with carousel display
struct HeroHeader: View {
    let item: GlassItemModel
    var extendsToTop: Bool = false
    var onAddPhoto: (() -> Void)?
    var imageRefreshTrigger: UUID?  // Change this to force image reload

    @State private var loadedImages: [UIImage] = []
    @State private var selectedImageIndex: Int = 0
    @State private var isLoading = true
    @State private var showingFullScreen = false
    @State private var showingColorApproximationInfo = false
    @State private var isShowingColorApproximation = false
    @State private var autoRotateTimer: Timer?
    @State private var userHasInteracted = false

    /// Auto-rotation interval in seconds
    private let autoRotateInterval: TimeInterval = 4.0

    /// Number of images available
    private var imageCount: Int {
        max(loadedImages.count, 1)
    }

    /// Whether we have multiple images to show carousel
    private var hasMultipleImages: Bool {
        loadedImages.count > 1
    }

    init(item: GlassItemModel, extendsToTop: Bool = false, onAddPhoto: (() -> Void)? = nil, imageRefreshTrigger: UUID? = nil) {
        self.item = item
        self.extendsToTop = extendsToTop
        self.onAddPhoto = onAddPhoto
        self.imageRefreshTrigger = imageRefreshTrigger
    }

    private var imageHeight: CGFloat {
        extendsToTop ? 280 : 220
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Large product image(s) - fills width and crops vertically
            // Shows carousel when multiple images available
            GeometryReader { geometry in
                if !loadedImages.isEmpty {
                    if hasMultipleImages {
                        // Multiple images - show carousel
                        TabView(selection: $selectedImageIndex) {
                            ForEach(loadedImages.indices, id: \.self) { index in
                                Image(uiImage: loadedImages[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: imageHeight)
                                    .clipped()
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(width: geometry.size.width, height: imageHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingFullScreen = true
                        }
                        .onAppear {
                            startAutoRotation()
                        }
                        .onDisappear {
                            stopAutoRotation()
                        }
                        .onChange(of: selectedImageIndex) { _, _ in
                            // User swiped manually - stop auto-rotation permanently
                            if autoRotateTimer != nil {
                                userHasInteracted = true
                                stopAutoRotation()
                            }
                        }
                        .accessibilityLabel("Product images for \(item.name), \(selectedImageIndex + 1) of \(loadedImages.count)")
                        .accessibilityHint("Swipe to see more images, double tap to view full screen")
                        .accessibilityAddTraits(.isButton)
                    } else {
                        // Single image
                        Image(uiImage: loadedImages[0])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: imageHeight)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingFullScreen = true
                            }
                            .accessibilityLabel("Product image for \(item.name)")
                            .accessibilityHint("Double tap to view full screen")
                            .accessibilityAddTraits(.isButton)
                    }
                } else {
                    // Loading or placeholder
                    Rectangle()
                        .fill(DesignSystem.Colors.backgroundSecondary)
                        .frame(width: geometry.size.width, height: imageHeight)
                        .overlay {
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                }
            }
            .frame(height: imageHeight)

            // Info button in top-right corner (when showing color approximation)
            if isShowingColorApproximation {
                GeometryReader { geometry in
                    Button {
                        showingColorApproximationInfo = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .accessibilityLabel("Color approximation info")
                    .accessibilityHint("This image shows an approximated color. Double tap for more information.")
                    .popover(isPresented: $showingColorApproximationInfo) {
                        colorApproximationPopover
                    }
                    .position(
                        x: geometry.size.width - DesignSystem.Padding.standard - 12,
                        y: (extendsToTop ? geometry.safeAreaInsets.top : 0) + DesignSystem.Spacing.lg + 12
                    )
                }
            }

            // Chevron indicators and page dots for multi-image carousel
            if hasMultipleImages {
                // Chevron indicators showing swipe direction
                HStack {
                    // Left chevron - visible when there are previous images
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .opacity(selectedImageIndex > 0 ? 0.8 : 0)
                        .padding(.leading, 12)

                    Spacer()

                    // Right chevron - visible when there are more images
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        .opacity(selectedImageIndex < loadedImages.count - 1 ? 0.8 : 0)
                        .padding(.trailing, 12)
                }
                .padding(.bottom, 70)  // Position above text overlay
                .allowsHitTesting(false)  // Don't block swipe gestures

                // Page indicator dots
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(loadedImages.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selectedImageIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 50)  // Position above text overlay
                }
            }

            // Text overlay with background stripe that grows with text
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(item.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        // Manufacturer name - clickable if URL available
                        let manufacturerName = GlassManufacturers.fullName(for: item.manufacturer) ?? item.manufacturer.capitalized
                        if let urlString = item.url, let url = URL(string: urlString) {
                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Text(manufacturerName)
                                    Image(systemName: "arrow.up.forward")
                                        .font(.caption)
                                        .accessibilityHidden(true)
                                }
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            }
                            .accessibilityLabel("Visit \(manufacturerName) website")
                            .accessibilityHint("Opens in browser")
                        } else {
                            Text(manufacturerName)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Spacer()

                    // Camera button for adding custom photo
                    if let onAddPhoto = onAddPhoto {
                        Button {
                            onAddPhoto()
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(DesignSystem.Spacing.md)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Add custom photo")
                        .accessibilityHint("Double tap to add your own photo of this product")
                        .accessibilityIdentifier("hero_add_photo")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Padding.standard)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .background(Color.black.opacity(0.5))
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: DesignSystem.CornerRadius.extraLarge,
                bottomTrailingRadius: DesignSystem.CornerRadius.extraLarge,
                topTrailingRadius: 0
            )
        )
        .ignoresSafeArea(edges: extendsToTop ? .top : [])
        .task(id: imageRefreshTrigger) {
            await loadImage()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if hasMultipleImages {
                FullscreenImageGallery(images: loadedImages, startIndex: selectedImageIndex)
            } else {
                FullScreenImageView(image: loadedImages.first, itemName: item.name)
            }
        }
    }

    // MARK: - Color Approximation Popover

    private var colorApproximationPopover: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Color Approximation")
                .font(DesignSystem.Typography.formLabel)
                .fontWeight(DesignSystem.FontWeight.semibold)

            Text("We don't have permission to show product images from this manufacturer, so we've approximated the color.")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Have a photo? Add it here and long-press to suggest it for the catalog.")
                .font(DesignSystem.Typography.listItemCaption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
    }

    // MARK: - Image Loading

    private func loadImage() async {
        isLoading = true
        defer { isLoading = false }

        // Check if we'll be showing a gradient (for info button)
        isShowingColorApproximation = await ImageHelpers.wouldReturnGradientImage(
            manufacturer: item.manufacturer,
            imagePath: item.image_path,
            imageThumbPath: item.image_thumb_path,
            dominantColors: item.dominant_colors,
            stableId: item.stable_id
        )

        // Check if we have multiple images available
        let imagePaths = item.image_paths ?? []
        let imageThumbPaths = item.image_thumb_paths ?? []
        let useThumbnail = !UserSettings.shared.downloadFullSizeImages

        if imagePaths.count > 1 {
            // Load multiple images
            var images: [UIImage] = []
            for i in 0..<imagePaths.count {
                let path = imagePaths[i]
                let thumbPath = imageThumbPaths.indices.contains(i) ? imageThumbPaths[i] : nil

                if let image = await ImageDownloadService.loadImage(
                    manufacturer: item.manufacturer,
                    exactFilename: path,
                    exactThumbnailFilename: thumbPath,
                    useThumbnail: useThumbnail
                ) {
                    images.append(image)
                }
            }

            // If we loaded multiple images, use them
            if images.count > 1 {
                loadedImages = images
                return
            }
        }

        // Fall back to single image loading (primary image or gradient)
        if let image = await ImageHelpers.loadProductImageForDisplay(
            itemCode: item.stable_id,
            manufacturer: item.manufacturer,
            stableId: item.stable_id,
            imagePath: item.image_path,
            imageThumbPath: item.image_thumb_path,
            dominantColors: item.dominant_colors
        ) {
            loadedImages = [image]
        } else {
            loadedImages = []
        }
    }

    // MARK: - Auto-Rotation

    private func startAutoRotation() {
        guard loadedImages.count > 1, !userHasInteracted else { return }
        stopAutoRotation()

        autoRotateTimer = Timer.scheduledTimer(withTimeInterval: autoRotateInterval, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedImageIndex = (selectedImageIndex + 1) % loadedImages.count
            }
        }
    }

    private func stopAutoRotation() {
        autoRotateTimer?.invalidate()
        autoRotateTimer = nil
    }
}

// MARK: - Full Screen Image View

/// Full screen image viewer with dismiss button
private struct FullScreenImageView: View {
    let image: UIImage?
    let itemName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()

            // Image with pinch to zoom
            if let image = image {
                ZoomableImageView(image: image)
            }

            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close full screen image")
                    .padding()
                }
                Spacer()

                // Item name at bottom
                Text(itemName)
                    .font(DesignSystem.Typography.listItemSubtitle)
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}

// MARK: - Preview

#Preview("Hero Header") {
    VStack {
        HeroHeader(
            item: GlassItemModel(
                stable_id: "bullseye-0124-30",
                name: "Bullseye Red Transparent",
                sku: "BE-0124-30",
                manufacturer: "bullseye",
                coe: 90,
                mfr_status: "available"
            )
        )
        .padding()

        Spacer()
    }
}
