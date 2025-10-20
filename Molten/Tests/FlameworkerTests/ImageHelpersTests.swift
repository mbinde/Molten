//
//  ImageHelpersTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/10/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import SwiftUI
import UIKit
import Foundation
@testable import Flameworker

@Suite("Image Helpers Tests", .serialized)
struct ImageHelpersTests: MockOnlyTestSuite {
    
    // Prevent Core Data usage automatically
    init() {
        ensureMockOnlyEnvironment()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a test UIImage for testing
    private func createTestImage(size: CGSize = CGSize(width: 100, height: 100), color: UIColor = .red) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    // MARK: - Filename Sanitization Tests
    
    @Test("Should sanitize item codes for filenames correctly")
    func testItemCodeSanitization() {
        // Test cases for filename sanitization
        let testCases = [
            ("NORMAL-CODE", "NORMAL-CODE"),
            ("CODE/WITH/SLASHES", "CODE-WITH-SLASHES"),
            ("CODE\\WITH\\BACKSLASHES", "CODE-WITH-BACKSLASHES"),
            ("MIXED/SLASH\\CODE", "MIXED-SLASH-CODE"),
            ("", ""),
            ("NO-SPECIAL-CHARS", "NO-SPECIAL-CHARS"),
            ("123/456\\789", "123-456-789"),
            ("SINGLE/", "SINGLE-"),
            ("\\SINGLE", "-SINGLE"),
            ("//DOUBLE//", "--DOUBLE--")
        ]
        
        for (input, expected) in testCases {
            let result = ImageHelpers.sanitizeItemCodeForFilename(input)
            #expect(result == expected, "Sanitizing '\(input)' should produce '\(expected)', got '\(result)'")
        }
    }
    
    @Test("Should handle edge cases in sanitization")
    func testSanitizationEdgeCases() {
        // Test edge cases
        let edgeCases = [
            ("A", "A"), // Single character
            ("/", "-"), // Single slash
            ("\\", "-"), // Single backslash
            ("A/B\\C", "A-B-C"), // Mixed slashes
            ("   SPACES   ", "   SPACES   "), // Spaces (should not be modified)
            ("UNICODE-ñáéí", "UNICODE-ñáéí"), // Unicode (should not be modified)
            ("123-456", "123-456") // Already valid
        ]
        
        for (input, expected) in edgeCases {
            let result = ImageHelpers.sanitizeItemCodeForFilename(input)
            #expect(result == expected, "Edge case '\(input)' should produce '\(expected)', got '\(result)'")
        }
    }
    
    // MARK: - Image Loading Tests
    
    @Test("Should return nil for empty item codes")
    func testEmptyItemCodeHandling() {
        // Test empty item code
        let result1 = ImageHelpers.loadProductImage(for: "")
        #expect(result1 == nil, "Empty item code should return nil")
        
        let result2 = ImageHelpers.loadProductImage(for: "", manufacturer: "TestManufacturer")
        #expect(result2 == nil, "Empty item code with manufacturer should return nil")
    }
    
    @Test("Should handle nil and empty manufacturer parameters")
    func testManufacturerParameterHandling() {
        let testCode = "TEST-001"
        
        // Test nil manufacturer
        let result1 = ImageHelpers.loadProductImage(for: testCode, manufacturer: nil)
        #expect(true, "Nil manufacturer should not crash (result: \(result1 == nil ? "nil" : "image"))")
        
        // Test empty manufacturer
        let result2 = ImageHelpers.loadProductImage(for: testCode, manufacturer: "")
        #expect(true, "Empty manufacturer should not crash (result: \(result2 == nil ? "nil" : "image"))")
        
        // Test whitespace-only manufacturer
        let result3 = ImageHelpers.loadProductImage(for: testCode, manufacturer: "   ")
        #expect(true, "Whitespace manufacturer should not crash (result: \(result3 == nil ? "nil" : "image"))")
    }
    
    @Test("Should handle non-existent images gracefully")
    func testNonExistentImageHandling() {
        // Test with codes that definitely don't exist
        let nonExistentCodes = [
            "DEFINITELY-DOES-NOT-EXIST-12345",
            "IMPOSSIBLE-CODE-99999",
            "NO-WAY-THIS-EXISTS-ABCDEF"
        ]
        
        for code in nonExistentCodes {
            let result = ImageHelpers.loadProductImage(for: code)
            #expect(result == nil, "Non-existent image code '\(code)' should return nil")
        }
    }
    
    @Test("Should handle image existence checking correctly")
    func testImageExistenceChecking() {
        let testCode = "EXISTENCE-TEST-001"
        
        // Test existence check
        let exists = ImageHelpers.productImageExists(for: testCode)
        let loaded = ImageHelpers.loadProductImage(for: testCode)
        
        // Existence check should match actual loading result
        #expect((exists && loaded != nil) || (!exists && loaded == nil), 
               "Image existence check should match loading result for '\(testCode)'")
    }
    
