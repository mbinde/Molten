//
//  ShareMetadataRepository.swift
//  Molten
//
//  Stores user's share code and friend shares in UserDefaults
//

import Foundation

/// Repository for storing share metadata locally
@MainActor
class ShareMetadataRepository {

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let myShareCodeKey = "molten.shareMetadata.myShareCode"
    private let myShareMetadataKey = "molten.shareMetadata.myShareMetadata"
    private let myShareLastUpdatedKey = "molten.shareMetadata.myShareLastUpdated"
    private let friendSharesKey = "molten.shareMetadata.friendShares"

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - My Share Code

    /// Save user's share code
    func saveMyShareCode(_ shareCode: String) throws {
        userDefaults.set(shareCode, forKey: myShareCodeKey)
    }

    /// Get user's share code
    func getMyShareCode() -> String? {
        return userDefaults.string(forKey: myShareCodeKey)
    }

    /// Delete user's share code
    func deleteMyShareCode() throws {
        userDefaults.removeObject(forKey: myShareCodeKey)
        userDefaults.removeObject(forKey: myShareMetadataKey)
    }

    // MARK: - My Share Metadata

    /// Save user's share metadata (display name and notes)
    func saveMyShareMetadata(_ metadata: MyShareMetadata) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        userDefaults.set(data, forKey: myShareMetadataKey)
    }

    /// Get user's share metadata
    func getMyShareMetadata() -> MyShareMetadata? {
        guard let data = userDefaults.data(forKey: myShareMetadataKey) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(MyShareMetadata.self, from: data)
    }

    // MARK: - My Share Last Updated

    /// Save timestamp of last share update
    func setMyShareLastUpdated(_ date: Date) {
        userDefaults.set(date, forKey: myShareLastUpdatedKey)
    }

    /// Get timestamp of last share update
    func getMyShareLastUpdated() -> Date? {
        return userDefaults.object(forKey: myShareLastUpdatedKey) as? Date
    }

    // MARK: - Friend Shares

    /// Save or update a friend share
    func saveFriendShare(_ share: FriendShare) throws {
        var shares = getFriendShares()

        // Remove existing share with same code if present
        shares.removeAll { $0.shareCode == share.shareCode }

        // Add new share
        shares.append(share)

        // Save to UserDefaults
        let encoder = JSONEncoder()
        let data = try encoder.encode(shares)
        userDefaults.set(data, forKey: friendSharesKey)
    }

    /// Get all friend shares
    func getFriendShares() -> [FriendShare] {
        guard let data = userDefaults.data(forKey: friendSharesKey) else {
            return []
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode([FriendShare].self, from: data)
        } catch {
            // If decoding fails, return empty array
            return []
        }
    }

    /// Get a specific friend share by code
    func getFriendShare(shareCode: String) -> FriendShare? {
        return getFriendShares().first { $0.shareCode == shareCode }
    }

    /// Delete a friend share by code
    func deleteFriendShare(shareCode: String) throws {
        var shares = getFriendShares()
        shares.removeAll { $0.shareCode == shareCode }

        let encoder = JSONEncoder()
        let data = try encoder.encode(shares)
        userDefaults.set(data, forKey: friendSharesKey)
    }

    /// Delete all friend shares
    func deleteAllFriendShares() throws {
        userDefaults.removeObject(forKey: friendSharesKey)
    }
}
