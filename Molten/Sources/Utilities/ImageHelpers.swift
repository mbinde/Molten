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
    static let colorChipDisplayModeChanged = Notification.Name("colorChipDisplayModeChanged")
}

#if canImport(UIKit)
// MARK: - UIKit-specific Image Helpers

/// Centralized image loading utilities for the app.
///
/// ## Public API (use these in Views):
/// - `loadProductImageForDisplay()` - **THE** entry point for loading product images. Always returns a usable image.
/// - `wouldReturnGradientImage()` - Check if the image would be a gradient (for info buttons)
/// - `generateGradientImage()` - Generate a gradient UIImage from hex colors (used internally, but public for testing)
/// - `clearCache()` / `clearAllCaches()` - Cache management
///
/// ## Internal Helpers (DO NOT call from Views - use loadProductImageForDisplay instead):
/// - `loadProductImage()` - Low-level bundle/cache loading (used internally for manufacturer logos)
/// - `productImageExists()` - Low-level existence check
/// - `getProductImageName()` - Low-level filename retrieval
/// - `sanitizeItemCodeForFilename()` - Filename sanitization
///
/// These internal helpers are accessible for unit testing but should never be called directly from Views.
struct ImageHelpers {
    nonisolated static let productImagePathPrefix = ""

    // MARK: - Shared Image Repository

    /// Shared user image repository (NOT created per view to avoid Core Data threading issues)
    private static let sharedUserImageRepository = AppDependencies.shared.userImageRepository

    // MARK: - Image Cache

