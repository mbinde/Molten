//
//  ReceiptPreferencesTests.swift
//  MoltenTests
//
//  Tests for ReceiptPreferences - UserDefaults storage for receipt settings
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

@Suite("ReceiptPreferences Tests")
@MainActor
struct ReceiptPreferencesTests {

    // MARK: - Test Helpers

    private func createTestPreferences() -> ReceiptPreferences {
        let suiteName = "com.molten.tests.receipt.preferences.\(UUID().uuidString)"
        let localStore = UserDefaults(suiteName: suiteName)!
        // Use NSUbiquitousKeyValueStore.default in tests (no iCloud sync in simulator)
        let prefs = ReceiptPreferences(cloudStore: .default, localStore: localStore)
        // Reset to clear any state from previous tests (shared cloudStore)
        prefs.reset()
        return prefs
    }

    // MARK: - Default Values Tests

    @Test("Should have nil user ID by default")
    func testDefaultUserId() {
        let preferences = createTestPreferences()
        #expect(preferences.userId == nil)
    }

    @Test("Should have nil plus address by default")
    func testDefaultPlusAddress() {
        let preferences = createTestPreferences()
        #expect(preferences.plusAddress == nil)
    }

    @Test("Should have disabled by default")
    func testDefaultIsEnabled() {
        let preferences = createTestPreferences()
        #expect(preferences.isEnabled == false)
    }

    @Test("Should have zero pending count by default")
    func testDefaultPendingCount() {
        let preferences = createTestPreferences()
        #expect(preferences.pendingReceiptCount == 0)
    }

    @Test("Should have nil last sync timestamp by default")
    func testDefaultLastSyncTimestamp() {
        let preferences = createTestPreferences()
        #expect(preferences.lastSyncTimestamp == nil)
    }

    @Test("Should not be set up by default")
    func testDefaultIsSetUp() {
        let preferences = createTestPreferences()
        #expect(preferences.isSetUp == false)
    }

    // MARK: - Storage Tests

    @Test("Should store and retrieve user ID")
    func testStoreUserId() {
        let preferences = createTestPreferences()
        preferences.userId = "test-user-123"
        #expect(preferences.userId == "test-user-123")
    }

    @Test("Should store and retrieve plus address key")
    func testStorePlusAddress() {
        let preferences = createTestPreferences()
        preferences.plusAddress = "abc123"  // Just the key
        #expect(preferences.plusAddress == "abc123")
    }

    @Test("Should store and retrieve enabled state")
    func testStoreIsEnabled() {
        let preferences = createTestPreferences()
        preferences.isEnabled = true
        #expect(preferences.isEnabled == true)
    }

    @Test("Should store and retrieve pending count")
    func testStorePendingCount() {
        let preferences = createTestPreferences()
        preferences.pendingReceiptCount = 42
        #expect(preferences.pendingReceiptCount == 42)
    }

    @Test("Should store and retrieve last sync timestamp")
    func testStoreLastSyncTimestamp() {
        let preferences = createTestPreferences()
        let date = Date()
        preferences.lastSyncTimestamp = date
        #expect(preferences.lastSyncTimestamp != nil)
        #expect(abs(preferences.lastSyncTimestamp!.timeIntervalSince(date)) < 1)
    }

    // MARK: - isSetUp Computed Property Tests

    @Test("Should be set up when enabled with user ID and plus address")
    func testIsSetUpWhenConfigured() {
        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test123"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true
        #expect(preferences.isSetUp == true)
    }

    @Test("Should not be set up when disabled")
    func testNotSetUpWhenDisabled() {
        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test123"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = false
        #expect(preferences.isSetUp == false)
    }

    @Test("Should not be set up without user ID")
    func testNotSetUpWithoutUserId() {
        let preferences = createTestPreferences()
        preferences.plusAddress = "test123"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true
        #expect(preferences.isSetUp == false)
    }

    @Test("Should not be set up without plus address")
    func testNotSetUpWithoutPlusAddress() {
        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true
        #expect(preferences.isSetUp == false)
    }

    // MARK: - receiptEmail Computed Property Tests

    @Test("Should return forwarding email based on plus key")
    func testReceiptEmail() {
        let preferences = createTestPreferences()
        preferences.plusAddress = "test123"  // Just the key, not full email
        preferences.identifierType = .plusAddress
        #expect(preferences.receiptEmail == "receipts+test123@moltenglass.app")
    }

    @Test("Should return nil for receipt email when no plus address")
    func testReceiptEmailNil() {
        let preferences = createTestPreferences()
        #expect(preferences.receiptEmail == nil)
    }

    // MARK: - Reset Tests

    @Test("Should reset all values")
    func testReset() {
        let preferences = createTestPreferences()
        preferences.userId = "test-user"
        preferences.plusAddress = "test123"  // Just the key
        preferences.identifierType = .plusAddress
        preferences.isEnabled = true
        preferences.pendingReceiptCount = 10
        preferences.lastSyncTimestamp = Date()

        preferences.reset()

        #expect(preferences.userId == nil)
        #expect(preferences.plusAddress == nil)
        #expect(preferences.isEnabled == false)
        #expect(preferences.pendingReceiptCount == 0)
        #expect(preferences.lastSyncTimestamp == nil)
        #expect(preferences.isSetUp == false)
    }
}
