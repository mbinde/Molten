//
//  SnapshotResult.swift
//  Molten
//
//  Result of deserializing an inventory snapshot
//

import Foundation

/// Result of deserializing an inventory snapshot
struct SnapshotResult {
    let items: [InventoryItemSnapshot]
    let timestamp: Date
    let version: String
    let isValid: Bool

    init(items: [InventoryItemSnapshot], timestamp: Date, version: String, isValid: Bool) {
        self.items = items
        self.timestamp = timestamp
        self.version = version
        self.isValid = isValid
    }
}