    /// Cache to store loaded images and prevent repeated file system access
    private nonisolated(unsafe) static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100 // Maximum 100 cached images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
        return cache
    }()

    /// Cache to store negative results (items that don't have images)
    private nonisolated(unsafe) static let negativeCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 500 // Cache up to 500 "not found" results
        return cache
    }()

    // MARK: - Gradient Image Generation

    /// Generates a UIImage with a linear gradient from hex color strings
    /// This allows gradient images to be returned from loadProductImageForDisplay instead of nil
    /// - Parameters:
    ///   - colors: Array of hex color strings (e.g., ["#2E5E41", "#1D4030"])
    ///   - size: Size of the image to generate (default 120x120 for good quality scaling)
    /// - Returns: UIImage with gradient, or nil if colors are invalid
    nonisolated static func generateGradientImage(from colors: [String], size: CGSize = CGSize(width: 120, height: 120)) -> UIImage? {
        // Convert hex strings to UIColors
        let uiColors = colors.compactMap { hexToUIColor($0) }
        guard !uiColors.isEmpty else { return nil }

        // Create a horizontal linear gradient
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }

        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Create gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let cgColors = uiColors.map { $0.cgColor } as CFArray

        // If only one color, duplicate it for a solid fill
        let gradientColors: CFArray
        if uiColors.count == 1 {
            gradientColors = [uiColors[0].cgColor, uiColors[0].cgColor] as CFArray
        } else {
            gradientColors = cgColors
        }

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: nil) else {
            return nil
        }

        // Draw horizontal gradient (left to right, like ColorSwatchView)
        let startPoint = CGPoint(x: 0, y: size.height / 2)
        let endPoint = CGPoint(x: size.width, y: size.height / 2)
        context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Converts a hex color string to UIColor
    /// - Parameter hex: Hex string in format "#RRGGBB" or "RRGGBB"
    /// - Returns: UIColor, or nil if parsing fails
    private nonisolated static func hexToUIColor(_ hex: String) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else {
            return nil
        }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    /// Checks if the image returned by loadProductImageForDisplay would be a color gradient
    /// Used by views like HeroHeader that need to show an info button for color approximations
    @MainActor
    static func wouldReturnGradientImage(
        manufacturer: String?,
        imagePath: String?,
        imageThumbPath: String?,
        dominantColors: [String]?,
        stableId: String? = nil
    ) async -> Bool {
        // If user has uploaded a primary image, we won't show the gradient
        if let stableId = stableId {
            if let _ = try? await sharedUserImageRepository.getPrimaryImage(ownerType: .glassItem, ownerId: stableId) {
                return false
            }
        }

        // Must have dominant colors to show gradient
        guard let colors = dominantColors, !colors.isEmpty else {
            return false
        }

        let colorChipMode = UserSettings.shared.colorChipDisplayMode

        // ALWAYS mode: always show gradient if we have colors
        if colorChipMode == .always {
            return true
        }

        // NEVER mode: never show gradient
        if colorChipMode == .never {
            return false
        }

        // NO_PHOTO mode (default): show gradient only if no product image is available
        if let manufacturer = manufacturer,
           !GlassManufacturers.hasProductImagePermission(for: manufacturer) {
            // No permission - would show gradient (unless PDX)
            let isPDX = manufacturer.caseInsensitiveCompare("PDX") == .orderedSame
            return !isPDX
        }

        // Has permission - check if product image exists
        let useThumbnail = !UserSettings.shared.downloadFullSizeImages
        let hasProductImage = await ImageDownloadService.loadImage(
            manufacturer: manufacturer,
            exactFilename: imagePath,
            exactThumbnailFilename: imageThumbPath,
            useThumbnail: useThumbnail
        ) != nil

        return !hasProductImage
    }

    // MARK: - Centralized Image Loading Logic

    /// Single source of truth for product image loading decision tree
    /// ALWAYS returns a usable image - never nil. Falls back to gradient or manufacturer logo.
    /// - Parameter excludeUserImages: If true, skips user-uploaded images and only returns manufacturer/catalog images
    @MainActor
    static func loadProductImageForDisplay(
        itemCode: String,
        manufacturer: String?,
        stableId: String?,
        imagePath: String?,
        imageThumbPath: String?,
        dominantColors: [String]?,
        excludeUserImages: Bool = false
    ) async -> UIImage? {
        // Step 0: User-uploaded image (highest priority - always wins)
        // Skip this step if excludeUserImages is true (used for "Your Photos" section)
        if !excludeUserImages, let stableId = stableId {
            if let primaryModel = try? await sharedUserImageRepository.getPrimaryImage(ownerType: .glassItem, ownerId: stableId),
               let userImage = try? await sharedUserImageRepository.loadImage(primaryModel) {
                return userImage
            }
        }

        // Get user's color chip display preference
        let colorChipMode = UserSettings.shared.colorChipDisplayMode

        // ALWAYS MODE: Always show gradient if we have dominant colors
        if colorChipMode == .always {
            // Check if we have dominant_colors
            if let colors = dominantColors, !colors.isEmpty {
                // Generate and return gradient image
                if let gradientImage = generateGradientImage(from: colors) {
                    return gradientImage
                }
            }
            // No colors or gradient generation failed - fall through to try product image or manufacturer logo
        } else if colorChipMode == .never {
            // NEVER MODE: Never show gradient - always photo or logo
            // Check if we have permission for product images
            if let manufacturer = manufacturer,
               !GlassManufacturers.hasProductImagePermission(for: manufacturer) {
                // No permission - skip to manufacturer logo (ignore dominant_colors)
                return await Task.detached(priority: .background) {
                    ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer, stableId: nil, imagePath: nil)
                }.value
            }

            // Try to load product image from CDN/bundle
            let useThumbnail = !UserSettings.shared.downloadFullSizeImages
            if let cdnImage = await ImageDownloadService.loadImage(
                manufacturer: manufacturer,
                exactFilename: imagePath,
                exactThumbnailFilename: imageThumbPath,
                useThumbnail: useThumbnail
            ) {
                return cdnImage
            }

            // Final fallback: Try manufacturer logo
            return await Task.detached(priority: .background) {
                ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer, stableId: nil, imagePath: nil)
            }.value
        } else if colorChipMode == .noPhoto {
            // NO PHOTO MODE (default): Only show gradient when no photo available
            // Step 1: Check if we have permission for product images
            if let manufacturer = manufacturer,
               !GlassManufacturers.hasProductImagePermission(for: manufacturer) {
                // Special case: PDX Tubing's product photos are too poor quality for color extraction
                // Always show manufacturer logo instead of gradient
                let isPDX = manufacturer.caseInsensitiveCompare("PDX") == .orderedSame

                // No permission - only load manufacturer logo if no color codes available (or PDX)
                if isPDX || dominantColors == nil || dominantColors?.isEmpty == true {
                    return await Task.detached(priority: .background) {
                        ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer, stableId: nil, imagePath: nil)
                    }.value
                } else {
                    // Generate and return gradient image
                    if let colors = dominantColors, let gradientImage = generateGradientImage(from: colors) {
                        return gradientImage
                    }
                    // Gradient generation failed - fall through to manufacturer logo
                    return await Task.detached(priority: .background) {
                        ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer, stableId: nil, imagePath: nil)
                    }.value
                }
            }

            // Step 2: Try to load product image from CDN/bundle
            let useThumbnail = !UserSettings.shared.downloadFullSizeImages
            if let cdnImage = await ImageDownloadService.loadImage(
                manufacturer: manufacturer,
                exactFilename: imagePath,
                exactThumbnailFilename: imageThumbPath,
                useThumbnail: useThumbnail
            ) {
                return cdnImage
            }

            // Step 3: No product image found - try gradient if we have colors
            if let colors = dominantColors, !colors.isEmpty {
                if let gradientImage = generateGradientImage(from: colors) {
                    return gradientImage
                }
            }

            // Final fallback: Try manufacturer logo
            return await Task.detached(priority: .background) {
                ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer, stableId: nil, imagePath: nil)
            }.value
        }

        // Common fallback for ALWAYS mode when no colors (or any other edge cases)
        // Try to load product image from CDN/bundle
        let useThumbnail = !UserSettings.shared.downloadFullSizeImages
        if let cdnImage = await ImageDownloadService.loadImage(
            manufacturer: manufacturer,
            exactFilename: imagePath,
            exactThumbnailFilename: imageThumbPath,
            useThumbnail: useThumbnail
        ) {
            return cdnImage
        }

        // Final fallback: Try manufacturer logo
        return await Task.detached(priority: .background) {
            ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer, stableId: nil, imagePath: nil)
        }.value
    }

    /// Loads an image from a file path, stripping color profile information to avoid ICC warnings
    /// Uses UIImage's built-in JPEG/PNG decoder which is more forgiving of corrupt color profiles
    private nonisolated static func loadImageWithoutColorProfile(from path: String) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }

        // Use UIImage's decoder which handles corrupt profiles more gracefully
        // Then immediately redraw to strip the profile
        guard let sourceImage = UIImage(data: data) else {
            return nil
        }

        // Get the underlying CGImage
        guard let cgImage = sourceImage.cgImage else {
            return nil
        }

        // Create a new image WITHOUT the color space (this strips the profile)
        // Use device RGB color space which is standard and doesn't have profile issues
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let width = cgImage.width
        let height = cgImage.height
        let bitsPerComponent = 8
        let bytesPerRow = width * 4

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Draw the original image into the new context (strips color profile)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get the redrawn image without color profile
        guard let newCGImage = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: newCGImage)
    }
  

    nonisolated static func sanitizeItemCodeForFilename(_ itemCode: String) -> String {
        itemCode.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "\\", with: "-")
    }
    
    /// Attempts to load a product image for the given item code and manufacturer
    /// Images are loaded in priority order:
    /// 1. User-uploaded images (from UserImageRepository)
    /// 2. Downloaded images from CDN (cdn.moltenglass.app) - cached locally
    /// 3. Exact image path if provided
    /// 4. Bundle images in Data/product-images/ folder
    /// 5. Manufacturer default images
    /// Format: manufacturer-itemcode.jpg (e.g., "CiM-511101.jpg")
    /// Item codes with slashes (/) or backslashes (\) will have them replaced with dashes (-) for the filename
    /// - Parameters:
    ///   - itemCode: The code to use for the image filename
    ///   - manufacturer: The manufacturer short name (optional, will try both formats)
    ///   - stableId: Optional natural key for user image lookup (format: "manufacturer-sku-sequence")
    ///   - imagePath: Optional exact image path (e.g., "OC-210-72S-F.jpg") - skips extension guessing
    /// - Returns: UIImage if found, nil otherwise
    nonisolated static func loadProductImage(for itemCode: String, manufacturer: String? = nil, stableId: String? = nil, imagePath: String? = nil) -> UIImage? {
        guard !itemCode.isEmpty else { return nil }

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

        // CRITICAL LEGAL CHECK: Check manufacturer image permissions FIRST
        // This MUST happen before ANY image loading attempts to avoid legal issues
        // ⚠️ DO NOT MOVE THIS CHECK BELOW ANY IMAGE LOADING CODE ⚠️
        // Check if we have permission to use product-specific images for this manufacturer
        // If not, skip directly to default manufacturer image
        if let manufacturer = manufacturer,
           !GlassManufacturers.hasProductImagePermission(for: manufacturer) {
            // No permission - use default manufacturer image only
            if let defaultImageName = GlassManufacturers.defaultImageName(for: manufacturer) {
                let extensions = ["webp", "jpg", "jpeg", "png", "PNG", "JPG", "JPEG", "WEBP"]

                for ext in extensions {
                    // Files in Molten/Resources/ are flattened to bundle root
                    if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext),
                       let image = loadImageWithoutColorProfile(from: path) {
                        imageCache.setObject(image, forKey: cacheKeyNS)
                        return image
                    }
                }
            }

            // Cache the negative result
            negativeCache.setObject(NSNumber(booleanLiteral: true), forKey: cacheKeyNS)
            return nil
        }

        // PRIORITY 2: Use exact image path if provided (we have permission if we got here)
        if let imagePath = imagePath, !imagePath.isEmpty {
            // Extract resource name and extension from path
            let pathComponents = imagePath.split(separator: ".")
            if pathComponents.count >= 2 {
                let resourceName = pathComponents.dropLast().joined(separator: ".")
                let ext = String(pathComponents.last!)

                // Files in Molten/Resources/ are flattened to bundle root
                if let path = Bundle.main.path(forResource: resourceName, ofType: ext),
                   let image = loadImageWithoutColorProfile(from: path) {
                    imageCache.setObject(image, forKey: cacheKeyNS)
                    return image
                }
            }
        }

        // PRIORITY 3: Try manufacturer default image
        // No more guessing filenames - if we don't have imagePath from catalog, go straight to default
        if let manufacturer = manufacturer,
           let defaultImageName = GlassManufacturers.defaultImageName(for: manufacturer) {
            let extensions = ["webp", "jpg", "jpeg", "png"]
            for ext in extensions {
                // Files in Molten/Resources/ are flattened to bundle root
                if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext),
                   let image = loadImageWithoutColorProfile(from: path) {
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
    nonisolated static func productImageExists(for itemCode: String, manufacturer: String? = nil) -> Bool {
        return loadProductImage(for: itemCode, manufacturer: manufacturer) != nil
    }

    nonisolated static func getProductImageName(for itemCode: String, manufacturer: String? = nil) -> String? {
        guard !itemCode.isEmpty else { return nil }

        // Check if we have permission to use product-specific images for this manufacturer
        // If not, skip directly to default manufacturer image
        if let manufacturer = manufacturer,
           !GlassManufacturers.hasProductImagePermission(for: manufacturer) {
            // No permission - use default manufacturer image only
            if let defaultImageName = GlassManufacturers.defaultImageName(for: manufacturer) {
                let extensions = ["webp", "jpg", "jpeg", "png", "PNG", "JPG", "JPEG", "WEBP"]
                for ext in extensions {
                    // Files in Molten/Resources/ are flattened to bundle root
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
                // Files in Molten/Resources/ are flattened to bundle root
                if let path = Bundle.main.path(forResource: defaultImageName, ofType: ext),
                   loadImageWithoutColorProfile(from: path) != nil {
                    return "\(defaultImageName).\(ext)"
                }
            }
        }

        return nil
    }

    // MARK: - User Image Support

    /// Clear cached image for an item (call after uploading new user image)
    nonisolated static func clearCache(for itemCode: String, manufacturer: String?) {
        let cacheKey = "\(manufacturer ?? "nil")-\(itemCode)"
        imageCache.removeObject(forKey: cacheKey as NSString)
        negativeCache.removeObject(forKey: cacheKey as NSString)
    }

    /// Clear all cached images (both positive and negative caches)
    /// Use this when image loading logic changes or new images are added to the bundle
    nonisolated static func clearAllCaches() {
        imageCache.removeAllObjects()
        negativeCache.removeAllObjects()
    }
}

struct ProductImageView: View {
    let itemCode: String
    let manufacturer: String?
    let stableId: String?
    let imagePath: String?
    let imageThumbPath: String?
    let dominantColors: [String]?
    let size: CGFloat

    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = true
    @State private var refreshTrigger: UUID = UUID()

    // CRITICAL: Shared repository instance (NOT created per view to avoid Core Data threading issues)
    private static let sharedUserImageRepository = AppDependencies.shared.userImageRepository

    init(itemCode: String, manufacturer: String? = nil, stableId: String? = nil, imagePath: String? = nil, imageThumbPath: String? = nil, dominantColors: [String]? = nil, size: CGFloat = 60) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
        self.stableId = stableId
        self.imagePath = imagePath
        self.imageThumbPath = imageThumbPath
        self.dominantColors = dominantColors
        self.size = size
    }

    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                // loadProductImageForDisplay always returns a usable image (product photo, gradient, or manufacturer logo)
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
                    .cornerRadius(8)
            } else {
                // Loading state or truly no image available
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay {
                        if isLoading && !DebugConfig.disableImageLoading {
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
        .onAppear {
            // Skip image loading if disabled via debug flag
            if DebugConfig.disableImageLoading {
                isLoading = false
                return
            }

            // Defer image loading slightly to allow UI to settle first
            // This prevents blocking the initial gesture response
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                await loadImageAsync()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userImageUploaded)) { notification in
            // Skip if image loading is disabled
            if DebugConfig.disableImageLoading {
                return
            }

            if let uploadedNaturalKey = notification.object as? String,
               uploadedNaturalKey == stableId {
                // Force refresh for this item
                loadedImage = nil
                isLoading = true
                Task {
                    await loadImageAsync()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .colorChipDisplayModeChanged)) { _ in
            // Skip if image loading is disabled
            if DebugConfig.disableImageLoading {
                return
            }

            // Reload image when color chip display mode changes
            loadedImage = nil
            isLoading = true
            Task {
                await loadImageAsync()
            }
        }
    }

    @MainActor
    private func loadImageAsync() async {
        isLoading = true

        // Use centralized image loading logic (single source of truth)
        loadedImage = await ImageHelpers.loadProductImageForDisplay(
            itemCode: itemCode,
            manufacturer: manufacturer,
            stableId: stableId,
            imagePath: imagePath,
            imageThumbPath: imageThumbPath,
            dominantColors: dominantColors
        )

        isLoading = false
    }
}

/// Product image detail view with upload and fullscreen capabilities
/// Uses centralized image loading logic from ImageHelpers
struct ProductImageDetail: View {
    let itemCode: String
    let manufacturer: String?
    let stableId: String?
    let imagePath: String?
    let imageThumbPath: String?
    let dominantColors: [String]?
    let maxSize: CGFloat
    let allowImageUpload: Bool
    let allowFullScreen: Bool
    let onImageUploaded: (() -> Void)?

    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = true
    @State private var showingFullScreen: Bool = false
    @State private var showingImagePicker: Bool = false
    @State private var showingUploadError: Bool = false
    @State private var uploadErrorMessage: String = ""

    // CRITICAL: Shared repository instance (NOT created per view to avoid Core Data threading issues)
    private static let sharedUserImageRepository = AppDependencies.shared.userImageRepository

    init(itemCode: String, manufacturer: String? = nil, stableId: String? = nil, imagePath: String? = nil, imageThumbPath: String? = nil, dominantColors: [String]? = nil, maxSize: CGFloat = 200, allowImageUpload: Bool = false, allowFullScreen: Bool = true, onImageUploaded: (() -> Void)? = nil) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
        self.stableId = stableId
        self.imagePath = imagePath
        self.imageThumbPath = imageThumbPath
        self.dominantColors = dominantColors
        self.maxSize = maxSize
        self.allowImageUpload = allowImageUpload
        self.allowFullScreen = allowFullScreen
        self.onImageUploaded = onImageUploaded
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Group {
                if let loadedImage = loadedImage {
                    // loadProductImageForDisplay always returns a usable image (product photo, gradient, or manufacturer logo)
                    let imageView = Image(uiImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: maxSize, maxHeight: maxSize)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                    if allowFullScreen {
                        imageView
                            .onTapGesture {
                                showingFullScreen = true
                            }
                    } else {
                        imageView
                    }
                } else {
                    // Loading state or truly no image available
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

            // Note: Image upload is now handled via the three-dot menu in inventory detail
            // The "Replace Image" button has been removed to save space
        }
        .task {
            // Skip image loading if disabled via debug flag
            if DebugConfig.disableImageLoading {
                isLoading = false
                return
            }

            await loadImageAsync()
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            if let loadedImage = loadedImage {
                FullScreenImageViewer(image: loadedImage, isPresented: $showingFullScreen)
            }
        }
        .alert("Image Upload Failed", isPresented: $showingUploadError) {
            Button("OK") { }
        } message: {
            Text(uploadErrorMessage)
        }
    }

    @MainActor
    private func loadImageAsync() async {
        isLoading = true

        // Use centralized image loading logic (single source of truth)
        loadedImage = await ImageHelpers.loadProductImageForDisplay(
            itemCode: itemCode,
            manufacturer: manufacturer,
            stableId: stableId,
            imagePath: imagePath,
            imageThumbPath: imageThumbPath,
            dominantColors: dominantColors
        )

        isLoading = false
    }

    @MainActor
    private func uploadImage(_ image: UIImage, for stableId: String) async {
        do {
            _ = try await Self.sharedUserImageRepository.saveImage(image, ownerType: .glassItem, ownerId: stableId, type: .primary)

            // Clear image cache for this item so it reloads with new image
            ImageHelpers.clearCache(for: itemCode, manufacturer: manufacturer)

            // Reload the image
            loadedImage = nil
            await loadImageAsync()

            // Notify callback
            onImageUploaded?()

            // Post notification so all ProductImageView instances reload
            NotificationCenter.default.post(name: .userImageUploaded, object: stableId)
        } catch {
            uploadErrorMessage = error.localizedDescription
            showingUploadError = true
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
    let stableId: String?
    let imagePath: String?
    let imageThumbPath: String?
    let dominantColors: [String]?
    let size: CGFloat

    init(itemCode: String, manufacturer: String? = nil, stableId: String? = nil, imagePath: String? = nil, imageThumbPath: String? = nil, dominantColors: [String]? = nil, size: CGFloat = 40) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
        self.stableId = stableId
        self.imagePath = imagePath
        self.imageThumbPath = imageThumbPath
        self.dominantColors = dominantColors
        self.size = size
    }

    var body: some View {
        #if canImport(UIKit)
        ProductImageView(itemCode: itemCode, manufacturer: manufacturer, stableId: stableId, imagePath: imagePath, imageThumbPath: imageThumbPath, dominantColors: dominantColors, size: size)
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
