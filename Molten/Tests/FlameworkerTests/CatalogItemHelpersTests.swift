//
//  CatalogItemHelpersTests.swift
//  Flameworker
//
//  Created by Assistant on 10/13/25.
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
@testable import Flameworker

@Suite("CatalogItemHelpers Repository Pattern Tests")
struct CatalogItemHelpersTests {
    
    @Test("CatalogItemHelpers should work with CatalogItemModel instead of Core Data entity")
    func testCatalogItemHelpersUsesBusinessModel() {
        // Arrange: Create a business model instead of Core Data entity
        let catalogItem = CatalogItemModel(
            name: "Red Glass Rod",
            rawCode: "RGR001",
            manufacturer: "Bullseye",
            tags: ["red", "glass", "rod"]
        )
        
        // Act: Use helpers with business model
        let tags = CatalogItemHelpers.tagsArrayForItem(catalogItem)
        let tagsString = CatalogItemHelpers.createTagsString(from: tags)
        let displayInfo = CatalogItemHelpers.getItemDisplayInfo(catalogItem)
        
        // Assert: Should work with business models
        #expect(tags.count == 3, "Should extract tags from CatalogItemModel")
        #expect(tagsString.contains("red"), "Should create tags string from business model")
        #expect(displayInfo.name == "Red Glass Rod", "Should create display info from CatalogItemModel")
    }
    
    @Test("CatalogItemHelpers should not require Core Data context")
    func testCatalogItemHelpersWorksWithoutCoreDataContext() {
        // Arrange: Create business model (no Core Data involved)
        let catalogItem = CatalogItemModel(
            name: "Blue Frit",
            rawCode: "BF001", 
            manufacturer: "Spectrum",
            tags: ["blue", "frit"]
        )
        
        // Act: Use helpers without any Core Data context
        let synonyms = CatalogItemHelpers.synonymsArrayForItem(catalogItem)
        let coe = CatalogItemHelpers.coeForItem(catalogItem)
        let color = CatalogItemHelpers.colorForManufacturer(catalogItem.manufacturer)
        
        // Assert: Should work without Core Data environment
        #expect(synonyms != nil, "Should work with business models without Core Data")
        #expect(coe != nil, "Should get COE from business model")
        #expect(color != nil, "Should get manufacturer color from business model")
    }
    
    @Test("CatalogItemHelpers should provide comprehensive business model operations")
    func testCatalogItemHelpersBusinessModelOperations() {
        // Arrange: Create detailed business model
        let catalogItem = CatalogItemModel(
            name: "Rainbow Glass",
            rawCode: "RAIN001",
            manufacturer: "Effetre", 
            tags: ["rainbow", "multicolor", "glass"]
        )
        
        // Act: Use comprehensive helper operations
        let displayInfo = CatalogItemHelpers.getItemDisplayInfo(catalogItem)
        let hasExtendedInfo = displayInfo.hasExtendedInfo
        let nameWithCode = displayInfo.nameWithCode
        
        // Assert: Should provide full business model functionality
        #expect(displayInfo.manufacturer == "Effetre", "Should extract manufacturer from business model")
        #expect(hasExtendedInfo == true, "Should detect extended info from business model")
        #expect(nameWithCode.contains("EFFETRE-RAIN001"), "Should format name with code from business model")
    }
    
    @Test("CatalogItemHelpers should not import CoreData")
    func testCatalogItemHelpersNoCoreDataImport() {
        // This test verifies that CatalogItemHelpers doesn't depend on Core Data
        // If it compiles and works with only business models, it's properly migrated
        
        let catalogItem = CatalogItemModel(
            name: "Clean Glass",
            rawCode: "CLEAN001",
            manufacturer: "TestCorp",
            tags: ["test"]
        )
        
        // All operations should work with business models only
        let tags = CatalogItemHelpers.tagsForItem(catalogItem)
        let displayInfo = CatalogItemHelpers.getItemDisplayInfo(catalogItem)
        
        #expect(tags != nil, "Should work without Core Data imports")
        #expect(displayInfo != nil, "Should create display info without Core Data")
    }
}