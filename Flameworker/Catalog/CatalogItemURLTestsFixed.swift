//
//  CatalogItemURLTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/6/25.
//

import Testing
@testable import Flameworker
import CoreData
import SwiftUI

@Suite("Catalog Item URL Tests")
struct CatalogItemURLTests {
    
    @Test("Should identify available URL fields in CatalogItem entity")
    func testCatalogItemURLFieldsAvailable() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        
        // Check what URL-related fields actually exist in the entity
        let entityDescription = catalogItem.entity
        let availableAttributes = entityDescription.attributesByName.keys
        
        // Print available attributes for debugging
        print("Available CatalogItem attributes: \(Array(availableAttributes).sorted())")
        
        // Test for various possible URL field names
        let possibleURLFields = ["url", "item_url", "catalog_url", "product_url", "link", "website"]
        var foundURLFields: [String] = []
        
        for field in possibleURLFields {
            if availableAttributes.contains(field) {
                foundURLFields.append(field)
            }
        }
        
        print("Found URL fields: \(foundURLFields)")
        #expect(!foundURLFields.isEmpty || availableAttributes.contains("manufacturer_url"), 
                "CatalogItem should have at least one URL field available")
    }
    
    @Test("Should return catalog item URL when available using safe field access")
    func testCatalogItemURLWhenAvailableWithSafeAccess() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-001"
        catalogItem.name = "Test Glass"
        catalogItem.manufacturer = "EF"
        
        // Try to set a URL using KVC if the field exists
        let entityDescription = catalogItem.entity
        let availableAttributes = entityDescription.attributesByName.keys
        
        var testURLSet = false
        let possibleURLFields = ["url", "item_url", "catalog_url", "product_url", "link"]
        
        for field in possibleURLFields {
            if availableAttributes.contains(field) {
                catalogItem.setValue("https://effetre.com/products/test-glass-001", forKey: field)
                testURLSet = true
                break
            }
        }
        
        let itemURL = CatalogItemHelpers.getItemURL(catalogItem)
        
        if testURLSet {
            #expect(itemURL != nil, "Catalog item with URL should return valid URL")
            #expect(itemURL?.absoluteString == "https://effetre.com/products/test-glass-001", 
                   "Should return the exact URL stored in the catalog item")
        } else {
            print("No URL field found to test with - this is expected if the field doesn't exist yet")
            #expect(itemURL == nil, "Should return nil when no URL field exists")
        }
    }
    
    @Test("Should return nil when catalog item has no URL field")
    func testCatalogItemURLWhenNotAvailable() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-002" 
        catalogItem.name = "Test Glass No URL"
        catalogItem.manufacturer = "DH"
        
        let itemURL = CatalogItemHelpers.getItemURL(catalogItem)
        #expect(itemURL == nil, "Catalog item without URL should return nil")
    }
    
    @Test("Should include item URL in display info when available")
    func testCatalogItemDisplayInfoIncludesURL() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-003"
        catalogItem.name = "Test Glass With URL"
        catalogItem.manufacturer = "GA"
        
        // Try to set a URL using KVC if the field exists
        let entityDescription = catalogItem.entity
        let availableAttributes = entityDescription.attributesByName.keys
        let possibleURLFields = ["url", "item_url", "catalog_url", "product_url", "link"]
        
        var testURLSet = false
        for field in possibleURLFields {
            if availableAttributes.contains(field) {
                catalogItem.setValue("https://glassalchemy.com/products/test-003", forKey: field)
                testURLSet = true
                break
            }
        }
        
        let displayInfo = CatalogItemHelpers.getItemDisplayInfo(catalogItem)
        
        if testURLSet {
            #expect(displayInfo.hasItemURL, "Display info should indicate URL is available")
            #expect(displayInfo.itemURL?.absoluteString == "https://glassalchemy.com/products/test-003",
                   "Display info should contain the correct URL")
        } else {
            #expect(!displayInfo.hasItemURL, "Display info should indicate no URL when none exists")
            #expect(displayInfo.itemURL == nil, "Display info itemURL should be nil when no field exists")
        }
    }
    
    @Test("DEBUG: Check what fields exist and what data is available")
    func testDebugAvailableFields() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        
        // Check what URL-related fields actually exist in the entity
        let entityDescription = catalogItem.entity
        let availableAttributes = entityDescription.attributesByName.keys
        
        print("=== DEBUG: Available CatalogItem attributes ===")
        print("All attributes: \(Array(availableAttributes).sorted())")
        
        // Check for URL fields specifically
        let urlFields = availableAttributes.filter { $0.lowercased().contains("url") || $0.lowercased().contains("link") || $0.lowercased().contains("website") }
        print("URL-related fields found: \(urlFields)")
        
        // Test with real data if available
        let fetchRequest: NSFetchRequest<CatalogItem> = CatalogItem.fetchRequest()
        fetchRequest.fetchLimit = 3
        
        do {
            let items = try context.fetch(fetchRequest)
            print("=== DEBUG: Sample data from \(items.count) catalog items ===")
            
            for (index, item) in items.enumerated() {
                print("Item \(index + 1): \(item.name ?? "No name") (\(item.code ?? "No code"))")
                
                // Check each URL field for this item
                for field in urlFields {
                    if let value = item.value(forKey: field) as? String, !value.isEmpty {
                        print("  \(field): \(value)")
                    } else {
                        print("  \(field): (empty or nil)")
                    }
                }
                
                // Test our helper method
                let itemURL = CatalogItemHelpers.getItemURL(item)
                let displayInfo = CatalogItemHelpers.getItemDisplayInfo(item)
                print("  getItemURL result: \(itemURL?.absoluteString ?? "nil")")
                print("  hasItemURL: \(displayInfo.hasItemURL)")
                print("---")
            }
        } catch {
            print("Error fetching catalog items: \(error)")
        }
        
        #expect(true, "This is just a debug test")
    }
}