//
//  InventoryItemSnapshot.swift
//  Molten
//
//  Simple data structure representing a single inventory item in a snapshot
//

import Foundation

/// Represents a single inventory item in a snapshot
public struct InventoryItemSnapshot: Codable, Equatable {
    public let stableId: String
    public let manufacturer: String
    public let sku: String
    public let quantity: Double
    public let unit: String
    public let location: String?

    public init(stableId: String, manufacturer: String, sku: String, quantity: Double, unit: String, location: String?) {
        self.stableId = stableId
        self.manufacturer = manufacturer
        self.sku = sku
        self.quantity = quantity
        self.unit = unit
        self.location = location
    }
}
