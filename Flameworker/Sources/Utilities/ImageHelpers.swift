//
//  ImageHelpers.swift
//  Flameworker
//
//  Created by Assistant on 10/01/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
import ImageIO
#endif

// MARK: - Notification Names

extension Notification.Name {
    static let userImageUploaded = Notification.Name("userImageUploaded")
}

#if canImport(UIKit)
// MARK: - UIKit-specific Image Helpers

struct ImageHelpers {
    static let productImagePathPrefix = ""
    
    // MARK: - Image Cache
    
    /// Cache to store loaded images and prevent repeated file system access
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100 // Maximum 100 cached images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        return cache
    }()
    
    /// Cache to store negative results (items that don't have images)
    private static let negativeCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 500 // Cache up to 500 "not found" results
        return cache
    }()
    
    /// Loads an image from a file path, stripping color profile information to avoid ICC warnings
    private static func loadImageWithoutColorProfile(from path: String) -> UIImage? {
        guard let data = NSData(contentsOfFile: path) else { return nil }
        
        // Create image source without color management
        guard let source = CGImageSourceCreateWithData(data, nil) else { return nil }
        
        // Create image without color profile
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: false
        ]
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
  
    
    static func sanitizeItemCodeForFilename(_ itemCode: String) -> String {
        itemCode.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")
    }
    
    /// Attempts to load a product image for the given item code and manufacturer
    /// Images are loaded in priority order:
    /// 1. User-uploaded images (from UserImageRepository)
    /// 2. Bundle images in Data/product-images/ folder
    /// 3. Manufacturer default images
    /// Format: manufacturer-itemcode.jpg (e.g., "CiM-511101.jpg")
    /// Item codes with slashes (/) or backslashes (\) will have them replaced with dashes (-) for the filename
    /// - Parameters:
    ///   - itemCode: The code to use for the image filename
    ///   - manufacturer: The manufacturer short name (optional, will try both formats)
    ///   - naturalKey: Optional natural key for user image lookup (format: "manufacturer-sku-sequence")
    /// - Returns: UIImage if found, nil otherwise
    static func loadProductImage(for itemCode: String, manufacturer: String? = nil, naturalKey: String? = nil) -> UIImage? {
        guard !itemCode.isEmpty else { return nil }

        // Debug logging for OC items
        if manufacturer?.uppercased() == "OC" || itemCode.uppercased().hasPrefix("OC-") {
            print("🔵 OC ITEM: itemCode='\(itemCode)', manufacturer='\(manufacturer ?? "nil")', naturalKey='\(naturalKey ?? "nil")'")
        }

        let cacheKey = "\(manufacturer ?? "nil")-\(itemCode)"
        let cacheKeyNS = cacheKey as NSString

        // Check positive cache first
        if let cachedImage = imageCache.object(forKey: cacheKeyNS) {
            return cachedImage
        }

        // Check negative cache (items we know don't have images)
        if negativeCache.object(forKey: cacheKeyNS) != nil {
            return nil
        }

        // PRIORITY 1: Check for user-uploaded primary image
        // NOTE: This is called from a sync context, so we can't await here
        // User images are loaded separately in ProductImageView/ProductImageDetail
        // which are async and can properly await the actor calls

        // Check if we have permission to use product-specific images for this manufacturer
        // If not, skip directly to default manufacturer image
        if let manufacturer = manufacturer,
           !GlassManufacturers.hasProductImagePermission(for: manufacturer) {
            // No permission - use default manufacturer image only
            if let defaultImageName = GlassManufacturers.defaultImageName(for: manufacturer) {
                let extensions = ["webp", "jpg", "jpeg", "png", "PNG", "JPG", "JPEG", "WEBP"]

                for ext in extensions {
                    // Try with directory
                    if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext, inDirectory: "manufacturer-images"),
                       let image = loadImageWithoutColorProfile(from: path) {
                        // Cache the successful result
                        imageCache.setObject(image, forKey: cacheKeyNS)
                        return image
                    }

                    // Try without directory (in case files are at bundle root)
                    if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext),
                       let image = loadImageWithoutColorProfile(from: path) {
                        // Cache the successful result
                        imageCache.setObject(image, forKey: cacheKeyNS)
                        return image
                    }
                }
            }

            // Cache the negative result
            negativeCache.setObject(NSNumber(booleanLiteral: true), forKey: cacheKeyNS)
            return nil
        }

        let sanitizedCode = sanitizeItemCodeForFilename(itemCode)

        // Common image extensions to try (including webp for modern web images)
        let extensions = ["webp", "jpg", "jpeg", "png", "PNG", "JPG", "JPEG", "WEBP"]

        // Try with manufacturer prefix first if provided (and we have permission)
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            let sanitizedManufacturer = sanitizeItemCodeForFilename(manufacturer)

            // Try multiple case variations since images might be uppercase/lowercase/mixed
            let manufacturerVariations = [
                sanitizedManufacturer.uppercased(),  // Try uppercase first (most common)
                sanitizedManufacturer.lowercased(),  // Then lowercase
                sanitizedManufacturer.capitalized,   // Then capitalized
                sanitizedManufacturer                // Finally original case
            ]

            for mfrVariation in manufacturerVariations {
                for ext in extensions {
                    // Check if itemCode already starts with manufacturer prefix to avoid duplication
                    // (e.g., itemCode="OC-6023-83CC-F" already has "OC-" prefix)
                    let imageName: String
                    if sanitizedCode.uppercased().hasPrefix("\(mfrVariation.uppercased())-") {
                        // ItemCode already includes manufacturer prefix, use as-is
                        imageName = "\(productImagePathPrefix)\(sanitizedCode)"
                        print("🔍 OC DEBUG: Using as-is: \(imageName).\(ext) (code: \(sanitizedCode), mfr: \(mfrVariation))")
                    } else {
                        // Add manufacturer prefix
                        imageName = "\(productImagePathPrefix)\(mfrVariation)-\(sanitizedCode)"
                        print("🔍 OC DEBUG: Adding prefix: \(imageName).\(ext) (code: \(sanitizedCode), mfr: \(mfrVariation))")
                    }

                    // Try bundle file with color profile handling
                    if let path = Bundle.main.path(forResource: imageName, ofType: ext) {
                        print("✅ OC DEBUG: Found path: \(path)")
                        if let image = loadImageWithoutColorProfile(from: path) {
                            print("✅ OC DEBUG: Loaded image successfully")
                            // Cache the successful result
                            imageCache.setObject(image, forKey: cacheKeyNS)
                            return image
                        } else {
                            print("❌ OC DEBUG: Path exists but failed to load image")
                        }
                    } else {
                        print("🚫 OC DEBUG: Path not found for: \(imageName).\(ext)")
                    }
                }
            }
        }

        // Fallback: try without manufacturer prefix (for backward compatibility)
        for ext in extensions {
            let imageName = "\(productImagePathPrefix)\(sanitizedCode)"

            // Try bundle file with color profile handling
            if let path = Bundle.main.path(forResource: imageName, ofType: ext),
               let image = loadImageWithoutColorProfile(from: path) {
                // Cache the successful result
                imageCache.setObject(image, forKey: cacheKeyNS)
                return image
            }
        }

        // Final fallback: try manufacturer default image
        if let manufacturer = manufacturer,
           let defaultImageName = GlassManufacturers.defaultImageName(for: manufacturer) {
            for ext in extensions {
                if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext, inDirectory: "manufacturer-images"),
                   let image = loadImageWithoutColorProfile(from: path) {
                    // Cache the successful result
                    imageCache.setObject(image, forKey: cacheKeyNS)
                    return image
                }

                // Also try at bundle root
                if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext),
                   let image = loadImageWithoutColorProfile(from: path) {
                    // Cache the successful result
                    imageCache.setObject(image, forKey: cacheKeyNS)
                    return image
                }
            }
        }

        // Cache the negative result to prevent future lookups
        negativeCache.setObject(NSNumber(booleanLiteral: true), forKey: cacheKeyNS)
        return nil
    }
    
    /// Checks if a product image exists for the given item code and manufacturer
    /// - Parameters:
    ///   - itemCode: The code to check for
    ///   - manufacturer: The manufacturer short name (optional)
    /// - Returns: true if an image exists, false otherwise
    static func productImageExists(for itemCode: String, manufacturer: String? = nil) -> Bool {
        return loadProductImage(for: itemCode, manufacturer: manufacturer) != nil
    }
    
    static func getProductImageName(for itemCode: String, manufacturer: String? = nil) -> String? {
        guard !itemCode.isEmpty else { return nil }

        // Check if we have permission to use product-specific images for this manufacturer
        // If not, skip directly to default manufacturer image
        if let manufacturer = manufacturer,
           !GlassManufacturers.hasProductImagePermission(for: manufacturer) {
            // No permission - use default manufacturer image only
            if let defaultImageName = GlassManufacturers.defaultImageName(for: manufacturer) {
                let extensions = ["webp", "jpg", "jpeg", "png", "PNG", "JPG", "JPEG", "WEBP"]
                for ext in extensions {
                    // Try with directory
                    if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext, inDirectory: "manufacturer-images"),
                       loadImageWithoutColorProfile(from: path) != nil {
                        return "manufacturer-images/\(defaultImageName).\(ext)"
                    }
                    // Try without directory (in case files are at bundle root)
                    if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext),
                       loadImageWithoutColorProfile(from: path) != nil {
                        return "\(defaultImageName).\(ext)"
                    }
                }
            }
            return nil
        }

        let sanitizedCode = sanitizeItemCodeForFilename(itemCode)
        let extensions = ["webp", "jpg", "jpeg", "png", "PNG", "JPG", "JPEG", "WEBP"]

        // Try with manufacturer prefix first if provided (and we have permission)
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            let sanitizedManufacturer = sanitizeItemCodeForFilename(manufacturer)

            // Try multiple case variations since images might be uppercase/lowercase/mixed
            let manufacturerVariations = [
                sanitizedManufacturer.uppercased(),  // Try uppercase first (most common)
                sanitizedManufacturer.lowercased(),  // Then lowercase
                sanitizedManufacturer.capitalized,   // Then capitalized
                sanitizedManufacturer                // Finally original case
            ]

            for mfrVariation in manufacturerVariations {
                for ext in extensions {
                    // Check if itemCode already starts with manufacturer prefix to avoid duplication
                    // (e.g., itemCode="OC-6023-83CC-F" already has "OC-" prefix)
                    let imageName: String
                    if sanitizedCode.uppercased().hasPrefix("\(mfrVariation.uppercased())-") {
                        // ItemCode already includes manufacturer prefix, use as-is
                        imageName = "\(productImagePathPrefix)\(sanitizedCode)"
                    } else {
                        // Add manufacturer prefix
                        imageName = "\(productImagePathPrefix)\(mfrVariation)-\(sanitizedCode)"
                    }

                    // Try bundle file for existence check
                    if let path = Bundle.main.path(forResource: imageName, ofType: ext),
                       loadImageWithoutColorProfile(from: path) != nil {
                        return "\(imageName).\(ext)"
                    }
                }
            }
        }

        // Fallback: try without manufacturer prefix
        for ext in extensions {
            let imageName = "\(productImagePathPrefix)\(sanitizedCode)"

            // Try bundle file for existence check
            if let path = Bundle.main.path(forResource: imageName, ofType: ext),
               loadImageWithoutColorProfile(from: path) != nil {
                return "\(imageName).\(ext)"
            }
        }

        // Final fallback: try manufacturer default image
        if let manufacturer = manufacturer,
           let defaultImageName = GlassManufacturers.defaultImageName(for: manufacturer) {
            for ext in extensions {
                if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext, inDirectory: "manufacturer-images"),
                   loadImageWithoutColorProfile(from: path) != nil {
                    return "manufacturer-images/\(defaultImageName).\(ext)"
                }
            }
        }

        return nil
    }

    // MARK: - User Image Support

    /// Clear cached image for an item (call after uploading new user image)
    static func clearCache(for itemCode: String, manufacturer: String?) {
        let cacheKey = "\(manufacturer ?? "nil")-\(itemCode)"
        imageCache.removeObject(forKey: cacheKey as NSString)
        negativeCache.removeObject(forKey: cacheKey as NSString)
    }

    /// Clear all cached images (both positive and negative caches)
    /// Use this when image loading logic changes or new images are added to the bundle
    static func clearAllCaches() {
        imageCache.removeAllObjects()
        negativeCache.removeAllObjects()
    }
}

