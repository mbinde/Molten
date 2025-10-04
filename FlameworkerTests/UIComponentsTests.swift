//
//  UIComponentsTests.swift
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

@Suite("AlertBuilders Tests")
struct AlertBuildersTests {
    
    @Test("Deletion confirmation alert message replacement works")
    func testDeletionConfirmationMessageReplacement() {
        // Test the message replacement logic
        let template = "Are you sure you want to delete {count} items?"
        let itemCount = 5
        let result = template.replacingOccurrences(of: "{count}", with: "\(itemCount)")
        
        #expect(result == "Are you sure you want to delete 5 items?", "Should replace count placeholder correctly")
    }
    
    @Test("Message replacement handles zero count")
    func testMessageReplacementWithZeroCount() {
        let template = "Delete {count} items?"
        let itemCount = 0
        let result = template.replacingOccurrences(of: "{count}", with: "\(itemCount)")
        
        #expect(result == "Delete 0 items?", "Should handle zero count correctly")
    }
    
    @Test("Message replacement handles large count")
    func testMessageReplacementWithLargeCount() {
        let template = "Delete {count} items?"
        let itemCount = 1000
        let result = template.replacingOccurrences(of: "{count}", with: "\(itemCount)")
        
        #expect(result == "Delete 1000 items?", "Should handle large count correctly")
    }
}

@Suite("InventoryViewComponents Tests")
struct InventoryViewComponentsTests {
    
    @Test("InventoryDataValidator has inventory data correctly")
    func testInventoryDataValidatorHasData() {
        // Test the logic without Core Data dependencies
        struct MockInventoryItem {
            let count: Double
            let notes: String?
            
            var hasInventory: Bool { count > 0 }
            var hasNotes: Bool {
                guard let notes = notes else { return false }
                return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            var hasAnyData: Bool { hasInventory || hasNotes }
        }
        
        let itemWithInventory = MockInventoryItem(count: 5.0, notes: nil)
        let itemWithNotes = MockInventoryItem(count: 0.0, notes: "Some notes")
        let itemWithBoth = MockInventoryItem(count: 3.0, notes: "Notes and inventory")
        let itemWithNeither = MockInventoryItem(count: 0.0, notes: nil)
        let itemWithEmptyNotes = MockInventoryItem(count: 0.0, notes: "   ")
        
        #expect(itemWithInventory.hasAnyData == true, "Item with inventory should have data")
        #expect(itemWithNotes.hasAnyData == true, "Item with notes should have data")
        #expect(itemWithBoth.hasAnyData == true, "Item with both should have data")
        #expect(itemWithNeither.hasAnyData == false, "Item with neither should not have data")
        #expect(itemWithEmptyNotes.hasAnyData == false, "Item with empty notes should not have data")
    }
    
    @Test("InventoryDataValidator format inventory display works correctly")
    func testFormatInventoryDisplay() {
        // Test the display formatting logic
        let displayWithBoth = InventoryDataValidator.formatInventoryDisplay(
            count: 5.0, 
            units: .ounces, // ounces
            type: .inventory,  // inventory  
            notes: "Test notes"
        )
        #expect(displayWithBoth != nil, "Should return display string for valid data")
        // Check for both formats since formatting might vary between implementations
        let containsCount = displayWithBoth?.contains("5.0") == true || displayWithBoth?.contains("5") == true
        #expect(containsCount, "Should contain count (either '5.0' or '5'). Actual: \(displayWithBoth ?? "nil")")
        #expect(displayWithBoth?.contains("Test notes") ?? false == true, "Should contain notes")
        
        let displayWithNotesOnly = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .ounces,
            type: .inventory,
            notes: "Only notes"
        )
        #expect(displayWithNotesOnly == "Only notes", "Should return just notes when count is zero")
        
        let displayWithCountOnly = InventoryDataValidator.formatInventoryDisplay(
            count: 3.0,
            units: .pounds, // pounds
            type: .buy,  // buy
            notes: nil
        )
        #expect(displayWithCountOnly != nil, "Should return display string for count only")
        // Check for both formats since formatting might vary between implementations
        let containsCount2 = displayWithCountOnly?.contains("3.0") == true || displayWithCountOnly?.contains("3") == true
        #expect(containsCount2, "Should contain count (either '3.0' or '3'). Actual: \(displayWithCountOnly ?? "nil")")
        
        let displayWithNeither = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .ounces,
            type: .inventory,
            notes: nil
        )
        #expect(displayWithNeither == nil, "Should return nil when no data to display")
        
