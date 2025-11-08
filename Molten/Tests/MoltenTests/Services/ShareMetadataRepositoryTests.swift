//
//  ShareMetadataRepositoryTests.swift
//  MoltenTests
//
//  Tests for ShareMetadataRepository - stores user's share code and friend shares
//

import Testing
import Foundation
@testable import Molten

@Suite("ShareMetadataRepository Tests")
@MainActor
struct ShareMetadataRepositoryTests {

    // MARK: - Test Lifecycle

    init() {
        // Clean up any existing test data
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.myShareCode")
        UserDefaults.standard.removeObject(forKey: "molten.shareMetadata.friendShares")
    }

    // MARK: - My Share Code Tests

    @Test("Should save my share code")
    func testSaveMyShareCode() async throws {
        let repository = ShareMetadataRepository()

        try repository.saveMyShareCode("ABC123")

        let retrieved = repository.getMyShareCode()
        #expect(retrieved == "ABC123")
    }

    @Test("Should return nil when no share code saved")
    func testGetMyShareCodeWhenNone() async throws {
        let repository = ShareMetadataRepository()

        let retrieved = repository.getMyShareCode()
        #expect(retrieved == nil)
    }

    @Test("Should update existing share code")
    func testUpdateMyShareCode() async throws {
        let repository = ShareMetadataRepository()

        try repository.saveMyShareCode("ABC123")
        try repository.saveMyShareCode("XYZ789")

        let retrieved = repository.getMyShareCode()
        #expect(retrieved == "XYZ789")
    }

    @Test("Should delete my share code")
    func testDeleteMyShareCode() async throws {
        let repository = ShareMetadataRepository()

        try repository.saveMyShareCode("ABC123")
        try repository.deleteMyShareCode()

        let retrieved = repository.getMyShareCode()
        #expect(retrieved == nil)
    }

    // MARK: - Friend Shares Tests

    @Test("Should save friend share")
    func testSaveFriendShare() async throws {
        let repository = ShareMetadataRepository()

        let share = FriendShare(
            shareCode: "FRIEND",
            friendName: "Alice",
            dateAdded: Date()
        )

        try repository.saveFriendShare(share)

        let retrieved = repository.getFriendShares()
        #expect(retrieved.count == 1)
        #expect(retrieved[0].shareCode == "FRIEND")
        #expect(retrieved[0].friendName == "Alice")
    }

    @Test("Should return empty array when no friend shares")
    func testGetFriendSharesWhenNone() async throws {
        let repository = ShareMetadataRepository()

        let retrieved = repository.getFriendShares()
        #expect(retrieved.isEmpty)
    }

    @Test("Should save multiple friend shares")
    func testSaveMultipleFriendShares() async throws {
        let repository = ShareMetadataRepository()

        let share1 = FriendShare(shareCode: "ALICE1", friendName: "Alice", dateAdded: Date())
        let share2 = FriendShare(shareCode: "BOB123", friendName: "Bob", dateAdded: Date())

        try repository.saveFriendShare(share1)
        try repository.saveFriendShare(share2)

        let retrieved = repository.getFriendShares()
        #expect(retrieved.count == 2)
    }

    @Test("Should delete friend share by code")
    func testDeleteFriendShare() async throws {
        let repository = ShareMetadataRepository()

        let share1 = FriendShare(shareCode: "ALICE1", friendName: "Alice", dateAdded: Date())
        let share2 = FriendShare(shareCode: "BOB123", friendName: "Bob", dateAdded: Date())

        try repository.saveFriendShare(share1)
        try repository.saveFriendShare(share2)

        try repository.deleteFriendShare(shareCode: "ALICE1")

        let retrieved = repository.getFriendShares()
        #expect(retrieved.count == 1)
        #expect(retrieved[0].shareCode == "BOB123")
    }

    @Test("Should update friend share if same code exists")
    func testUpdateFriendShare() async throws {
        let repository = ShareMetadataRepository()

        let share1 = FriendShare(shareCode: "ALICE1", friendName: "Alice", dateAdded: Date())
        try repository.saveFriendShare(share1)

        let share2 = FriendShare(shareCode: "ALICE1", friendName: "Alice Updated", dateAdded: Date())
        try repository.saveFriendShare(share2)

        let retrieved = repository.getFriendShares()
        #expect(retrieved.count == 1)
        #expect(retrieved[0].friendName == "Alice Updated")
    }

    @Test("Should get friend share by code")
    func testGetFriendShareByCode() async throws {
        let repository = ShareMetadataRepository()

        let share = FriendShare(shareCode: "ALICE1", friendName: "Alice", dateAdded: Date())
        try repository.saveFriendShare(share)

        let retrieved = repository.getFriendShare(shareCode: "ALICE1")
        #expect(retrieved?.shareCode == "ALICE1")
        #expect(retrieved?.friendName == "Alice")
    }

    @Test("Should return nil when friend share not found")
    func testGetFriendShareByCodeNotFound() async throws {
        let repository = ShareMetadataRepository()

        let retrieved = repository.getFriendShare(shareCode: "NOTFOUND")
        #expect(retrieved == nil)
    }

    // MARK: - Persistence Tests

    @Test("Should persist across repository instances")
    func testPersistenceAcrossInstances() async throws {
        let repository1 = ShareMetadataRepository()
        try repository1.saveMyShareCode("ABC123")

        let share = FriendShare(shareCode: "FRIEND", friendName: "Friend", dateAdded: Date())
        try repository1.saveFriendShare(share)

        // Create new instance
        let repository2 = ShareMetadataRepository()

        #expect(repository2.getMyShareCode() == "ABC123")
        #expect(repository2.getFriendShares().count == 1)
    }
}
