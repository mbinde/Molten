//
//  SnapshotResult.swift
//  Molten
//
//  Result of deserializing an inventory snapshot
//

import Foundation

/// Result of deserializing an inventory snapshot
public struct SnapshotResult {
    public let items: [InventoryItemSnapshot]
    public let timestamp: Date
    public let version: String
    public let isValid: Bool

    public init(items: [InventoryItemSnapshot], timestamp: Date, version: String, isValid: Bool) {
        self.items = items
        self.timestamp = timestamp
        self.version = version
        self.isValid = isValid
    }
}
