//
//  UserSettingsOwnerTests.swift
//  MoltenTests
//
//  Tests for UserSettings inventory owner field
//

import Testing
import Foundation
@testable import Molten

@Suite("UserSettings - Inventory Owner")
@MainActor
struct UserSettingsOwnerTests {

    @Test("Inventory owner defaults to nil")
    func inventoryOwnerDefaultsToNil() async throws {
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: "inventoryOwner")

        let settings = UserSettings.shared

        #expect(settings.inventoryOwner == nil)
    }

    @Test("Inventory owner can be set and retrieved")
    func inventoryOwnerCanBeSetAndRetrieved() async throws {
        let settings = UserSettings.shared
        let ownerName = "Glass Studio West"

        settings.inventoryOwner = ownerName

        #expect(settings.inventoryOwner == ownerName)

        // Verify it persists to UserDefaults
        let storedValue = UserDefaults.standard.string(forKey: "inventoryOwner")
        #expect(storedValue == ownerName)

        // Cleanup
        settings.inventoryOwner = nil
    }

    @Test("Inventory owner can be cleared")
    func inventoryOwnerCanBeCleared() async throws {
        let settings = UserSettings.shared

        // Set a value first
        settings.inventoryOwner = "Test Studio"
        #expect(settings.inventoryOwner != nil)

        // Clear it
        settings.inventoryOwner = nil

        #expect(settings.inventoryOwner == nil)

        // Verify UserDefaults is also cleared
        let storedValue = UserDefaults.standard.string(forKey: "inventoryOwner")
        #expect(storedValue == nil)
    }

    @Test("Inventory owner persists across UserSettings instances")
    func inventoryOwnerPersistsAcrossInstances() async throws {
        let ownerName = "Artist Name"

        // Set value
        UserSettings.shared.inventoryOwner = ownerName

        // Access through shared instance again
        let retrievedValue = UserSettings.shared.inventoryOwner

        #expect(retrievedValue == ownerName)

        // Cleanup
        UserSettings.shared.inventoryOwner = nil
    }

    @Test("Reset to defaults clears inventory owner")
    func resetToDefaultsClearsInventoryOwner() async throws {
        let settings = UserSettings.shared

        // Set a value
        settings.inventoryOwner = "Studio Name"
        #expect(settings.inventoryOwner != nil)

        // Reset to defaults
        settings.resetToDefaults()

        #expect(settings.inventoryOwner == nil)
    }

    @Test("Inventory owner supports empty string")
    func inventoryOwnerSupportsEmptyString() async throws {
        let settings = UserSettings.shared

        // Set to empty string
        settings.inventoryOwner = ""

        // Empty string should be stored (not converted to nil)
        #expect(settings.inventoryOwner == "")

        // Cleanup
        settings.inventoryOwner = nil
    }

    @Test("Inventory owner supports special characters")
    func inventoryOwnerSupportsSpecialCharacters() async throws {
        let settings = UserSettings.shared
        let ownerWithSpecialChars = "Studio & Co. — Artisan's Glass"

        settings.inventoryOwner = ownerWithSpecialChars

        #expect(settings.inventoryOwner == ownerWithSpecialChars)

        // Cleanup
        settings.inventoryOwner = nil
    }

    @Test("Inventory owner supports Unicode characters")
    func inventoryOwnerSupportsUnicode() async throws {
        let settings = UserSettings.shared
        let unicodeOwner = "玻璃工作室 Glass Atelier"

        settings.inventoryOwner = unicodeOwner

        #expect(settings.inventoryOwner == unicodeOwner)

        // Cleanup
        settings.inventoryOwner = nil
    }
}
