//
//  BackupPreferencesTests.swift
//  MoltenTests
//
//  Tests for BackupPreferences - stores backup preferences and state in UserDefaults
//

#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif
import Foundation
@testable import Molten

@Suite("BackupPreferences Tests")
@MainActor
struct BackupPreferencesTests {

    // MARK: - Setup

    private func createTestPreferences() -> BackupPreferences {
        let suiteName = "com.molten.tests.backup.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        return BackupPreferences(userDefaults: userDefaults)
    }

    // MARK: - Backup Key Tests

    @Test("Should store and retrieve backup key")
    func testBackupKey() {
        let preferences = createTestPreferences()

        preferences.backupKey = "ABC-DEF-GHJ"

        #expect(preferences.backupKey == "ABC-DEF-GHJ")
    }

    @Test("Should return nil for unset backup key")
    func testBackupKeyUnset() {
        let preferences = createTestPreferences()

        #expect(preferences.backupKey == nil)
    }

    @Test("Should clear backup key when set to nil")
    func testBackupKeyClear() {
        let preferences = createTestPreferences()

        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.backupKey = nil

        #expect(preferences.backupKey == nil)
    }

    // MARK: - Enabled State Tests

    @Test("Should store and retrieve enabled state")
    func testIsEnabled() {
        let preferences = createTestPreferences()

        preferences.isEnabled = true
        #expect(preferences.isEnabled == true)

        preferences.isEnabled = false
        #expect(preferences.isEnabled == false)
    }

    @Test("Should default to disabled")
    func testIsEnabledDefault() {
        let preferences = createTestPreferences()

        #expect(preferences.isEnabled == false)
    }

    // MARK: - Paused State Tests

    @Test("Should store and retrieve paused state")
    func testIsPaused() {
        let preferences = createTestPreferences()

        preferences.isPaused = true
        #expect(preferences.isPaused == true)

        preferences.isPaused = false
        #expect(preferences.isPaused == false)
    }

    @Test("Should default to not paused")
    func testIsPausedDefault() {
        let preferences = createTestPreferences()

        #expect(preferences.isPaused == false)
    }

    // MARK: - Last Backup Timestamp Tests

    @Test("Should store and retrieve last backup timestamp")
    func testLastBackupTimestamp() {
        let preferences = createTestPreferences()
        let testDate = Date()

        preferences.lastBackupTimestamp = testDate

        #expect(preferences.lastBackupTimestamp != nil)
        // Allow for small time differences due to serialization
        #expect(abs(preferences.lastBackupTimestamp!.timeIntervalSince(testDate)) < 1)
    }

    @Test("Should return nil for unset timestamp")
    func testLastBackupTimestampUnset() {
        let preferences = createTestPreferences()

        #expect(preferences.lastBackupTimestamp == nil)
    }

    @Test("Should clear timestamp when set to nil")
    func testLastBackupTimestampClear() {
        let preferences = createTestPreferences()

        preferences.lastBackupTimestamp = Date()
        preferences.lastBackupTimestamp = nil

        #expect(preferences.lastBackupTimestamp == nil)
    }

    // MARK: - Hours Since Last Backup Tests

    @Test("Should return nil for hours since backup when never backed up")
    func testHoursSinceLastBackupNeverBackedUp() {
        let preferences = createTestPreferences()

        #expect(preferences.hoursSinceLastBackup == nil)
    }

    @Test("Should calculate hours since last backup")
    func testHoursSinceLastBackup() {
        let preferences = createTestPreferences()

        // Set timestamp to 2 hours ago
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        preferences.lastBackupTimestamp = twoHoursAgo

        let hours = preferences.hoursSinceLastBackup
        #expect(hours != nil)
        #expect(abs(hours! - 2.0) < 0.1) // Allow small margin
    }

    @Test("Should return small value for recent backup")
    func testHoursSinceRecentBackup() {
        let preferences = createTestPreferences()

        // Set timestamp to 5 minutes ago
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        preferences.lastBackupTimestamp = fiveMinutesAgo

        let hours = preferences.hoursSinceLastBackup
        #expect(hours != nil)
        #expect(hours! < 0.2) // Less than 12 minutes
    }

    // MARK: - Checksum Tests

    @Test("Should store and retrieve inventory checksum")
    func testLastInventoryChecksum() {
        let preferences = createTestPreferences()

        preferences.lastInventoryChecksum = "abc123def456"

        #expect(preferences.lastInventoryChecksum == "abc123def456")
    }

    @Test("Should store and retrieve tags checksum")
    func testLastTagsChecksum() {
        let preferences = createTestPreferences()

        preferences.lastTagsChecksum = "xyz789"

        #expect(preferences.lastTagsChecksum == "xyz789")
    }

    @Test("Should return nil for unset checksums")
    func testChecksumsUnset() {
        let preferences = createTestPreferences()

        #expect(preferences.lastInventoryChecksum == nil)
        #expect(preferences.lastTagsChecksum == nil)
    }

    // MARK: - Reset Tests

    @Test("Should reset all preferences")
    func testReset() {
        let preferences = createTestPreferences()

        // Set all values
        preferences.backupKey = "ABC-DEF-GHJ"
        preferences.isEnabled = true
        preferences.isPaused = true
        preferences.lastBackupTimestamp = Date()
        preferences.lastInventoryChecksum = "checksum1"
        preferences.lastTagsChecksum = "checksum2"

        // Reset
        preferences.reset()

        // Verify all cleared
        #expect(preferences.backupKey == nil)
        #expect(preferences.isEnabled == false)
        #expect(preferences.isPaused == false)
        #expect(preferences.lastBackupTimestamp == nil)
        #expect(preferences.lastInventoryChecksum == nil)
        #expect(preferences.lastTagsChecksum == nil)
    }

    @Test("Should handle reset when already empty")
    func testResetWhenEmpty() {
        let preferences = createTestPreferences()

        // Should not throw
        preferences.reset()

        #expect(preferences.backupKey == nil)
        #expect(preferences.isEnabled == false)
    }

    // MARK: - Persistence Tests

    @Test("Should persist values across instances")
    func testPersistence() {
        let suiteName = "com.molten.tests.backup.persistence.\(UUID().uuidString)"

        // First instance - set values
        let prefs1 = BackupPreferences(userDefaults: UserDefaults(suiteName: suiteName)!)
        prefs1.backupKey = "ABC-DEF-GHJ"
        prefs1.isEnabled = true
        prefs1.isPaused = true

        // Second instance - read values
        let prefs2 = BackupPreferences(userDefaults: UserDefaults(suiteName: suiteName)!)

        #expect(prefs2.backupKey == "ABC-DEF-GHJ")
        #expect(prefs2.isEnabled == true)
        #expect(prefs2.isPaused == true)
    }
}
