//
//  ImageLoadingTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/9/25.
//

import Foundation
import UIKit
@testable import Molten

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

#if canImport(Testing)

@Suite("ImageLoading Tests")
struct ImageLoadingTests {
    
    @Test("sanitizeItemCodeForFilename should replace slashes with dashes")
    func testSanitizeItemCodeForFilename() throws {
        // Test forward slash replacement
        let forwardSlashResult = ImageHelpers.sanitizeItemCodeForFilename("CIM/101-A")
        #expect(forwardSlashResult == "CIM-101-A", "Should replace forward slashes with dashes")
        
        // Test backward slash replacement  
        let backwardSlashResult = ImageHelpers.sanitizeItemCodeForFilename("CIM\\101-B")
        #expect(backwardSlashResult == "CIM-101-B", "Should replace backward slashes with dashes")
        
        // Test mixed slashes
        let mixedSlashResult = ImageHelpers.sanitizeItemCodeForFilename("CIM/101\\C")
        #expect(mixedSlashResult == "CIM-101-C", "Should replace both slash types with dashes")
        
        // Test normal codes without slashes
        let normalResult = ImageHelpers.sanitizeItemCodeForFilename("CIM-101-D")
        #expect(normalResult == "CIM-101-D", "Should leave normal codes unchanged")
        
        // Test empty string
        let emptyResult = ImageHelpers.sanitizeItemCodeForFilename("")
        #expect(emptyResult == "", "Should handle empty strings")
    }
    
    @Test("loadProductImage should return nil for empty item codes")
    func testLoadProductImageEmptyCode() throws {
        // Act
        let result = ImageHelpers.loadProductImage(for: "", manufacturer: "CIM")
        
        // Assert
        #expect(result == nil, "Should return nil for empty item codes")
    }
    
    @Test("loadProductImage should return nil for non-existent images")
    func testLoadProductImageNonExistent() throws {
        // Act
        let result = ImageHelpers.loadProductImage(for: "NON_EXISTENT_CODE_12345", manufacturer: "TEST")
        
        // Assert
        #expect(result == nil, "Should return nil for non-existent images")
    }
    
    @Test("productImageExists should return false for empty item codes")
    func testProductImageExistsEmptyCode() throws {
        // Act
        let result = ImageHelpers.productImageExists(for: "", manufacturer: "CIM")
        
        // Assert
        #expect(result == false, "Should return false for empty item codes")
    }
    
    @Test("productImageExists should return false for non-existent images")
    func testProductImageExistsNonExistent() throws {
        // Act
        let result = ImageHelpers.productImageExists(for: "NON_EXISTENT_CODE_12345", manufacturer: "TEST")
        
        // Assert
        #expect(result == false, "Should return false for non-existent images")
    }
    
    @Test("getProductImageName should return nil for empty item codes")
    func testGetProductImageNameEmptyCode() throws {
        // Act
        let result = ImageHelpers.getProductImageName(for: "", manufacturer: "CIM")
        
        // Assert
        #expect(result == nil, "Should return nil for empty item codes")
    }
    
    @Test("getProductImageName should return nil for non-existent images")
    func testGetProductImageNameNonExistent() throws {
        // Act
        let result = ImageHelpers.getProductImageName(for: "NON_EXISTENT_CODE_12345", manufacturer: "TEST")
        
        // Assert
        #expect(result == nil, "Should return nil for non-existent images")
    }
    
    @Test("loadProductImage should handle manufacturer parameter consistently")
    func testLoadProductImageManufacturerHandling() throws {
        // Test with nil manufacturer
        let nilManufacturerResult = ImageHelpers.loadProductImage(for: "TEST-CODE", manufacturer: nil)
        // Should not crash and return nil for non-existent test image
        #expect(nilManufacturerResult == nil, "Should handle nil manufacturer gracefully")
        
        // Test with empty manufacturer
        let emptyManufacturerResult = ImageHelpers.loadProductImage(for: "TEST-CODE", manufacturer: "")
        // Should not crash and return nil for non-existent test image  
        #expect(emptyManufacturerResult == nil, "Should handle empty manufacturer gracefully")
    }
}

#endif
