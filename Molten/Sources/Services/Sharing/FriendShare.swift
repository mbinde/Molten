//
//  FriendShare.swift
//  Molten
//
//  Represents a friend's shared inventory
//

import Foundation

/// Metadata about a friend's shared inventory
/// Note: Inventory data is stored separately in Core Data (SharedInventoryItem, SharedUserTags)
public struct FriendShare: Codable, Equatable, Identifiable {
    public let id: String  // Same as shareCode
    public let shareCode: String
    public let friendName: String
    public let dateAdded: Date
    public let lastRefreshed: Date?

    public init(shareCode: String, friendName: String, dateAdded: Date, lastRefreshed: Date? = nil) {
        self.id = shareCode
        self.shareCode = shareCode
        self.friendName = friendName
        self.dateAdded = dateAdded
        self.lastRefreshed = lastRefreshed
    }

    /// Create FriendShare from ShareRecord entity
    public init?(from shareRecord: ShareRecord) {
        guard let shareCode = shareRecord.value(forKey: "share_code") as? String,
              let ownerName = shareRecord.value(forKey: "owner_name") as? String,
              let dateAdded = shareRecord.value(forKey: "date_added") as? Date else {
            return nil
        }

        self.id = shareCode
        self.shareCode = shareCode
        self.friendName = ownerName
        self.dateAdded = dateAdded
        self.lastRefreshed = shareRecord.value(forKey: "last_fetched") as? Date
    }
}

import CoreData

extension ShareRecord {
    /// Convert to FriendShare struct
    func toFriendShare() -> FriendShare? {
        return FriendShare(from: self)
    }
}
