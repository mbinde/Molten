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
struct HeroHeader: View {
    let item: GlassItemModel
    var extendsToTop: Bool = false
    var onAddPhoto: (() -> Void)?
    var imageRefreshTrigger: UUID?  // Change this to force image reload

    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var showingFullScreen = false
    @State private var showingColorApproximationInfo = false
    @State private var isShowingColorApproximation = false

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
            // Large product image - fills width and crops vertically
            // loadProductImageForDisplay always returns a usable image (product photo, gradient, or manufacturer logo)
            GeometryReader { geometry in
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: imageHeight)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingFullScreen = true
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
                    .popover(isPresented: $showingColorApproximationInfo) {
                        colorApproximationPopover
                    }
                    .position(
                        x: geometry.size.width - DesignSystem.Padding.standard - 12,
                        y: (extendsToTop ? geometry.safeAreaInsets.top : 0) + DesignSystem.Spacing.lg + 12
                    )
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
                                }
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            }
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
            FullScreenImageView(image: loadedImage, itemName: item.name)
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

        // Use the centralized image loading logic
        loadedImage = await ImageHelpers.loadProductImageForDisplay(
            itemCode: item.stable_id,
            manufacturer: item.manufacturer,
            stableId: item.stable_id,
            imagePath: item.image_path,
            imageThumbPath: item.image_thumb_path,
            dominantColors: item.dominant_colors
        )
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

/// Zoomable image view with pinch gesture
private struct ZoomableImageView: View {
    let image: UIImage

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        lastScale = scale
                        // Snap back if zoomed out too much
                        if scale < 1.0 {
                            withAnimation(.spring()) {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if scale > 1.0 {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .onTapGesture(count: 2) {
                // Double tap to reset zoom
                withAnimation(.spring()) {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
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