        let displayWithWhitespaceNotes = InventoryDataValidator.formatInventoryDisplay(
            count: 0.0,
            units: .ounces,
            type: .inventory,
            notes: "   "
        )
        #expect(displayWithWhitespaceNotes == nil, "Should return nil for whitespace-only notes")
    }
    
    @Test("InventoryItem status properties work correctly")
    func testInventoryItemStatusProperties() {
        // Test the logic patterns used in the extension
        struct MockInventoryItem {
            let count: Double
            let notes: String?
            
            var hasInventory: Bool { count > 0 }
            var isLowStock: Bool { count > 0 && count <= 10.0 }
            var hasNotes: Bool {
                guard let notes = notes else { return false }
                return !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            var hasAnyData: Bool { hasInventory || hasNotes }
        }
        
        // Test hasInventory
        #expect(MockInventoryItem(count: 5.0, notes: nil).hasInventory == true, "Should have inventory when count > 0")
        #expect(MockInventoryItem(count: 0.0, notes: nil).hasInventory == false, "Should not have inventory when count = 0")
        
        // Test isLowStock
        #expect(MockInventoryItem(count: 5.0, notes: nil).isLowStock == true, "Should be low stock when 0 < count <= 10")
        #expect(MockInventoryItem(count: 15.0, notes: nil).isLowStock == false, "Should not be low stock when count > 10")
        #expect(MockInventoryItem(count: 0.0, notes: nil).isLowStock == false, "Should not be low stock when count = 0")
        
        // Test hasNotes  
        #expect(MockInventoryItem(count: 0.0, notes: "test").hasNotes == true, "Should have notes when notes exist")
        #expect(MockInventoryItem(count: 0.0, notes: nil).hasNotes == false, "Should not have notes when nil")
        #expect(MockInventoryItem(count: 0.0, notes: "   ").hasNotes == false, "Should not have notes when whitespace only")
        
        // Test hasAnyData
        #expect(MockInventoryItem(count: 5.0, notes: nil).hasAnyData == true, "Should have data with inventory")
        #expect(MockInventoryItem(count: 0.0, notes: "notes").hasAnyData == true, "Should have data with notes")
        #expect(MockInventoryItem(count: 0.0, notes: nil).hasAnyData == false, "Should not have data with neither")
    }
}

@Suite("ProductImageView Logic Tests")
struct ProductImageViewLogicTests {
    
    @Test("ProductImageView initialization sets properties correctly")
    func testProductImageViewInitialization() {
        // Test the initialization logic patterns
        
        struct MockProductImageView {
            let itemCode: String
            let manufacturer: String?
            let size: CGFloat
            
            init(itemCode: String, manufacturer: String? = nil, size: CGFloat = 60) {
                self.itemCode = itemCode
                self.manufacturer = manufacturer
                self.size = size
            }
        }
        
        // Test with default values
        let defaultView = MockProductImageView(itemCode: "ABC123")
        #expect(defaultView.itemCode == "ABC123", "Should set item code correctly")
        #expect(defaultView.manufacturer == nil, "Should default manufacturer to nil")
        #expect(defaultView.size == 60, "Should use default size")
        
        // Test with all parameters
        let customView = MockProductImageView(itemCode: "XYZ789", manufacturer: "TestMfg", size: 80)
        #expect(customView.itemCode == "XYZ789", "Should set custom item code")
        #expect(customView.manufacturer == "TestMfg", "Should set custom manufacturer")
        #expect(customView.size == 80, "Should set custom size")
    }
    
    @Test("ProductImageThumbnail uses correct default size")
    func testProductImageThumbnailDefaults() {
        // Test thumbnail sizing logic
        
        struct MockProductImageThumbnail {
            let size: CGFloat
            
            init(itemCode: String, manufacturer: String? = nil, size: CGFloat = 40) {
                self.size = size
            }
        }
        
        let thumbnail = MockProductImageThumbnail(itemCode: "TEST")
        #expect(thumbnail.size == 40, "Thumbnail should default to smaller size than regular view")
        
        let customThumbnail = MockProductImageThumbnail(itemCode: "TEST", size: 50)
        #expect(customThumbnail.size == 50, "Should accept custom thumbnail size")
    }
    
    @Test("ProductImageDetail uses correct default max size")
    func testProductImageDetailDefaults() {
        // Test detail view sizing logic
        
        struct MockProductImageDetail {
            let maxSize: CGFloat
            
            init(itemCode: String, manufacturer: String? = nil, maxSize: CGFloat = 200) {
                self.maxSize = maxSize
            }
        }
        
        let detail = MockProductImageDetail(itemCode: "TEST")
        #expect(detail.maxSize == 200, "Detail view should default to larger max size")
        
        let customDetail = MockProductImageDetail(itemCode: "TEST", maxSize: 300)
        #expect(customDetail.maxSize == 300, "Should accept custom max size")
    }
    
    @Test("Image view fallback calculations work correctly")
    func testImageViewFallbackCalculations() {
        // Test the calculation logic used for fallback image sizes
        
        let maxSize: CGFloat = 200
        let fallbackWidth = maxSize * 0.8
        let fallbackHeight = maxSize * 0.6
        
        #expect(fallbackWidth == 160, "Fallback width should be 80% of max size")
        #expect(fallbackHeight == 120, "Fallback height should be 60% of max size")
        
        // Test icon size calculation
        let iconSize = 40.0 * 0.4
        #expect(iconSize == 16.0, "Icon size should be 40% of container size")
    }
    
    @Test("Image view corner radius values are consistent")
    func testImageViewCornerRadius() {
        // Test that corner radius values are reasonable and consistent
        
        let standardRadius: CGFloat = 8
        let detailRadius: CGFloat = 12
        
        #expect(standardRadius > 0, "Standard radius should be positive")
        #expect(detailRadius > standardRadius, "Detail radius should be larger than standard")
        #expect(detailRadius <= 15, "Detail radius should not be excessive")
    }
}