struct ProductImageView: View {
    let itemCode: String
    let manufacturer: String?
    let naturalKey: String?
    let size: CGFloat

    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = true
    @State private var refreshTrigger: UUID = UUID()

    init(itemCode: String, manufacturer: String? = nil, naturalKey: String? = nil, size: CGFloat = 60) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
        self.naturalKey = naturalKey
        self.size = size
    }

    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "photo")
                                .foregroundColor(Color(.systemGray3))
                                .font(.system(size: size * 0.4))
                        }
                    }
            }
        }
        .task(id: refreshTrigger) {
            await loadImageAsync()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userImageUploaded)) { notification in
            if let uploadedNaturalKey = notification.object as? String,
               uploadedNaturalKey == naturalKey {
                // Force refresh for this item
                loadedImage = nil
                isLoading = true
                refreshTrigger = UUID()
            }
        }
    }

    @MainActor
    private func loadImageAsync() async {
        isLoading = true

        // PRIORITY 1: Try to load user-uploaded image first (if we have a naturalKey)
        if let naturalKey = naturalKey {
            let repo = RepositoryFactory.createUserImageRepository()
            if let primaryModel = try? await repo.getPrimaryImage(for: naturalKey),
               let userImage = try? await repo.loadImage(primaryModel) {
                loadedImage = userImage
                isLoading = false
                return
            }
        }

        // PRIORITY 2: Load bundle/manufacturer images
        let image = await Task.detached(priority: .utility) {
            ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer, naturalKey: nil)
        }.value

        loadedImage = image
        isLoading = false
    }
}

