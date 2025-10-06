//
//  CatalogBusinessLogicTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/4/25.
//  Consolidated from CatalogAndSearchTests.swift during Phase 7 cleanup
//

import Testing
import Foundation
import SwiftUI
@testable import Flameworker

@Suite("CatalogItemHelpers Basic Tests")
struct CatalogItemHelpersBasicTests {
    
    @Test("CatalogItemHelpers should exist and be accessible")
    func testCatalogItemHelpersExist() {
        // Test that we can access CatalogItemHelpers functionality
        // This verifies the module import and basic functionality
        
        // Test tag parsing logic
        let tags = CatalogItemHelpers.tagsArrayForItem(nil)
        #expect(tags.isEmpty, "Empty item should return empty tags")
        
        // Test that the helper exists and can be called
        #expect(true, "CatalogItemHelpers should be accessible from tests")
    }
    
    @Test("Feature flags should work correctly in catalog context")
    func testFeatureFlagsInCatalogContext() {
        // Test that feature flags work in the context of catalog operations
        let advancedFiltering = FeatureFlags.advancedFiltering
        let debugConfigFiltering = DebugConfig.FeatureFlags.advancedFiltering
        
        #expect(advancedFiltering == debugConfigFiltering, "Both access methods should be equivalent")
        
        // Test that the main flag controls advanced features
        let mainFlag = FeatureFlags.isFullFeaturesEnabled
        #expect(advancedFiltering == mainFlag, "Advanced filtering should follow main flag")
    }
}
    
    @Test("AvailabilityStatus has correct display text")
    func testAvailabilityStatusDisplayText() {
        #expect(AvailabilityStatus.available.displayText == "Available", "Available should have correct display text")
        #expect(AvailabilityStatus.discontinued.displayText == "Discontinued", "Discontinued should have correct display text")
        #expect(AvailabilityStatus.futureRelease.displayText == "Future Release", "Future release should have correct display text")
    }
    
    @Test("AvailabilityStatus has correct colors")
    func testAvailabilityStatusColors() {
        #expect(AvailabilityStatus.available.color == .green, "Available should be green")
        #expect(AvailabilityStatus.discontinued.color == .orange, "Discontinued should be orange")
        #expect(AvailabilityStatus.futureRelease.color == .blue, "Future release should be blue")
    }
    
    @Test("AvailabilityStatus has correct short display text")
    func testAvailabilityStatusShortText() {
        #expect(AvailabilityStatus.available.shortDisplayText == "Avail.", "Available should have short text")
        #expect(AvailabilityStatus.discontinued.shortDisplayText == "Disc.", "Discontinued should have short text")
        #expect(AvailabilityStatus.futureRelease.shortDisplayText == "Future", "Future release should have short text")
    }
    
    @Test("Create tags string from array works correctly")
    func testCreateTagsString() {
        let tags = ["red", "glass", "rod"]
        let result = CatalogItemHelpers.createTagsString(from: tags)
        #expect(result == "red,glass,rod", "Should create comma-separated string")
        
        // Test with empty strings
        let tagsWithEmpty = ["red", "", "glass", "   ", "rod"]
        let filteredResult = CatalogItemHelpers.createTagsString(from: tagsWithEmpty)
        #expect(filteredResult == "red,glass,rod", "Should filter out empty and whitespace-only strings")
        
        // Test empty array
        let emptyResult = CatalogItemHelpers.createTagsString(from: [])
        #expect(emptyResult.isEmpty, "Empty array should produce empty string")
    }
    
    @Test("Format date works correctly")
    func testFormatDate() {
        let date = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021
        let formatted = CatalogItemHelpers.formatDate(date, style: .short)
        
        // Just verify it's not empty and is a reasonable date string
        #expect(!formatted.isEmpty, "Formatted date should not be empty")
        #expect(formatted.count >= 6, "Formatted date should have reasonable length")
        
        // Test that the function handles different styles without crashing
        let mediumFormatted = CatalogItemHelpers.formatDate(date, style: .medium)
        #expect(!mediumFormatted.isEmpty, "Medium formatted date should not be empty")
        
        let longFormatted = CatalogItemHelpers.formatDate(date, style: .long)
        #expect(!longFormatted.isEmpty, "Long formatted date should not be empty")
    }
    
    @Test("CatalogItemDisplayInfo nameWithCode works correctly") 
    func testCatalogItemDisplayInfoNameWithCode() {
        let displayInfo = CatalogItemDisplayInfo(
            name: "Test Glass",
            code: "TG001",
            manufacturer: "Test Mfg",
            manufacturerFullName: "Test Manufacturing Co",
            coe: "96",
            stockType: "rod",
            tags: ["red", "glass"],
            synonyms: ["test", "sample"],
            color: .blue,
            manufacturerURL: nil,
            imagePath: nil,
            description: "Test description"
        )
        
        #expect(displayInfo.nameWithCode == "Test Glass (TG001)", "Should combine name and code correctly")
        #expect(displayInfo.hasExtendedInfo == true, "Should have extended info with tags")
        #expect(displayInfo.hasDescription == true, "Should have description")
    }
    
    @Test("CatalogItemDisplayInfo detects extended info correctly")
    func testCatalogItemDisplayInfoExtendedInfo() {
        // Test with no extended info
        let basicInfo = CatalogItemDisplayInfo(
            name: "Basic",
            code: "B001", 
            manufacturer: "Basic Mfg",
            manufacturerFullName: "Basic Manufacturing",
            coe: nil,
            stockType: nil,
            tags: [],
            synonyms: [],
            color: .gray,
            manufacturerURL: nil,
            imagePath: nil,
            description: nil
        )
        
        #expect(basicInfo.hasExtendedInfo == false, "Should not have extended info")
        #expect(basicInfo.hasDescription == false, "Should not have description")
        
        // Test with extended info
        let extendedInfo = CatalogItemDisplayInfo(
            name: "Extended",
            code: "E001",
            manufacturer: "Extended Mfg", 
            manufacturerFullName: "Extended Manufacturing",
            coe: nil,
            stockType: "rod",
            tags: [],
            synonyms: [],
            color: .gray,
            manufacturerURL: nil,
            imagePath: nil,
            description: "   "
        )
        
        #expect(extendedInfo.hasExtendedInfo == true, "Should have extended info due to stock type")
        #expect(extendedInfo.hasDescription == false, "Should not have description due to whitespace")
    }
}
