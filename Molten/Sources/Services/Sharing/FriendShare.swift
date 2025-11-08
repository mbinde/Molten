//
//  FriendShare.swift
//  Molten
//
//  Represents a friend's shared inventory
//

import Foundation

/// Metadata about a friend's shared inventory
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
}
