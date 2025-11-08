//
//  InventoryItemSnapshot.swift
//  Molten
//
//  Simple data structure representing a single inventory item in a snapshot
//

import Foundation

/// Represents a single inventory item in a snapshot
struct InventoryItemSnapshot: Codable, Equatable {
    let stableId: String
    let manufacturer: String
    let sku: String
    let quantity: Double
    let unit: String
    let location: String?

    init(stableId: String, manufacturer: String, sku: String, quantity: Double, unit: String, location: String?) {
        self.stableId = stableId
        self.manufacturer = manufacturer
        self.sku = sku
        self.quantity = quantity
        self.unit = unit
        self.location = location
    }
}