struct ProductImageDetail: View {
    let itemCode: String
    let manufacturer: String?
    let naturalKey: String?
    let maxSize: CGFloat
    let allowImageUpload: Bool
    let onImageUploaded: (() -> Void)?

    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = true
    @State private var showingFullScreen: Bool = false
    @State private var showingImagePicker: Bool = false

    init(itemCode: String, manufacturer: String? = nil, naturalKey: String? = nil, maxSize: CGFloat = 200, allowImageUpload: Bool = false, onImageUploaded: (() -> Void)? = nil) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
        self.naturalKey = naturalKey
        self.maxSize = maxSize
        self.allowImageUpload = allowImageUpload
        self.onImageUploaded = onImageUploaded
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Group {
                if let loadedImage = loadedImage {
                    Image(uiImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxSize, maxHeight: maxSize)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .onTapGesture {
                            showingFullScreen = true
                        }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: maxSize * 0.8, height: maxSize * 0.6)
                        .overlay {
                            VStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color(.systemGray3))
                                    Text("No Image")
                                        .font(.caption)
                                        .foregroundColor(Color(.systemGray))
                                }
                            }
                        }
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
            }

            // Upload button (only show if enabled and we have a natural key)
            if allowImageUpload, let naturalKey = naturalKey {
                Button(action: {
                    showingImagePicker = true
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: loadedImage == nil ? "photo.badge.plus" : "photo.badge.arrow.down")
                        Text(loadedImage == nil ? "Add Image" : "Replace Image")
                    }
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.accentPrimary)
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImageSourcePickerSheet(
                        selectedImage: .constant(nil),
                        isPresented: $showingImagePicker,
                        onImageSelected: { image in
                            Task {
                                await uploadImage(image, for: naturalKey)
                            }
                        }
                    )
                }
            }
        }
        .task {
            await loadImageAsync()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let loadedImage = loadedImage {
                FullScreenImageViewer(image: loadedImage, isPresented: $showingFullScreen)
            }
        }
    }

    @MainActor
    private func loadImageAsync() async {
        isLoading = true

        // PRIORITY 1: Try to load user-uploaded image first (if we have a naturalKey)
        if let naturalKey = naturalKey {
            let repo = RepositoryFactory.createUserImageRepository()
            if let primaryModel = try? await repo.getPrimaryImage(for: naturalKey),
               let userImage = try? await repo.loadImage(primaryModel) {
                loadedImage = userImage
                isLoading = false
                return
            }
        }

        // PRIORITY 2: Load bundle/manufacturer images
        let image = await Task.detached(priority: .utility) {
            ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer, naturalKey: nil)
        }.value

        loadedImage = image
        isLoading = false
    }

    @MainActor
    private func uploadImage(_ image: UIImage, for naturalKey: String) async {
        do {
            let repo = RepositoryFactory.createUserImageRepository()
            _ = try await repo.saveImage(image, for: naturalKey, type: .primary)

            // Clear image cache for this item so it reloads with new image
            ImageHelpers.clearCache(for: itemCode, manufacturer: manufacturer)

            // Reload the image
            loadedImage = nil
            await loadImageAsync()

            // Notify callback
            onImageUploaded?()

            // Post notification so all ProductImageView instances reload
            NotificationCenter.default.post(name: .userImageUploaded, object: naturalKey)
        } catch {
            // TODO: Show error to user in UI
            print("Failed to upload image: \(error)")
        }
    }
}

// MARK: - Full Screen Image Viewer

struct FullScreenImageViewer: View {
    let image: UIImage
    @Binding var isPresented: Bool

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .padding()
                }

                Spacer()

                // Image with pinch-to-zoom and pan gestures
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale = min(max(scale * delta, 1.0), 5.0)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                // Reset if zoomed out past normal
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .gesture(
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
                        // Double-tap to reset zoom
                        withAnimation(.spring()) {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }

                Spacer()

                // Instruction text
                Text("Pinch to zoom • Double-tap to reset")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 20)
            }
        }
    }
}

#endif

// MARK: - Cross-Platform Product Image Views

struct ProductImageThumbnail: View {
    let itemCode: String
    let manufacturer: String?
    let naturalKey: String?
    let size: CGFloat

    init(itemCode: String, manufacturer: String? = nil, naturalKey: String? = nil, size: CGFloat = 40) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
        self.naturalKey = naturalKey
        self.size = size
    }

    var body: some View {
        #if canImport(UIKit)
        ProductImageView(itemCode: itemCode, manufacturer: manufacturer, naturalKey: naturalKey, size: size)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        #else
        // macOS/other platforms: Show placeholder
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                    .font(.system(size: size * 0.4))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
        #endif
    }
}
