//  InventoryItemTypeTests.swift
//  FlameworkerTests
//
//  Extracted from FlameworkerTests.swift on 10/3/25.
//  Copyright © 2025 Motley Woods. All rights reserved.
//

import Testing
import Foundation
@testable import Flameworker

@Suite("InventoryItemType Tests")
struct InventoryItemTypeTests {
    
    @Test("InventoryItemType has correct display names")
    func testDisplayNames() {
        #expect(InventoryItemType.inventory.displayName == "Inventory")
        #expect(InventoryItemType.buy.displayName == "Buy")
        #expect(InventoryItemType.sell.displayName == "Sell")
    }
    
    @Test("InventoryItemType has correct system image names")
    func testSystemImageNames() {
        #expect(InventoryItemType.inventory.systemImageName == "archivebox.fill")
        #expect(InventoryItemType.buy.systemImageName == "cart.badge.plus")
        #expect(InventoryItemType.sell.systemImageName == "dollarsign.circle.fill")
    }
    
    @Test("InventoryItemType initializes from raw value correctly")
    func testInitFromRawValue() {
        #expect(InventoryItemType(from: 0) == .inventory)
        #expect(InventoryItemType(from: 1) == .buy)
        #expect(InventoryItemType(from: 2) == .sell)
    }
    
    @Test("InventoryItemType falls back to inventory for invalid raw values")
    func testInitFromInvalidRawValue() {
        #expect(InventoryItemType(from: -1) == .inventory)
        #expect(InventoryItemType(from: 999) == .inventory)
    }
    
    @Test("InventoryItemType has correct ID values")
    func testIdValues() {
        #expect(InventoryItemType.inventory.id == 0)
        #expect(InventoryItemType.buy.id == 1)
        #expect(InventoryItemType.sell.id == 2)
    }
}