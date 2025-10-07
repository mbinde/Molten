//
//  AddInventoryItemViewTests.swift
//  Flameworker
//
//  Created on 10/06/25.
//

import Testing
@testable import Flameworker

@Suite("AddInventoryItemView Image Display Tests")
struct AddInventoryItemViewTests {
    
    @Test("Selected catalog item should show only one image, not duplicates")
    func testSingleImageDisplayForSelectedCatalogItem() {
        // This test verifies that when a catalog item is selected in the AddInventoryItemView,
        // only one image should be displayed in the UI, not multiple copies.
        
        // The issue: Currently both ProductImageDetail and CatalogItemRowView show images,
        // creating duplicate images for the same item
        
        // Expected behavior: Only one image should be visible per catalog item
        
        #expect(false, "AddInventoryItemView currently shows duplicate images - one from ProductImageDetail and one from CatalogItemRowView. Need to fix this redundancy.")
    }
}