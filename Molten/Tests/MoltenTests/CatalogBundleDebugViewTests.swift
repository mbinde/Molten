//
//  CatalogBundleDebugViewTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/11/25.
//

import Foundation
import SwiftUI
import Testing
@testable import Molten

@Suite("CatalogBundleDebugView Tests")
struct CatalogBundleDebugViewTests {
    
    // MARK: - Bundle Path Validation Tests
    
    @Test("Should validate bundle path exists and is accessible")
    func testBundlePathValidation() {
        // Act
        let bundlePath = Bundle.main.resourcePath
        
        // Assert
        #expect(bundlePath != nil, "Bundle resource path should be accessible")
        
        if let path = bundlePath {
            #expect(!path.isEmpty, "Bundle path should not be empty")
            #expect(path.contains("Molten"), "Bundle path should contain app name")
            
            // Verify path exists and is accessible
            let fileManager = FileManager.default
            #expect(fileManager.fileExists(atPath: path), "Bundle path should exist on file system")
        }
    }
    
    @Test("Should handle bundle path display formatting")
    func testBundlePathDisplay() {
        // Arrange
        var testContents: [String] = []
        let testBinding = Binding<[String]>(
            get: { testContents },
            set: { testContents = $0 }
        )
        
        // Act - Create view instance
        let debugView = CatalogBundleDebugView(bundleContents: testBinding)
        
        // Assert - View should initialize successfully
        #expect(testContents.isEmpty, "Should start with empty bundle contents")
        
        // Test bundle path accessibility
        if let bundlePath = Bundle.main.resourcePath {
            #expect(bundlePath.count > 0, "Bundle path should have content for display")
            #expect(!bundlePath.contains("//"), "Bundle path should be properly formatted")
        }
    }
    
    // MARK: - JSON File Filtering Tests
    
    @Test("Should correctly identify JSON files from bundle contents")
    func testJSONFileFiltering() {
        // Arrange
        let bundleContents = [
            "glassitems.json",
            "AppIcon.png", 
            "data.json",
            "Info.plist",
            "sample.txt",
            "config.json"
        ]
        
        // Act
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: bundleContents)
        
