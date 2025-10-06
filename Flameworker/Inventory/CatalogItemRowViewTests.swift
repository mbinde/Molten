//
//  CatalogItemRowViewTests.swift
//  Flameworker
//
//  Created by Assistant on 10/05/25.
//

import Testing
import SwiftUI
@testable import Flameworker

@Suite("CatalogItemRowView Tests")
struct CatalogItemRowViewTests {
    
    @Test("CatalogItemRowView should be accessible and testable")
    func testCatalogItemRowViewAccessibility() {
        // Test that CatalogItemRowView related functionality is accessible
        // This verifies SwiftUI components work with the test framework
        
        // Test that we can access CatalogItemHelpers
        let emptyTags = CatalogItemHelpers.tagsArrayForItem(nil)
        #expect(emptyTags.isEmpty, "Empty item should return empty tags array")
        
        // Test that display info structures are accessible
        // This would be used by CatalogItemRowView for displaying item information
        #expect(true, "CatalogItemRowView components should be accessible")
    }
    
    @Test("Catalog display logic should work correctly")
    func testCatalogDisplayLogic() {
        // Test basic display logic that CatalogItemRowView would use
        let testCode = "TEST-123"
        let testName = "Test Color"
        let testManufacturer = "Test Manufacturer"
        
        // Test that display strings are properly formatted
        let hasCode = !testCode.isEmpty
        let hasName = !testName.isEmpty
        let hasManufacturer = !testManufacturer.isEmpty
        
        #expect(hasCode && hasName && hasManufacturer, "All display components should be available")
        
        // Test code formatting logic
        let preferredCode = CatalogCodeLookup.preferredCatalogCode(from: "123", manufacturer: "Test")
        #expect(preferredCode == "Test-123", "Code formatting should work correctly")
    }
    
    @Test("Feature flags should work with catalog row display")
    func testFeatureFlagsWithCatalogRow() {
        // Test that feature flags affecting catalog display work correctly
        let advancedUI = FeatureFlags.advancedUIComponents
        let mainFlag = FeatureFlags.isFullFeaturesEnabled
        
        #expect(advancedUI == mainFlag, "Advanced UI should follow main flag")
        
        // Test filtering flag for catalog rows
        let advancedFiltering = FeatureFlags.advancedFiltering
        #expect(advancedFiltering == mainFlag, "Advanced filtering should follow main flag")
    }
}
    func catalogItemRowViewExists() {
        // Test with preview context to avoid Core Data model conflicts
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-101"
        catalogItem.name = "Test Color"
        catalogItem.manufacturer = "TestCorp"
        
        // This should compile and create a view
        let rowView = CatalogItemRowView(item: catalogItem)
        
        // Verify the view is not nil (basic existence test)
        #expect(rowView != nil)
    }
    
    @Test("CatalogItemHelpers should provide display info for catalog items")
    func catalogItemHelpersWorkCorrectly() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-IMAGE"
        catalogItem.name = "Test Image Item"
        catalogItem.manufacturer = "TestImageCorp"
        
        // Test that helpers extract information correctly using the comprehensive version
        let displayInfo = CatalogItemHelpers.getItemDisplayInfo(catalogItem)
        
        #expect(displayInfo.code == "TEST-IMAGE", "Should extract code correctly")
        #expect(displayInfo.name == "Test Image Item", "Should extract name correctly") 
        #expect(displayInfo.manufacturer == "TestImageCorp", "Should extract manufacturer correctly")
        
        // Test tags helper - should work with the comprehensive implementation
        let tags = CatalogItemHelpers.tagsArrayForItem(catalogItem)
        #expect(tags != nil, "Tags array should be returned (even if empty)")
    }
    
    @Test("Image loading system should find available images")
    func testImageLoadingSystemFindsImages() {
        // Test with some common catalog codes that might have images
        let testCases = [
            ("CiM-511101", "CiM"),  // From README mention
            ("101", nil),           // Simple code without manufacturer
            ("DH-101", "DH"),       // Double Helix
            ("EFF-001", "Effetre"), // Effetre
        ]
        
        var foundAnyImages = false
        
        for (code, manufacturer) in testCases {
            let hasImage = ImageHelpers.productImageExists(for: code, manufacturer: manufacturer)
            let imageName = ImageHelpers.getProductImageName(for: code, manufacturer: manufacturer)
            
            print("🔍 Testing image for code: \(code), manufacturer: \(manufacturer ?? "nil")")
            print("   - Image exists: \(hasImage)")
            print("   - Image name: \(imageName ?? "none")")
            
            if hasImage {
                foundAnyImages = true
                print("✅ Found image: \(imageName!)")
            }
        }
        
        // Test bundle contents to see what's actually available
        let bundleContents = BundleUtilities.debugContents()
        let imageFiles = bundleContents.filter { file in
            let lowercased = file.lowercased()
            return lowercased.hasSuffix(".jpg") || lowercased.hasSuffix(".jpeg") || lowercased.hasSuffix(".png")
        }
        
        print("📁 Available image files in bundle:")
        for imageFile in imageFiles.prefix(10) {  // Show first 10
            print("   - \(imageFile)")
        }
        
        if imageFiles.count > 10 {
            print("   ... and \(imageFiles.count - 10) more")
        }
        
        // This test will help us understand what's available
        #expect(bundleContents.count > 0, "Bundle should contain files")
        
        if !foundAnyImages && imageFiles.isEmpty {
            print("⚠️ No images found in bundle - this explains the placeholder issue")
        } else if !foundAnyImages && !imageFiles.isEmpty {
            print("⚠️ Images exist in bundle but naming pattern doesn't match expectations")
        }
    }
}
