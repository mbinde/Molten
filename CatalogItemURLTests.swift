//
//  CatalogItemURLTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/6/25.
//

import Testing
@testable import Flameworker
import CoreData

@Suite("Catalog Item URL Tests")
struct CatalogItemURLTests {
    
    @Test("Should return catalog item URL when available")
    func testCatalogItemURLWhenAvailable() {
        // Create a mock catalog item with a URL
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-001"
        catalogItem.name = "Test Glass"
        catalogItem.manufacturer = "EF"
        catalogItem.url = "https://effetre.com/products/test-glass-001"
        
        let itemURL = CatalogItemHelpers.getItemURL(catalogItem)
        #expect(itemURL != nil, "Catalog item with URL should return valid URL")
        #expect(itemURL?.absoluteString == "https://effetre.com/products/test-glass-001", "Should return the exact URL stored in the catalog item")
    }
    
    @Test("Should return nil when catalog item has no URL")
    func testCatalogItemURLWhenNotAvailable() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-002"
        catalogItem.name = "Test Glass No URL"
        catalogItem.manufacturer = "DH"
        catalogItem.url = nil
        
        let itemURL = CatalogItemHelpers.getItemURL(catalogItem)
        #expect(itemURL == nil, "Catalog item without URL should return nil")
    }
    
    @Test("Should return nil for empty URL string")
    func testCatalogItemURLForEmptyString() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-003"
        catalogItem.name = "Test Glass Empty URL"
        catalogItem.manufacturer = "CiM"
        catalogItem.url = ""
        
        let itemURL = CatalogItemHelpers.getItemURL(catalogItem)
        #expect(itemURL == nil, "Catalog item with empty URL string should return nil")
    }
    
    @Test("Should validate URL format")
    func testCatalogItemURLValidation() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-004"
        catalogItem.name = "Test Glass Valid URL"
        catalogItem.manufacturer = "GA"
        catalogItem.url = "https://glassalchemy.com/products/test-004"
        
        let itemURL = CatalogItemHelpers.getItemURL(catalogItem)
        if let url = itemURL {
            #expect(url.scheme == "https", "Catalog item URL should use HTTPS")
            #expect(!url.host!.isEmpty, "Catalog item URL should have a valid host")
        }
    }
    
    @Test("Should handle malformed URLs gracefully")
    func testCatalogItemURLMalformed() {
        let context = PersistenceController.preview.container.viewContext
        let catalogItem = CatalogItem(context: context)
        catalogItem.code = "TEST-005"
        catalogItem.name = "Test Glass Bad URL"
        catalogItem.manufacturer = "BB"
        catalogItem.url = "not-a-valid-url"
        
        let itemURL = CatalogItemHelpers.getItemURL(catalogItem)
        #expect(itemURL == nil, "Malformed URL should return nil rather than crash")
    }
}