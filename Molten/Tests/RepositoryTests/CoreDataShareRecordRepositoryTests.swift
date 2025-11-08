//
//  CoreDataShareRecordRepositoryTests.swift
//  RepositoryTests
//
//  Tests for CoreDataShareRecordRepository - manages friend share records in CloudKit
//

import Testing
import Foundation
import CoreData
@testable import Molten

@Suite("Core Data ShareRecord Repository Tests")
@MainActor
struct CoreDataShareRecordRepositoryTests {

    // MARK: - Save Tests

    @Test("Should save new share record")
    func testSaveNewShareRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Test
        try repository.saveShareRecord(
            shareCode: "ABC123",
            ownerName: "Alice",
            ownerNickname: nil,
            ownerShareNotes: "My collection"
        )

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record != nil)
        #expect(record?.value(forKey: "share_code") as? String == "ABC123")
        #expect(record?.value(forKey: "owner_name") as? String == "Alice")
        #expect(record?.value(forKey: "user_share_notes") as? String == "My collection")
        #expect(record?.value(forKey: "status") as? String == "active")
    }

    @Test("Should update existing share record")
    func testUpdateExistingShareRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Create initial record
        try repository.saveShareRecord(
            shareCode: "ABC123",
            ownerName: "Alice",
            ownerNickname: nil,
            ownerShareNotes: "Old notes"
        )

        // Test - update with new data
        try repository.saveShareRecord(
            shareCode: "ABC123",
            ownerName: "Alice Smith",
            ownerNickname: "Friend from GAS",
            ownerShareNotes: "New notes"
        )

        // Verify
        let records = try repository.getActiveShareRecords()
        #expect(records.count == 1)

        let record = records.first
        #expect(record?.value(forKey: "owner_name") as? String == "Alice Smith")
        #expect(record?.value(forKey: "owner_nickname") as? String == "Friend from GAS")
        #expect(record?.value(forKey: "user_share_notes") as? String == "New notes")
    }

    @Test("Should save all optional fields")
    func testSaveAllOptionalFields() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Test
        try repository.saveShareRecord(
            shareCode: "ABC123",
            ownerName: "Alice",
            ownerNickname: "Alice from GAS",
            ownerShareNotes: "Boro specialist",
            iconSymbol: "star.fill",
            iconBackgroundHex: "#FF5733",
            iconForegroundHex: "#FFFFFF"
        )

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record?.value(forKey: "owner_nickname") as? String == "Alice from GAS")
        #expect(record?.value(forKey: "icon_symbol") as? String == "star.fill")
        #expect(record?.value(forKey: "icon_background_hex") as? String == "#FF5733")
        #expect(record?.value(forKey: "icon_foreground_hex") as? String == "#FFFFFF")
    }

    // MARK: - Fetch Tests

    @Test("Should get active share records")
    func testGetActiveShareRecords() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Create multiple records
        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")
        try repository.saveShareRecord(shareCode: "DEF456", ownerName: "Bob")
        try repository.saveShareRecord(shareCode: "GHI789", ownerName: "Charlie")

        // Deactivate one
        try repository.deactivateShareRecord(shareCode: "DEF456")

        // Test
        let activeRecords = try repository.getActiveShareRecords()

        // Verify - only active records returned
        #expect(activeRecords.count == 2)

        let shareCodes = activeRecords.map { $0.value(forKey: "share_code") as? String }
        #expect(shareCodes.contains("ABC123"))
        #expect(shareCodes.contains("GHI789"))
        #expect(!shareCodes.contains("DEF456"))
    }

    @Test("Should get share record by code")
    func testGetShareRecordByCode() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Create records
        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")
        try repository.saveShareRecord(shareCode: "DEF456", ownerName: "Bob")

        // Test
        let record = try repository.getShareRecord(shareCode: "ABC123")

        // Verify
        #expect(record != nil)
        #expect(record?.value(forKey: "share_code") as? String == "ABC123")
        #expect(record?.value(forKey: "owner_name") as? String == "Alice")
    }

    @Test("Should return nil for non-existent share code")
    func testGetNonExistentShareRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Test
        let record = try repository.getShareRecord(shareCode: "NOTFOUND")

        // Verify
        #expect(record == nil)
    }

    // MARK: - Deactivate Tests

    @Test("Should deactivate share record")
    func testDeactivateShareRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")

        // Test
        try repository.deactivateShareRecord(shareCode: "ABC123")

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record?.value(forKey: "status") as? String == "inactive")

        let activeRecords = try repository.getActiveShareRecords()
        #expect(activeRecords.isEmpty)
    }

    @Test("Should not error when deactivating non-existent record")
    func testDeactivateNonExistentRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Test - should not throw
        try repository.deactivateShareRecord(shareCode: "NOTFOUND")
    }

    // MARK: - Reactivate Tests

    @Test("Should reactivate share record")
    func testReactivateShareRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")
        try repository.deactivateShareRecord(shareCode: "ABC123")

        // Test
        try repository.reactivateShareRecord(shareCode: "ABC123")

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record?.value(forKey: "status") as? String == "active")

        let activeRecords = try repository.getActiveShareRecords()
        #expect(activeRecords.count == 1)
    }

    // MARK: - Update Tests

    @Test("Should update last fetched timestamp")
    func testUpdateLastFetched() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")

        let originalRecord = try repository.getShareRecord(shareCode: "ABC123")
        let originalTimestamp = originalRecord?.value(forKey: "last_fetched") as? Date

        // Wait a bit
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Test
        try repository.updateLastFetched(shareCode: "ABC123")

        // Verify
        let updatedRecord = try repository.getShareRecord(shareCode: "ABC123")
        let newTimestamp = updatedRecord?.value(forKey: "last_fetched") as? Date

        #expect(newTimestamp != nil)
        #expect(newTimestamp! > originalTimestamp!)
    }

    @Test("Should update owner nickname")
    func testUpdateOwnerNickname() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")

        // Test
        try repository.updateOwnerNickname(shareCode: "ABC123", nickname: "Alice from GAS 2025")

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record?.value(forKey: "owner_nickname") as? String == "Alice from GAS 2025")
    }

    @Test("Should update user share notes")
    func testUpdateUserShareNotes() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")

        // Test
        try repository.updateUserShareNotes(shareCode: "ABC123", notes: "Met at GAS, boro specialist")

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record?.value(forKey: "user_share_notes") as? String == "Met at GAS, boro specialist")
    }

    @Test("Should update icon")
    func testUpdateIcon() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")

        // Test
        try repository.updateIcon(
            shareCode: "ABC123",
            symbol: "flame.fill",
            backgroundHex: "#FF5733",
            foregroundHex: "#FFFFFF"
        )

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record?.value(forKey: "icon_symbol") as? String == "flame.fill")
        #expect(record?.value(forKey: "icon_background_hex") as? String == "#FF5733")
        #expect(record?.value(forKey: "icon_foreground_hex") as? String == "#FFFFFF")
    }

    @Test("Should clear nickname with nil")
    func testClearNickname() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        try repository.saveShareRecord(
            shareCode: "ABC123",
            ownerName: "Alice",
            ownerNickname: "Friend from GAS"
        )

        // Test
        try repository.updateOwnerNickname(shareCode: "ABC123", nickname: nil)

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record?.value(forKey: "owner_nickname") as? String == nil)
    }

    // MARK: - Delete Tests

    @Test("Should permanently delete share record")
    func testDeleteShareRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")

        // Test
        try repository.deleteShareRecord(shareCode: "ABC123")

        // Verify
        let record = try repository.getShareRecord(shareCode: "ABC123")
        #expect(record == nil)
    }

    @Test("Should not error when deleting non-existent record")
    func testDeleteNonExistentRecord() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Test - should not throw
        try repository.deleteShareRecord(shareCode: "NOTFOUND")
    }

    // MARK: - Timestamp Tests

    @Test("Should set date_added only on creation")
    func testDateAddedSetOnCreation() async throws {
        // Setup
        let controller = PersistenceController.createTestController()
        let repository = CoreDataShareRecordRepository(context: controller.container.viewContext)

        // Create
        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice")

        let firstRecord = try repository.getShareRecord(shareCode: "ABC123")
        let firstDateAdded = firstRecord?.value(forKey: "date_added") as? Date

        // Wait
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Update
        try repository.saveShareRecord(shareCode: "ABC123", ownerName: "Alice Updated")

        // Verify - date_added should not change
        let secondRecord = try repository.getShareRecord(shareCode: "ABC123")
        let secondDateAdded = secondRecord?.value(forKey: "date_added") as? Date

        #expect(firstDateAdded == secondDateAdded)
    }
}