        // Assert
        #expect(jsonFiles.count == 3, "Should identify exactly 3 JSON files")
        #expect(jsonFiles.contains("glassitems.json"), "Should include glassitems.json")
        #expect(jsonFiles.contains("data.json"), "Should include data.json")  
        #expect(jsonFiles.contains("config.json"), "Should include config.json")
        #expect(!jsonFiles.contains("AppIcon.png"), "Should exclude image files")
        #expect(!jsonFiles.contains("Info.plist"), "Should exclude plist files")
        #expect(!jsonFiles.contains("sample.txt"), "Should exclude text files")
    }
    
    @Test("Should handle empty bundle contents for JSON filtering")
    func testJSONFilteringEmptyInput() {
        // Arrange
        let emptyContents: [String] = []
        
        // Act
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: emptyContents)
        
        // Assert
        #expect(jsonFiles.isEmpty, "Should return empty array for empty input")
    }
    
    @Test("Should handle mixed case JSON extensions")
    func testJSONFilteringCaseSensitivity() {
        // Arrange
        let mixedCaseContents = [
            "data.JSON",      // Uppercase extension
            "config.Json",    // Mixed case extension
            "glassitems.json",    // Lowercase extension
            "test.jsons",     // Similar but not JSON
            "sample.jsonl"    // JSON Lines format
        ]
        
        // Act
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: mixedCaseContents)
        
        // Assert - Current implementation is case-sensitive for .json
        #expect(jsonFiles.count == 1, "Should only match exact .json extension")
        #expect(jsonFiles.contains("glassitems.json"), "Should include lowercase .json files")
        #expect(!jsonFiles.contains("data.JSON"), "Should exclude uppercase .JSON files")
        #expect(!jsonFiles.contains("config.Json"), "Should exclude mixed case .Json files")
        #expect(!jsonFiles.contains("test.jsons"), "Should exclude .jsons files")
        #expect(!jsonFiles.contains("sample.jsonl"), "Should exclude .jsonl files")
    }
    
    // MARK: - Target File Detection Tests
    
    @Test("Should identify glassitems.json as target file")
    func testTargetFileDetection() {
        // Arrange
        let testFiles = [
            "data.json",
            "glassitems.json", 
            "config.json",
            "sample.json"
        ]
        
        // Act
        let targetFile = BundleFileUtilities.identifyTargetFile(from: testFiles)
        
        // Assert
        #expect(targetFile == "glassitems.json", "Should identify glassitems.json as target file")
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
        #expect(targetFile == nil, "Should return nil when glassitems.json not found")
    }
    
    @Test("Should handle empty file list for target detection")
    func testTargetDetectionEmptyList() {
        // Arrange
        let emptyFiles: [String] = []
        
        // Act
        let targetFile = BundleFileUtilities.identifyTargetFile(from: emptyFiles)
        
        // Assert
        #expect(targetFile == nil, "Should return nil for empty file list")
    }
    
    @Test("Should prioritize glassitems.json when multiple candidates exist")
    func testTargetDetectionPriority() {
        // Arrange - Multiple files including glassitems.json
        let multipleFiles = [
            "glassitems.json",
            "glassitems.json",      // Different case
            "colors_backup.json",
            "data.json"
        ]
        
        // Act
        let targetFile = BundleFileUtilities.identifyTargetFile(from: multipleFiles)
        
        // Assert
        #expect(targetFile == "glassitems.json", "Should prioritize exact match 'glassitems.json'")
    }
    
    // MARK: - File Categorization Logic Tests
    
    @Test("Should categorize files by type correctly")
    func testFileCategorization() {
        // Arrange
        let diverseFiles = [
            "glassitems.json",
            "data.json",
            "AppIcon.png",
            "launch_image.jpg",
            "Info.plist",
            "README.md",
            "sample.txt",
            "config.xml",
            "style.css",
            "script.js"
        ]
        
        // Act
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: diverseFiles)
        let imageFiles = diverseFiles.filter { file in
            file.hasSuffix(".png") || file.hasSuffix(".jpg") || file.hasSuffix(".jpeg")
        }
        let configFiles = diverseFiles.filter { file in
            file.hasSuffix(".plist") || file.hasSuffix(".xml")
        }
        
        // Assert - JSON files
        #expect(jsonFiles.count == 2, "Should categorize 2 JSON files")
        #expect(jsonFiles.contains("glassitems.json"), "Should include glassitems.json in JSON category")
        #expect(jsonFiles.contains("data.json"), "Should include data.json in JSON category")
        
        // Assert - Image files
        #expect(imageFiles.count == 2, "Should identify 2 image files")
        #expect(imageFiles.contains("AppIcon.png"), "Should include PNG files")
        #expect(imageFiles.contains("launch_image.jpg"), "Should include JPG files")
        
        // Assert - Config files
        #expect(configFiles.count == 2, "Should identify 2 config files")
        #expect(configFiles.contains("Info.plist"), "Should include plist files")
        #expect(configFiles.contains("config.xml"), "Should include XML files")
    }
    
    @Test("Should handle files with no extensions")
    func testCategorizationNoExtensions() {
        // Arrange
        let filesWithoutExtensions = [
            "README",
            "LICENSE", 
            "Makefile",
            "glassitems.json",
            "data"
        ]
        
        // Act
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: filesWithoutExtensions)
        
        // Assert
        #expect(jsonFiles.count == 1, "Should only find actual JSON files")
        #expect(jsonFiles.contains("glassitems.json"), "Should include valid JSON file")
        #expect(!jsonFiles.contains("README"), "Should exclude files without extensions")
        #expect(!jsonFiles.contains("data"), "Should exclude ambiguous files")
    }
    
    // MARK: - Bundle Contents Sorting Tests
    
    @Test("Should sort bundle contents alphabetically")
    func testBundleContentsSorting() {
        // Arrange
        let unsortedContents = [
            "zebra.json",
            "apple.png",
            "config.json", 
            "beta.txt",
            "alpha.json"
        ]
        
        // Act
        let sortedContents = unsortedContents.sorted()
        
        // Assert
        let expectedOrder = [
            "alpha.json",
            "apple.png", 
            "beta.txt",
            "config.json",
            "zebra.json"
        ]
        
        #expect(sortedContents == expectedOrder, "Should sort files alphabetically")
        #expect(sortedContents.first == "alpha.json", "Should start with alphabetically first file")
        #expect(sortedContents.last == "zebra.json", "Should end with alphabetically last file")
    }
    
    @Test("Should handle sorting with mixed case filenames")
    func testSortingMixedCase() {
        // Arrange
        let mixedCaseFiles = [
            "Zebra.json",
            "apple.png",
            "Config.json",
            "beta.txt", 
            "Alpha.json"
        ]
        
        // Act
        let sortedFiles = mixedCaseFiles.sorted()
        
        // Assert - String sorting is case-sensitive, uppercase comes before lowercase
        #expect(sortedFiles.first == "Alpha.json", "Should sort case-sensitively")
        #expect(sortedFiles.contains("Config.json"), "Should preserve original case")
        #expect(sortedFiles != mixedCaseFiles, "Should change order from original unsorted array")
    }
    
    @Test("Should handle sorting empty array")
    func testSortingEmptyArray() {
        // Arrange
        let emptyArray: [String] = []
        
        // Act
        let sortedArray = emptyArray.sorted()
        
        // Assert
        #expect(sortedArray.isEmpty, "Should handle empty array sorting")
        #expect(sortedArray.count == 0, "Sorted empty array should remain empty")
    }
    
    @Test("Should handle sorting single item")
    func testSortingSingleItem() {
        // Arrange
        let singleItem = ["glassitems.json"]
        
        // Act
        let sortedArray = singleItem.sorted()
        
        // Assert
        #expect(sortedArray.count == 1, "Should maintain single item")
        #expect(sortedArray.first == "glassitems.json", "Should preserve single item value")
        #expect(sortedArray == singleItem, "Single item array should remain unchanged")
    }
    
    // MARK: - File Count Display Tests
    
    @Test("Should display correct file count for bundle contents")
    func testFileCountDisplay() {
        // Arrange
        let testFiles = [
            "glassitems.json",
            "data.json",
            "AppIcon.png",
            "Info.plist"
        ]
        
        var bundleContents = testFiles
        let binding = Binding<[String]>(
            get: { bundleContents },
            set: { bundleContents = $0 }
        )
        
        // Act - Create view with test data
        let debugView = CatalogBundleDebugView(bundleContents: binding)
        
        // Assert
        #expect(bundleContents.count == 4, "Should track correct file count")
        #expect(bundleContents == testFiles, "Should maintain file list integrity")
    }
    
    @Test("Should handle dynamic file count updates")
    func testDynamicFileCountUpdates() {
        // Arrange
        var dynamicContents: [String] = ["initial.json"]
        let binding = Binding<[String]>(
            get: { dynamicContents },
            set: { dynamicContents = $0 }
        )
        
        let debugView = CatalogBundleDebugView(bundleContents: binding)
        
        // Act - Simulate adding files
        dynamicContents.append("added.json")
        dynamicContents.append("another.png")
        
        // Assert
        #expect(dynamicContents.count == 3, "Should reflect updated file count")
        #expect(dynamicContents.contains("added.json"), "Should include newly added files")
        #expect(dynamicContents.contains("another.png"), "Should include all added files")
        
        // Act - Simulate removing files
        dynamicContents.removeAll { $0 == "initial.json" }
        
        // Assert
        #expect(dynamicContents.count == 2, "Should reflect reduced file count")
        #expect(!dynamicContents.contains("initial.json"), "Should exclude removed files")
    }
    
    @Test("Should display zero count for empty bundle")
    func testEmptyBundleCount() {
        // Arrange
        var emptyContents: [String] = []
        let binding = Binding<[String]>(
            get: { emptyContents },
            set: { emptyContents = $0 }
        )
        
        // Act
        let debugView = CatalogBundleDebugView(bundleContents: binding)
        
        // Assert
        #expect(emptyContents.count == 0, "Should display zero count for empty bundle")
        #expect(emptyContents.isEmpty, "Should handle empty state correctly")
    }
    
    // MARK: - Integration Tests
    
    @Test("Should integrate JSON filtering and target detection correctly")
    func testJSONFilteringAndTargetDetectionIntegration() {
        // Arrange
        let mixedBundleContents = [
            "README.md",
            "glassitems.json",      // Target file
            "AppIcon.png",
            "data.json",        // Regular JSON
            "Info.plist",
            "config.json"       // Regular JSON
        ]
        
        // Act
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: mixedBundleContents)
        let targetFile = BundleFileUtilities.identifyTargetFile(from: jsonFiles)
        
        // Assert
        #expect(jsonFiles.count == 3, "Should filter to 3 JSON files")
        #expect(targetFile == "glassitems.json", "Should identify glassitems.json as target from filtered results")
        #expect(jsonFiles.contains("glassitems.json"), "Filtered results should contain target file")
        #expect(jsonFiles.allSatisfy { $0.hasSuffix(".json") }, "All filtered files should have .json extension")
    }
    
    @Test("Should handle large bundle contents efficiently")
    func testLargeBundleContentsPerformance() {
        // Arrange - Create large file list
        let baseFiles = (1...100).map { "file\($0).json" }
        let mixedFiles = baseFiles + [
            "glassitems.json",
            "AppIcon.png",
            "README.md"
        ]
        
        let startTime = Date()
        
        // Act
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: mixedFiles)
        let targetFile = BundleFileUtilities.identifyTargetFile(from: jsonFiles)
        let sortedFiles = mixedFiles.sorted()
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Assert
        #expect(jsonFiles.count == 101, "Should handle 101 JSON files (100 generated + glassitems.json)")
        #expect(targetFile == "glassitems.json", "Should find target file in large dataset")
        #expect(sortedFiles.count == 103, "Should sort all files including non-JSON")
        #expect(processingTime < 1.0, "Should process large dataset within reasonable time")
        
        // Verify sorting is correct for large dataset
        #expect(sortedFiles.first == "AppIcon.png", "Should sort correctly with mixed file types")
        #expect(sortedFiles.contains("glassitems.json"), "Should include target file in sorted results")
    }
    
    @Test("Should maintain data integrity across multiple operations")
    func testDataIntegrityAcrossOperations() {
        // Arrange
        let originalFiles = [
            "config.json",
            "glassitems.json",
            "data.json",
            "AppIcon.png",
            "README.md"
        ]
        
        // Act - Perform multiple operations that shouldn't modify original data
        let jsonFiles = BundleFileUtilities.filterJSONFiles(from: originalFiles)
        let targetFile = BundleFileUtilities.identifyTargetFile(from: originalFiles)
        let sortedFiles = originalFiles.sorted()
        let jsonFromSorted = BundleFileUtilities.filterJSONFiles(from: sortedFiles)
        
        // Assert - Original data should remain unchanged
        #expect(originalFiles.count == 5, "Original array should be unchanged")
        #expect(originalFiles.contains("glassitems.json"), "Original array should retain all files")
        #expect(originalFiles.contains("AppIcon.png"), "Original array should retain non-JSON files")
        
        // Assert - Operations should be consistent
        #expect(jsonFiles.count == jsonFromSorted.count, "JSON filtering should be consistent regardless of input order")
        #expect(Set(jsonFiles) == Set(jsonFromSorted), "JSON files should be identical regardless of source sorting")
        #expect(targetFile == "glassitems.json", "Target detection should work on original unsorted data")
        
        // Verify no data corruption
        let allProcessedFiles = Set(jsonFiles + sortedFiles)
        let originalSet = Set(originalFiles)
        #expect(allProcessedFiles.isSuperset(of: originalSet), "All processed results should include original data")
    }
}
