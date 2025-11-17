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
    public let expiresAt: Date?  // Expiration date (only set for expiring shares)

    public init(
        items: [InventoryItemSnapshot],
        timestamp: Date,
        version: String,
        isValid: Bool,
        ownerName: String? = nil,
        ownerShareNotes: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.items = items
        self.timestamp = timestamp
        self.version = version
        self.isValid = isValid
        self.ownerName = ownerName
        self.ownerShareNotes = ownerShareNotes
        self.expiresAt = expiresAt
    }
}
