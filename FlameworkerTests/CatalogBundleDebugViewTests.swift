//  CatalogBundleDebugViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
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
import Foundation
@testable import Flameworker

@Suite("Catalog Bundle Debug View Tests", .serialized)
struct CatalogBundleDebugViewTests {
    
    // MARK: - JSON File Filtering Tests
    
    @Test("Should correctly identify JSON files from bundle contents")
    func testJSONFileFiltering() {
        // Arrange
        let bundleContents = [
            "colors.json",
            "AppIcon.png", 
            "data.json",
            "Info.plist",
            "sample.txt",
            "config.json"
        ]
        
        // Act
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: bundleContents)
        
        // Assert
        let expectedJSONFiles = ["colors.json", "data.json", "config.json"]
        #expect(jsonFiles.count == 3)
        #expect(jsonFiles.contains("colors.json"))
        #expect(jsonFiles.contains("data.json"))  
        #expect(jsonFiles.contains("config.json"))
        #expect(!jsonFiles.contains("AppIcon.png"))
        #expect(!jsonFiles.contains("Info.plist"))
        #expect(!jsonFiles.contains("sample.txt"))
    }
    
    // MARK: - Target File Detection Tests
    
    @Test("Should identify colors.json as target file")
    func testTargetFileDetection() {
        // Arrange
        let testFiles = [
            "data.json",
            "colors.json", 
            "config.json",
            "sample.json"
        ]
        
        // Act
        let targetFile = BundleFileUtilities.identifyTargetFile(from: testFiles)
        
        // Assert
        #expect(targetFile == "colors.json")
    }
    
    @Test("Should return nil when no target file exists")
    func testNoTargetFileDetection() {
        // Arrange
        let testFiles = [
            "data.json",
            "config.json",
            "sample.json"
        ]
        
        // Act
        let targetFile = BundleFileUtilities.identifyTargetFile(from: testFiles)
        
        // Assert
        #expect(targetFile == nil)
    }
}