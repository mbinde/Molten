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
    public let ownerName: String?  // Share owner's display name
    public let ownerShareNotes: String?  // Share owner's public notes

    public init(
        items: [InventoryItemSnapshot],
        timestamp: Date,
        version: String,
        isValid: Bool,
        ownerName: String? = nil,
        ownerShareNotes: String? = nil
    ) {
        self.items = items
        self.timestamp = timestamp
        self.version = version
        self.isValid = isValid
        self.ownerName = ownerName
        self.ownerShareNotes = ownerShareNotes
    }
}
