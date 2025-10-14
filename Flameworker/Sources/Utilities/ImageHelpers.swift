//
//  ImageHelpers.swift
//  Flameworker
//
//  Created by Assistant on 10/01/25.
//

import SwiftUI
import UIKit
import ImageIO

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
    /// Images are expected to be in the Data/product-images/ folder
    /// Format: manufacturer-itemcode.jpg (e.g., "CiM-511101.jpg")
    /// Item codes with slashes (/) or backslashes (\) will have them replaced with dashes (-) for the filename
    /// - Parameters:
    ///   - itemCode: The code to use for the image filename
    ///   - manufacturer: The manufacturer short name (optional, will try both formats)
    /// - Returns: UIImage if found, nil otherwise
    static func loadProductImage(for itemCode: String, manufacturer: String? = nil) -> UIImage? {
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
        
        let sanitizedCode = sanitizeItemCodeForFilename(itemCode)
        
        // Common image extensions to try
        let extensions = ["jpg", "jpeg", "png", "PNG", "JPG", "JPEG"]
        
        // Try with manufacturer prefix first if provided
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            let sanitizedManufacturer = sanitizeItemCodeForFilename(manufacturer)
            for ext in extensions {
                let imageName = "\(productImagePathPrefix)\(sanitizedManufacturer)-\(sanitizedCode)"
                
                // Try bundle file with color profile handling
                if let path = Bundle.main.path(forResource: imageName, ofType: ext),
                   let image = loadImageWithoutColorProfile(from: path) {
                    // Cache the successful result
                    imageCache.setObject(image, forKey: cacheKeyNS)
                    return image
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
        let sanitizedCode = sanitizeItemCodeForFilename(itemCode)
        let extensions = ["jpg", "jpeg", "png", "PNG", "JPG", "JPEG"]
        
        // Try with manufacturer prefix first if provided
        if let manufacturer = manufacturer, !manufacturer.isEmpty {
            let sanitizedManufacturer = sanitizeItemCodeForFilename(manufacturer)
            for ext in extensions {
                let imageName = "\(productImagePathPrefix)\(sanitizedManufacturer)-\(sanitizedCode)"
                
                // Try bundle file for existence check
                if let path = Bundle.main.path(forResource: imageName, ofType: ext),
                   loadImageWithoutColorProfile(from: path) != nil {
                    return "\(imageName).\(ext)"
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
        
        return nil
    }
}

struct ProductImageView: View {
    let itemCode: String
    let manufacturer: String?
    let size: CGFloat
    
    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = true
    
    init(itemCode: String, manufacturer: String? = nil, size: CGFloat = 60) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
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
        .task {
            await loadImageAsync()
        }
    }
    
    @MainActor
    private func loadImageAsync() async {
        // Don't reload if we already have an image
        guard loadedImage == nil else { return }
        
        // Load image on background queue to prevent main thread blocking
        let image = await Task.detached(priority: .utility) {
            ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer)
        }.value
        
        loadedImage = image
        isLoading = false
    }
}

struct ProductImageThumbnail: View {
    let itemCode: String
    let manufacturer: String?
    let size: CGFloat
    
    init(itemCode: String, manufacturer: String? = nil, size: CGFloat = 40) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
        self.size = size
    }
    
    var body: some View {
        ProductImageView(itemCode: itemCode, manufacturer: manufacturer, size: size)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
    }
}

struct ProductImageDetail: View {
    let itemCode: String
    let manufacturer: String?
    let maxSize: CGFloat
    
    @State private var loadedImage: UIImage?
    @State private var isLoading: Bool = true
    
    init(itemCode: String, manufacturer: String? = nil, maxSize: CGFloat = 200) {
        self.itemCode = itemCode
        self.manufacturer = manufacturer
        self.maxSize = maxSize
    }
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: maxSize, maxHeight: maxSize)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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
        .task {
            await loadImageAsync()
        }
    }
    
    @MainActor
    private func loadImageAsync() async {
        // Don't reload if we already have an image
        guard loadedImage == nil else { return }
        
        // Load image on background queue to prevent main thread blocking
        let image = await Task.detached(priority: .utility) {
            ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer)
        }.value
        
        loadedImage = image
        isLoading = false
    }
}
