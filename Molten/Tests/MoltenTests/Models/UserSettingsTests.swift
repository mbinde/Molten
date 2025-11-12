//
//  UserSettingsTests.swift
//  MoltenTests
//
//  Tests for UserSettings image quality preferences
//

import Testing
import Foundation
@testable import Molten

@Suite("UserSettings Image Quality Tests")
struct UserSettingsImageQualityTests {

    @Test("downloadFullSizeImages defaults to false")
    func testDownloadFullSizeImagesDefaultValue() async throws {
        // Given: Fresh UserDefaults
        let key = "downloadFullSizeImages"
        UserDefaults.standard.removeObject(forKey: key)

        // When: Reading the setting
        let value = UserSettings.shared.downloadFullSizeImages

        // Then: Should default to false (thumbnails)
        #expect(value == false)
    }

    @Test("downloadFullSizeImages persists changes")
    func testDownloadFullSizeImagesPersistence() async throws {
        // Given: Setting enabled
        UserSettings.shared.downloadFullSizeImages = true

        // When: Reading the value back
        let enabled = UserSettings.shared.downloadFullSizeImages

        // Then: Should be true
        #expect(enabled == true)

        // When: Setting disabled
        UserSettings.shared.downloadFullSizeImages = false
        let disabled = UserSettings.shared.downloadFullSizeImages

        // Then: Should be false
        #expect(disabled == false)
    }

    @Test("downloadFullSizeImages uses correct UserDefaults key")
    func testDownloadFullSizeImagesKey() async throws {
        // Given: Setting a value
        UserSettings.shared.downloadFullSizeImages = true

        // When: Reading directly from UserDefaults
        let value = UserDefaults.standard.bool(forKey: "downloadFullSizeImages")

        // Then: Should match
        #expect(value == true)
    }

    @Test("downloadFullSizeImages can be toggled multiple times")
    func testDownloadFullSizeImagesToggling() async throws {
        // Given: Initial state
        UserSettings.shared.downloadFullSizeImages = false

        // When: Toggling multiple times
        UserSettings.shared.downloadFullSizeImages = true
        #expect(UserSettings.shared.downloadFullSizeImages == true)

        UserSettings.shared.downloadFullSizeImages = false
        #expect(UserSettings.shared.downloadFullSizeImages == false)

        UserSettings.shared.downloadFullSizeImages = true
        #expect(UserSettings.shared.downloadFullSizeImages == true)
    }
}
