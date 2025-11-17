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
    public let friendName: String  // Display name from their share
    public let nickname: String?  // Personal nickname we've set
    public let dateAdded: Date
    public let lastRefreshed: Date?
    public let expiresAt: Date?  // Set if this is an expiring share

    // Icon customization
    public let iconSymbol: String?
    public let iconBackgroundHex: String?
    public let iconForegroundHex: String?

    // Default icon values
    public static let defaultIconSymbol = "circle.fill"
    public static let defaultIconBackgroundHex = "#007AFF"  // iOS blue
    public static let defaultIconForegroundHex = "#FFFFFF"  // White

    public init(shareCode: String, friendName: String, nickname: String? = nil, dateAdded: Date, lastRefreshed: Date? = nil, expiresAt: Date? = nil, iconSymbol: String? = nil, iconBackgroundHex: String? = nil, iconForegroundHex: String? = nil) {
        self.id = shareCode
        self.shareCode = shareCode
        self.friendName = friendName
        self.nickname = nickname
        self.dateAdded = dateAdded
        self.lastRefreshed = lastRefreshed
        self.expiresAt = expiresAt
        self.iconSymbol = iconSymbol
        self.iconBackgroundHex = iconBackgroundHex
        self.iconForegroundHex = iconForegroundHex
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
        self.nickname = shareRecord.value(forKey: "owner_nickname") as? String
        self.dateAdded = dateAdded
        self.lastRefreshed = shareRecord.value(forKey: "last_fetched") as? Date
        self.expiresAt = shareRecord.value(forKey: "expires_at") as? Date
        self.iconSymbol = shareRecord.value(forKey: "icon_symbol") as? String
        self.iconBackgroundHex = shareRecord.value(forKey: "icon_background_hex") as? String
        self.iconForegroundHex = shareRecord.value(forKey: "icon_foreground_hex") as? String
    }
}

import CoreData

extension ShareRecord {
    /// Convert to FriendShare struct
    func toFriendShare() -> FriendShare? {
        return FriendShare(from: self)
    }
}
