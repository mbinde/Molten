//
//  DownloadedSnapshot.swift
//  Molten
//
//  Result of downloading an inventory snapshot from the server
//

import Foundation

/// Result of downloading an inventory snapshot
public struct DownloadedSnapshot {
    public let snapshotData: Data
    public let publicKey: Data
    public let displayName: String?  // Share owner's display name (from server)
    public let shareNotes: String?  // Share owner's public notes (from server)
    public let expiresAt: Date?  // Expiration date (only set for expiring shares)

    public init(snapshotData: Data, publicKey: Data, displayName: String? = nil, shareNotes: String? = nil, expiresAt: Date? = nil) {
        self.snapshotData = snapshotData
        self.publicKey = publicKey
        self.displayName = displayName
        self.shareNotes = shareNotes
        self.expiresAt = expiresAt
    }
}
