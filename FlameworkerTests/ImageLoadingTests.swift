//
//  ImageLoadingTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/3/25.
//

import Testing
import SwiftUI
@testable import Flameworker

@Suite("Image Loading Tests")
struct ImageLoadingTests {
    
    @Test("CIM-101 image file exists and is loadable")
    func testCIM101ImageExists() {
        let itemCode = "101"
        let manufacturer = "CIM"
        
        // Test that the image exists
        let imageExists = ImageHelpers.productImageExists(for: itemCode, manufacturer: manufacturer)
        #expect(imageExists == true, "CIM-101 image should exist in bundle")
        
        // Test that the image can be loaded
        let loadedImage = ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer)
        #expect(loadedImage != nil, "CIM-101 image should be loadable")
        
        // Test that we can get the image name
        let imageName = ImageHelpers.getProductImageName(for: itemCode, manufacturer: manufacturer)
        #expect(imageName != nil, "CIM-101 should have a valid image name")
        #expect(imageName?.contains("CIM") == true, "Image name should contain manufacturer code")
        #expect(imageName?.contains("101") == true, "Image name should contain item code")
    }
    
    @Test("Image loading handles missing images gracefully")
    func testMissingImageHandling() {
        let nonExistentCode = "NONEXISTENT999"
        let nonExistentManufacturer = "FAKE"
        
        // Test that non-existent image returns false
        let imageExists = ImageHelpers.productImageExists(for: nonExistentCode, manufacturer: nonExistentManufacturer)
        #expect(imageExists == false, "Non-existent image should return false")
        
        // Test that loading non-existent image returns nil
        let loadedImage = ImageHelpers.loadProductImage(for: nonExistentCode, manufacturer: nonExistentManufacturer)
        #expect(loadedImage == nil, "Non-existent image should return nil when loading")
        
        // Test that image name is nil for non-existent image
        let imageName = ImageHelpers.getProductImageName(for: nonExistentCode, manufacturer: nonExistentManufacturer)
        #expect(imageName == nil, "Non-existent image should have nil image name")
    }
    
    @Test("Image loading fallback logic works correctly")
    func testImageLoadingFallback() {
        let itemCode = "101"
        
        // Test with manufacturer first
        let imageWithManufacturer = ImageHelpers.productImageExists(for: itemCode, manufacturer: "CIM")
        
        // Test without manufacturer (fallback)
        let imageWithoutManufacturer = ImageHelpers.productImageExists(for: itemCode, manufacturer: nil)
        
        // At least one should work (preferably with manufacturer)
        let hasImage = imageWithManufacturer || imageWithoutManufacturer
        #expect(hasImage == true, "Should find image either with or without manufacturer")
        
        // If both exist, manufacturer version should be preferred
        if imageWithManufacturer && imageWithoutManufacturer {
            let nameWithMfg = ImageHelpers.getProductImageName(for: itemCode, manufacturer: "CIM")
            #expect(nameWithMfg?.contains("CIM") == true, "Should prefer manufacturer-prefixed version when available")
        }
    }
    
    @Test("Image sanitization works correctly")
    func testImageCodeSanitization() {
        // Test that problematic characters are sanitized
        let problematicCode = "ABC/123\\XYZ"
        let sanitized = ImageHelpers.sanitizeItemCodeForFilename(problematicCode)
        
        #expect(sanitized == "ABC-123-XYZ", "Should sanitize slashes to dashes")
        #expect(!sanitized.contains("/"), "Should not contain forward slashes")
        #expect(!sanitized.contains("\\"), "Should not contain backward slashes")
        
        // Test that the sanitized code could theoretically be used for image loading
        // (This doesn't guarantee the image exists, just that the code format is valid)
        #expect(!sanitized.isEmpty, "Sanitized code should not be empty")
        #expect(sanitized.count > 0, "Sanitized code should have content")
    }
    
    @Test("Common image file extensions are supported")
    func testCommonImageExtensions() {
        // Test that common image extensions work with the image loading system
        let itemCode = "101"
        let manufacturer = "CIM"
        
        // The system should handle various image formats
        // We don't know which format CIM-101 is in, but we know it should load
        let imageExists = ImageHelpers.productImageExists(for: itemCode, manufacturer: manufacturer)
        
        if imageExists {
            let imageName = ImageHelpers.getProductImageName(for: itemCode, manufacturer: manufacturer)
            #expect(imageName != nil, "Should get valid image name for existing image")
            
            // Check that the image name has a reasonable extension
            let hasImageExtension = imageName?.lowercased().hasSuffix(".jpg") == true ||
                                   imageName?.lowercased().hasSuffix(".jpeg") == true ||
                                   imageName?.lowercased().hasSuffix(".png") == true
            #expect(hasImageExtension, "Image should have a standard image file extension")
        }
    }
    
    @Test("Bundle image loading is thread-safe")
    func testBundleImageLoadingThreadSafety() async {
        let itemCode = "101"
        let manufacturer = "CIM"
        
        // Test concurrent image loading
        await withTaskGroup(of: Bool.self) { group in
            // Add multiple concurrent tasks
            for _ in 0..<5 {
                group.addTask {
                    let exists = ImageHelpers.productImageExists(for: itemCode, manufacturer: manufacturer)
                    let image = ImageHelpers.loadProductImage(for: itemCode, manufacturer: manufacturer)
                    
                    // Both should be consistent
                    if exists {
                        return image != nil
                    } else {
                        return image == nil
                    }
                }
            }
            
            // Collect all results
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            
            // All results should be consistent (all true)
            #expect(results.allSatisfy { $0 }, "Concurrent image loading should be consistent")
            #expect(results.count == 5, "Should have 5 concurrent results")
        }
    }
    
    @Test("Image helpers handle edge cases safely")
    func testImageHelpersEdgeCases() {
        // Test empty strings
        #expect(ImageHelpers.productImageExists(for: "", manufacturer: nil) == false, "Empty code should return false")
        #expect(ImageHelpers.loadProductImage(for: "", manufacturer: nil) == nil, "Empty code should return nil image")
        #expect(ImageHelpers.getProductImageName(for: "", manufacturer: nil) == nil, "Empty code should return nil name")
        
        // Test with empty manufacturer
        #expect(ImageHelpers.productImageExists(for: "101", manufacturer: "") == ImageHelpers.productImageExists(for: "101", manufacturer: nil), "Empty manufacturer should behave like nil")
        
        // Test with whitespace
        #expect(ImageHelpers.productImageExists(for: "   ", manufacturer: nil) == false, "Whitespace code should return false")
        #expect(ImageHelpers.productImageExists(for: "101", manufacturer: "   ") == ImageHelpers.productImageExists(for: "101", manufacturer: nil), "Whitespace manufacturer should behave like nil")
    }
    
    @Test("Bundle contains expected image directory structure")
    func testBundleImageStructure() {
        // Test that we can access bundle resources
        let bundle = Bundle.main
        #expect(bundle.bundlePath.count > 0, "Should have valid bundle path")
        
        // Test that we can get bundle contents
        let bundlePath = bundle.bundlePath
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: bundlePath)
            #expect(!contents.isEmpty, "Bundle should contain files")
            
            // Look for image files in bundle
            let imageFiles = contents.filter { fileName in
                fileName.lowercased().hasSuffix(".jpg") ||
                fileName.lowercased().hasSuffix(".jpeg") ||
                fileName.lowercased().hasSuffix(".png")
            }
            
            // We should have at least some image files (including CIM-101)
            #expect(!imageFiles.isEmpty, "Bundle should contain image files")
            
        } catch {
            #expect(false, "Should be able to read bundle contents: \(error)")
        }
    }
}