//
//  UserSettingsTests.swift
//  FlameworkerTests
//
//  Created by Assistant on 10/16/25.
//

// Standard test framework imports pattern - use in all test files
#if canImport(Testing)
import Testing
#else
#if canImport(XCTest)
import XCTest
#endif
#endif

import Foundation
@testable import Flameworker

@Suite("UserSettings Tests - User Preferences", .serialized)
struct UserSettingsTests {

    // MARK: - Test Lifecycle

    /// Reset UserDefaults before each test to ensure test isolation
    init() {
        // Clear the specific UserDefaults key before each test
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")
    }

    // MARK: - Default Value Tests

    @Test("Should have false as default value for manufacturer description expansion")
    func testDefaultValue() {
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Default should be false (collapsed)
        #expect(settings.expandManufacturerDescriptionsByDefault == false,
               "Manufacturer descriptions should default to collapsed (false)")
    }

    @Test("Should return false when UserDefaults key doesn't exist")
    func testMissingKey() {
        // Explicitly remove the key
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Should return false (UserDefaults.bool returns false for missing keys)
        #expect(settings.expandManufacturerDescriptionsByDefault == false,
               "Missing UserDefaults key should return false")
    }

    // MARK: - Setter Tests

    @Test("Should persist setting when changed to true")
    func testSetToTrue() {
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Set to true
        settings.expandManufacturerDescriptionsByDefault = true

        // Verify it was persisted
        #expect(settings.expandManufacturerDescriptionsByDefault == true,
               "Setting should be persisted as true")

        // Verify it's stored in UserDefaults
        #expect(UserDefaults.standard.bool(forKey: "expandManufacturerDescriptionsByDefault") == true,
               "Value should be stored in UserDefaults")
    }

    @Test("Should persist setting when changed to false")
    func testSetToFalse() {
        // Start with true
        UserDefaults.standard.set(true, forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Set to false
        settings.expandManufacturerDescriptionsByDefault = false

        // Verify it was persisted
        #expect(settings.expandManufacturerDescriptionsByDefault == false,
               "Setting should be persisted as false")

        // Verify it's stored in UserDefaults
        #expect(UserDefaults.standard.bool(forKey: "expandManufacturerDescriptionsByDefault") == false,
               "Value should be stored in UserDefaults")
    }

    @Test("Should toggle setting correctly")
    func testToggleSetting() {
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Start with default (false)
        #expect(settings.expandManufacturerDescriptionsByDefault == false)

        // Toggle to true
        settings.expandManufacturerDescriptionsByDefault = true
        #expect(settings.expandManufacturerDescriptionsByDefault == true)

        // Toggle back to false
        settings.expandManufacturerDescriptionsByDefault = false
        #expect(settings.expandManufacturerDescriptionsByDefault == false)

        // Toggle to true again
        settings.expandManufacturerDescriptionsByDefault = true
        #expect(settings.expandManufacturerDescriptionsByDefault == true)
    }

    // MARK: - Persistence Tests

    @Test("Should persist across multiple accesses")
    func testPersistenceAcrossAccesses() {
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Set value
        settings.expandManufacturerDescriptionsByDefault = true

        // Access multiple times - should always return true
        for _ in 1...10 {
            #expect(settings.expandManufacturerDescriptionsByDefault == true,
                   "Value should persist across multiple accesses")
        }
    }

    @Test("Should use singleton pattern correctly")
    func testSingletonPattern() {
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        // Get two references to shared instance
        let settings1 = UserSettings.shared
        let settings2 = UserSettings.shared

        // Set value through first reference
        settings1.expandManufacturerDescriptionsByDefault = true

        // Should be visible through second reference (same instance)
        #expect(settings2.expandManufacturerDescriptionsByDefault == true,
               "Singleton should share state across references")

        // Change through second reference
        settings2.expandManufacturerDescriptionsByDefault = false

        // Should be visible through first reference
        #expect(settings1.expandManufacturerDescriptionsByDefault == false,
               "Singleton should share state bidirectionally")
    }

    // MARK: - Reset Tests

    @Test("Should reset to default value when resetToDefaults is called")
    func testResetToDefaults() {
        let settings = UserSettings.shared

        // Set to non-default value
        settings.expandManufacturerDescriptionsByDefault = true
        #expect(settings.expandManufacturerDescriptionsByDefault == true)

        // Reset
        settings.resetToDefaults()

        // Should be back to default (false)
        #expect(settings.expandManufacturerDescriptionsByDefault == false,
               "resetToDefaults() should restore default value (false)")
    }

    @Test("Should reset when value was already at default")
    func testResetWhenAlreadyDefault() {
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Already at default (false)
        #expect(settings.expandManufacturerDescriptionsByDefault == false)

        // Reset should not cause any issues
        settings.resetToDefaults()

        // Should still be at default
        #expect(settings.expandManufacturerDescriptionsByDefault == false,
               "resetToDefaults() should work when already at default")
    }

    // MARK: - UserDefaults Key Tests

    @Test("Should use correct UserDefaults key")
    func testUserDefaultsKey() {
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Set value through settings
        settings.expandManufacturerDescriptionsByDefault = true

        // Verify using direct UserDefaults access with exact key
        let storedValue = UserDefaults.standard.bool(forKey: "expandManufacturerDescriptionsByDefault")
        #expect(storedValue == true, "Should use correct UserDefaults key")

        // Set value directly in UserDefaults
        UserDefaults.standard.set(false, forKey: "expandManufacturerDescriptionsByDefault")

        // Verify settings reflects the change
        #expect(settings.expandManufacturerDescriptionsByDefault == false,
               "Should read from correct UserDefaults key")
    }

    // MARK: - Concurrent Access Tests

    @Test("Should handle rapid successive changes")
    func testRapidChanges() {
        UserDefaults.standard.removeObject(forKey: "expandManufacturerDescriptionsByDefault")

        let settings = UserSettings.shared

        // Make rapid changes
        for i in 1...100 {
            settings.expandManufacturerDescriptionsByDefault = (i % 2 == 0)
        }

        // Final value should be true (100 % 2 == 0 evaluates to true)
        #expect(settings.expandManufacturerDescriptionsByDefault == true,
               "Should handle rapid successive changes correctly")
    }
}
