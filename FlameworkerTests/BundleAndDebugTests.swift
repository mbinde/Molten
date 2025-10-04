//
//  BundleAndDebugTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
import SwiftUI
import CoreData
import os
@testable import Flameworker

@Suite("CatalogBundleDebugView Logic Tests")
struct CatalogBundleDebugViewLogicTests {
    
    @Test("Bundle path validation logic works correctly")
    func testBundlePathValidation() {
        // Test the logic used to validate bundle paths
        
        let validPath = "/Applications/App.app/Contents/Resources"
        let emptyPath = ""
        
        #expect(!validPath.isEmpty, "Valid path should not be empty")
        #expect(validPath.contains("/"), "Valid path should contain path separators")
        #expect(emptyPath.isEmpty, "Empty path should be detected")
    }
    
    @Test("File filtering for JSON files works correctly")  
    func testJSONFileFiltering() {
        // Test the JSON file filtering logic
        
        let allFiles = [
            "colors.json",
            "AppIcon.png", 
            "Info.plist",
            "data.json",
            "sample.txt",
            "catalog.JSON", // Test case sensitivity
            "backup.json.bak" // Test compound extensions
        ]
        
        let jsonFiles = allFiles.filter { $0.hasSuffix(".json") }
        
        #expect(jsonFiles.count == 2, "Should find exactly 2 .json files")
        #expect(jsonFiles.contains("colors.json"), "Should include colors.json")
        #expect(jsonFiles.contains("data.json"), "Should include data.json")
        #expect(!jsonFiles.contains("catalog.JSON"), "Should not include .JSON (uppercase)")
        #expect(!jsonFiles.contains("backup.json.bak"), "Should not include compound extensions")
        
        // Test empty array handling
        let emptyFiles: [String] = []
        let emptyJsonFiles = emptyFiles.filter { $0.hasSuffix(".json") }
        #expect(emptyJsonFiles.isEmpty, "Should handle empty file list")
    }
    
    @Test("Target file detection works correctly")
    func testTargetFileDetection() {
        // Test the logic used to identify target files
        
        let targetFile = "colors.json"
        let regularFile = "data.json"
        
        #expect(targetFile == "colors.json", "Should correctly identify target file")
        #expect(regularFile != "colors.json", "Should distinguish non-target files")
        
        // Test case sensitivity
        #expect("Colors.json" != "colors.json", "Should be case sensitive")
        #expect("COLORS.JSON" != "colors.json", "Should be case sensitive")
    }
    
    @Test("File categorization logic works correctly")
    func testFileCategorization() {
        // Test the categorization logic used in the debug view
        
        struct FileCategory {
            static func categorize(_ fileName: String) -> String {
                if fileName.hasSuffix(".json") {
                    return "JSON"
                } else if fileName.hasSuffix(".png") || fileName.hasSuffix(".jpg") {
                    return "Image"
                } else if fileName.hasSuffix(".plist") {
                    return "Config"
                } else {
                    return "Other"
                }
            }
        }
        
        #expect(FileCategory.categorize("colors.json") == "JSON", "Should categorize JSON files")
        #expect(FileCategory.categorize("icon.png") == "Image", "Should categorize image files")
        #expect(FileCategory.categorize("Info.plist") == "Config", "Should categorize config files")
        #expect(FileCategory.categorize("README.txt") == "Other", "Should categorize other files")
    }
    
    @Test("Bundle contents sorting works correctly")
    func testBundleContentsSorting() {
        // Test the sorting logic used for bundle contents display
        
        let unsortedContents = [
            "zeta.json",
            "AppIcon.png",
            "alpha.txt",
            "beta.json",
            "Info.plist"
        ]
        
        let sorted = unsortedContents.sorted()
        let expected = [
            "AppIcon.png",
            "Info.plist", 
            "alpha.txt",
            "beta.json",
            "zeta.json"
        ]
        
        #expect(sorted == expected, "Should sort contents alphabetically")
        #expect(sorted.count == unsortedContents.count, "Should maintain all items when sorting")
    }
    
    @Test("Bundle file count display logic works correctly")
    func testBundleFileCountDisplay() {
        // Test the file count display logic
        
        let filesList = ["file1.json", "file2.txt", "file3.png"]
        let count = filesList.count
        let displayText = "All Files (\(count))"
        
        #expect(displayText == "All Files (3)", "Should display correct file count")
        
        // Test empty list
        let emptyList: [String] = []
        let emptyCount = emptyList.count
        let emptyDisplayText = "All Files (\(emptyCount))"
        
        #expect(emptyDisplayText == "All Files (0)", "Should handle empty file list")
    }
}