//
//  FlameworkerTests.swift
//  FlameworkerTests
//
//  Created by Melissa Binde on 9/27/25.
//

import Testing
import CoreData
@testable import Flameworker

@Suite("Inventory Item Type Tests")
struct FlameworkerTests {
    
    @Test("InventoryItemType enum values and display names")
    func inventoryItemTypeEnumValues() async throws {
        // Test that the raw values match the expected integers
        #expect(InventoryItemType.inventory.rawValue == 0)
        #expect(InventoryItemType.buy.rawValue == 1)
        #expect(InventoryItemType.sell.rawValue == 2)
        
        // Test that display names are correct
        #expect(InventoryItemType.inventory.displayName == "Inventory")
        #expect(InventoryItemType.buy.displayName == "Buy")
        #expect(InventoryItemType.sell.displayName == "Sell")
    }
    
    @Test("InventoryItemType system images and colors")
    func inventoryItemTypeVisualsProperties() async throws {
        // Test that each type has appropriate system images
        #expect(InventoryItemType.inventory.systemImageName == "archivebox.fill")
        #expect(InventoryItemType.buy.systemImageName == "cart.badge.plus")
        #expect(InventoryItemType.sell.systemImageName == "cart.badge.minus")
        
        // Test that each type has a color (can't test exact colors, but ensure they're different)
        #expect(InventoryItemType.inventory.color != InventoryItemType.buy.color)
        #expect(InventoryItemType.buy.color != InventoryItemType.sell.color)
        #expect(InventoryItemType.inventory.color != InventoryItemType.sell.color)
    }
    
    @Test("InventoryItemType initializes with fallback to inventory")
    func inventoryItemTypeInitialization() async throws {
        // Test valid raw values
        #expect(InventoryItemType(from: 0) == .inventory)
        #expect(InventoryItemType(from: 1) == .buy)
        #expect(InventoryItemType(from: 2) == .sell)
        
        // Test invalid raw values fallback to inventory
        #expect(InventoryItemType(from: 99) == .inventory)
        #expect(InventoryItemType(from: -1) == .inventory)
    }
    
    @Test("InventoryItem extension properties work correctly")
    func inventoryItemExtensionProperties() async throws {
        // Create in-memory context for testing
        let container = NSPersistentContainer(name: "Flameworker")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        // Load persistent stores synchronously for testing
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        let context = container.viewContext
        
        // Create test inventory item
        let item = InventoryItem(context: context)
        item.id = "test-item"
        item.type = InventoryItemType.buy.rawValue
        
        // Test the computed properties
        #expect(item.itemType == .buy)
        #expect(item.typeDisplayName == "Buy")
        #expect(item.typeSystemImage == "cart.badge.plus")
        
        // Test setting itemType
        item.itemType = .sell
        #expect(item.type == 2)
        #expect(item.itemType == .sell)
        #expect(item.typeDisplayName == "Sell")
    }
    
    @Test("All case iteration works properly")
    func inventoryItemTypeAllCases() async throws {
        let allCases = InventoryItemType.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.inventory))
        #expect(allCases.contains(.buy))
        #expect(allCases.contains(.sell))
    }
}