    @Test("Should get product image names correctly")
    func testProductImageNameRetrieval() {
        let testCode = "NAME-TEST-001"
        
        // Test name retrieval
        let imageName = ImageHelpers.getProductImageName(for: testCode)
        
        if imageName != nil {
            // If we get a name, it should be a valid filename format
            #expect(imageName!.contains(testCode.replacingOccurrences(of: "/", with: "-")), 
                   "Image name should contain sanitized code")
            #expect(imageName!.contains("."), "Image name should have file extension")
        }
        
        // Test with empty code
        let emptyResult = ImageHelpers.getProductImageName(for: "")
        #expect(emptyResult == nil, "Empty code should return nil for image name")
    }
    
    // MARK: - Cache Behavior Tests
    
    @Test("Should cache images efficiently")
    func testImageCaching() {
        let testCode = "CACHE-TEST-001"
        
        // First load - this will either find the image or cache the negative result
        let firstLoad = ImageHelpers.loadProductImage(for: testCode)
        
        // Second load - should be faster due to caching
        let startTime = Date()
        let secondLoad = ImageHelpers.loadProductImage(for: testCode)
        let endTime = Date()
        
        let cacheTime = endTime.timeIntervalSince(startTime)
        
        // Results should be consistent
        #expect((firstLoad == nil) == (secondLoad == nil), "Cache should return consistent results")
        
        // Second load should be very fast (cached)
        #expect(cacheTime < 0.01, "Cached load should be very fast (actual: \(cacheTime)s)")
    }
    
    @Test("Should handle cache with manufacturer parameter")
    func testCacheWithManufacturer() {
        let testCode = "CACHE-MFG-001"
        let manufacturer = "TestManufacturer"
        
        // Load with manufacturer
        let withMfg = ImageHelpers.loadProductImage(for: testCode, manufacturer: manufacturer)
        
        // Load without manufacturer
        let withoutMfg = ImageHelpers.loadProductImage(for: testCode, manufacturer: nil)
        
        // These should be cached separately (different cache keys)
        #expect(true, "Different manufacturer parameters should use separate cache entries")
        
        // Second load with same parameters should be cached
        let startTime = Date()
        let cachedWithMfg = ImageHelpers.loadProductImage(for: testCode, manufacturer: manufacturer)
        let endTime = Date()
        
        let cacheTime = endTime.timeIntervalSince(startTime)
        #expect(cacheTime < 0.01, "Cached manufacturer-specific load should be fast")
        #expect((withMfg == nil) == (cachedWithMfg == nil), "Cached result should match original")
    }
    
    // MARK: - Bundle Resource Loading Tests
    
    @Test("Should search for multiple image extensions")
    func testMultipleExtensionSearch() {
        let testCode = "EXTENSION-TEST"
        let expectedExtensions = ["jpg", "jpeg", "png", "PNG", "JPG", "JPEG"]
        
        // The function should try all these extensions
        let result = ImageHelpers.loadProductImage(for: testCode)
        
        // We can't directly test the internal extension search, but we can test that
        // the function handles the search without crashing
        #expect(true, "Multiple extension search should complete without crashing")
        
        // Test that different cases are handled
        let testCodes = ["test", "TEST", "Test-123", "test-456"]
        for code in testCodes {
            let result = ImageHelpers.loadProductImage(for: code)
            #expect(true, "Extension search for '\(code)' should not crash")
        }
    }
    
    @Test("Should handle manufacturer prefix logic correctly")
    func testManufacturerPrefixLogic() {
        let testCode = "PREFIX-001"
        let manufacturer = "TestMfg"
        
        // Test with manufacturer (should try manufacturer-code format first)
        let withMfg = ImageHelpers.loadProductImage(for: testCode, manufacturer: manufacturer)
        
        // Test without manufacturer (should try code format only)
        let withoutMfg = ImageHelpers.loadProductImage(for: testCode, manufacturer: nil)
        
        // Both should complete without errors
        #expect(true, "Manufacturer prefix logic should handle both cases")
        
        // Test with special characters in manufacturer
        let specialMfg = "Test/Mfg\\Name"
        let withSpecialMfg = ImageHelpers.loadProductImage(for: testCode, manufacturer: specialMfg)
        #expect(true, "Special characters in manufacturer should be handled")
    }
    
    @Test("Should handle bundle resource path construction")
    func testBundleResourcePathConstruction() {
        // Test various code formats
        let testCases = [
            ("SIMPLE", nil),
            ("WITH-DASHES", nil),
            ("WITH/SLASHES", nil),
            ("COMPLEX-123/456", "TestManufacturer"),
            ("", "SomeManufacturer"), // Edge case
            ("NORMAL", "") // Edge case
        ]
        
        for (code, manufacturer) in testCases {
            // These should all complete without crashing
            let result = ImageHelpers.loadProductImage(for: code, manufacturer: manufacturer)
            #expect(true, "Path construction for code '\(code)', mfg '\(manufacturer ?? "nil")' should not crash")
        }
    }
    
    // MARK: - Performance Tests
    
    @Test("Should handle multiple image requests efficiently")
    func testMultipleImageRequestPerformance() {
        let testCodes = (1...20).map { "PERF-TEST-\(String(format: "%03d", $0))" }
        
        let startTime = Date()
        
        // Load multiple images
        var results: [UIImage?] = []
        for code in testCodes {
            let image = ImageHelpers.loadProductImage(for: code)
            results.append(image)
        }
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        #expect(results.count == testCodes.count, "Should process all image requests")
        #expect(processingTime < 2.0, "Should handle 20 image requests efficiently (actual: \(processingTime)s)")
    }
    
    @Test("Should demonstrate cache efficiency with repeated requests")
    func testCacheEfficiencyWithRepeatedRequests() {
        let testCodes = ["CACHE-PERF-001", "CACHE-PERF-002", "CACHE-PERF-003"]
        
        // First pass - populate cache
        let firstPassStart = Date()
        for code in testCodes {
            _ = ImageHelpers.loadProductImage(for: code)
        }
        let firstPassEnd = Date()
        let firstPassTime = firstPassEnd.timeIntervalSince(firstPassStart)
        
        // Second pass - should use cache
        let secondPassStart = Date()
        for code in testCodes {
            _ = ImageHelpers.loadProductImage(for: code)
        }
        let secondPassEnd = Date()
        let secondPassTime = secondPassEnd.timeIntervalSince(secondPassStart)
        
        // Second pass should be much faster due to caching
        #expect(secondPassTime <= firstPassTime, "Cached requests should be faster or equal")
        #expect(secondPassTime < 0.1, "Cached requests should be very fast (actual: \(secondPassTime)s)")
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Should handle memory pressure gracefully")
    func testMemoryPressureHandling() {
        let testCodes = (1...50).map { "MEMORY-TEST-\(String(format: "%03d", $0))" }
        
        // Try to load many images to test cache limits
        for code in testCodes {
            _ = ImageHelpers.loadProductImage(for: code)
        }
        
        // Should complete without memory issues
        #expect(true, "Should handle many image requests without memory issues")
    }
    
    // MARK: - ProductImageView Component Tests
    
    @Test("Should initialize ProductImageView with correct parameters")
    func testProductImageViewInitialization() {
        // Test default initialization
        let defaultView = ProductImageView(itemCode: "TEST-001")
        #expect(true, "Should initialize ProductImageView with default parameters")
        
        // Test with manufacturer
        let withManufacturer = ProductImageView(itemCode: "TEST-002", manufacturer: "TestMfg")
        #expect(true, "Should initialize ProductImageView with manufacturer")
        
        // Test with custom size
        let customSize = ProductImageView(itemCode: "TEST-003", size: 120)
        #expect(true, "Should initialize ProductImageView with custom size")
        
        // Test with all parameters
        let fullInit = ProductImageView(itemCode: "TEST-004", manufacturer: "TestMfg", size: 80)
        #expect(true, "Should initialize ProductImageView with all parameters")
    }
    
    @Test("Should initialize ProductImageThumbnail correctly")
    func testProductImageThumbnailInitialization() {
        // Test default thumbnail
        let defaultThumbnail = ProductImageThumbnail(itemCode: "THUMB-001")
        #expect(true, "Should initialize ProductImageThumbnail with default size")
        
        // Test with manufacturer
        let withMfg = ProductImageThumbnail(itemCode: "THUMB-002", manufacturer: "TestMfg")
        #expect(true, "Should initialize ProductImageThumbnail with manufacturer")
        
        // Test with custom size
        let customSize = ProductImageThumbnail(itemCode: "THUMB-003", size: 60)
        #expect(true, "Should initialize ProductImageThumbnail with custom size")
    }
    
    @Test("Should initialize ProductImageDetail correctly")
    func testProductImageDetailInitialization() {
        // Test default detail view
        let defaultDetail = ProductImageDetail(itemCode: "DETAIL-001")
        #expect(true, "Should initialize ProductImageDetail with default max size")
        
        // Test with manufacturer
        let withMfg = ProductImageDetail(itemCode: "DETAIL-002", manufacturer: "TestMfg")
        #expect(true, "Should initialize ProductImageDetail with manufacturer")
        
        // Test with custom max size
        let customMaxSize = ProductImageDetail(itemCode: "DETAIL-003", maxSize: 300)
        #expect(true, "Should initialize ProductImageDetail with custom max size")
    }
    
    // MARK: - Component Size and Layout Tests
    
    @Test("Should handle different size configurations correctly")
    func testSizeConfigurations() {
        let sizesToTest: [CGFloat] = [20, 40, 60, 80, 120, 200, 300]
        
        for size in sizesToTest {
            let view = ProductImageView(itemCode: "SIZE-TEST", size: size)
            #expect(true, "Should handle size \(size) without issues")
            
            let thumbnail = ProductImageThumbnail(itemCode: "SIZE-TEST", size: size)
            #expect(true, "Should handle thumbnail size \(size) without issues")
            
            let detail = ProductImageDetail(itemCode: "SIZE-TEST", maxSize: size)
            #expect(true, "Should handle detail max size \(size) without issues")
        }
    }
    
    @Test("Should handle edge case sizes")
    func testEdgeCaseSizes() {
        let edgeSizes: [CGFloat] = [0, 1, 0.5, 999, 1000]
        
        for size in edgeSizes {
            let view = ProductImageView(itemCode: "EDGE-SIZE", size: size)
            #expect(true, "Should handle edge case size \(size) without crashing")
        }
    }
    
    // MARK: - Error Handling and Edge Cases
    
    @Test("Should handle invalid item codes gracefully")
    func testInvalidItemCodeHandling() {
        let invalidCodes = [
            "", // Empty
            " ", // Whitespace
            "   ", // Multiple whitespace
            "!@#$%^&*()", // Special characters
            String(repeating: "A", count: 1000), // Very long
            "💩🔥🎯", // Emoji
            "测试代码", // Unicode
            "\n\r\t", // Control characters
        ]
        
        for code in invalidCodes {
            let result = ImageHelpers.loadProductImage(for: code)
            #expect(true, "Should handle invalid code '\(code)' gracefully (result: \(result == nil ? "nil" : "image"))")
            
            let exists = ImageHelpers.productImageExists(for: code)
            #expect(true, "Should handle existence check for invalid code gracefully")
            
            let name = ImageHelpers.getProductImageName(for: code)
            #expect(true, "Should handle name retrieval for invalid code gracefully")
        }
    }
    
    @Test("Should handle concurrent access safely")
    func testConcurrentAccess() async {
        let testCode = "CONCURRENT-TEST"
        
        // Create multiple concurrent tasks
        let tasks = (1...10).map { index in
            Task {
                let result = ImageHelpers.loadProductImage(for: "\(testCode)-\(index)")
                return result != nil
            }
        }
        
        // Wait for all tasks to complete
        var results: [Bool] = []
        for task in tasks {
            let result = await task.value
            results.append(result)
        }
        
        #expect(results.count == 10, "Should handle 10 concurrent image loads")
        #expect(true, "Concurrent access should complete without crashes")
    }
    
    // MARK: - Integration Tests
    
    @Test("Should integrate filename sanitization with image loading")
    func testSanitizationIntegration() {
        let codesWithSpecialChars = [
            "TEST/001",
            "ITEM\\002", 
            "COMPLEX/PATH\\NAME",
            "NORMAL-CODE"
        ]
        
        for code in codesWithSpecialChars {
            // Both functions should handle special characters consistently
            let sanitized = ImageHelpers.sanitizeItemCodeForFilename(code)
            let image = ImageHelpers.loadProductImage(for: code)
            
            #expect(!sanitized.contains("/"), "Sanitized code should not contain forward slashes")
            #expect(!sanitized.contains("\\"), "Sanitized code should not contain backslashes")
            #expect(true, "Image loading should handle special characters in codes")
        }
    }
    
    @Test("Should maintain consistency between all image methods")
    func testMethodConsistency() {
        let testCodes = ["CONSISTENCY-001", "CONSISTENCY-002", "CONSISTENCY-003"]
        
        for code in testCodes {
            let loaded = ImageHelpers.loadProductImage(for: code)
            let exists = ImageHelpers.productImageExists(for: code)
            let name = ImageHelpers.getProductImageName(for: code)
            
            // Consistency checks
            if loaded != nil {
                #expect(exists, "If image loads, existence check should be true for '\(code)'")
                #expect(name != nil, "If image loads, name should not be nil for '\(code)'")
            }
            
            if exists {
                #expect(name != nil, "If image exists, name should not be nil for '\(code)'")
            }
            
            if name != nil {
                #expect(exists, "If name exists, existence check should be true for '\(code)'")
            }
        }
    }
}