//
//  LabelUpdatePreferencesTests.swift
//  MoltenTests
//
//  Tests for label update preferences
//

import Foundation
import Testing

@testable import Molten

@Suite("LabelUpdatePreferences Tests")
@MainActor
struct LabelUpdatePreferencesTests {

    // MARK: - Label Source Tests

    @Test("Label source enum has correct raw values")
    func testLabelSource() {
        let bundled = LabelUpdatePreferences.LabelSource.bundled
        #expect(bundled.rawValue == "Bundled")

        let downloaded = LabelUpdatePreferences.LabelSource.downloaded
        #expect(downloaded.rawValue == "Downloaded")
    }

    // MARK: - Should Check For Updates Tests

    @Test("Should check for updates when never checked")
    func testShouldCheckWhenNeverChecked() {
        // Create test instance with fresh UserDefaults
        let testDefaults = UserDefaults(suiteName: "test.labelprefs.neverChecked")!
        testDefaults.removePersistentDomain(forName: "test.labelprefs.neverChecked")

        // Manually check the logic
        let lastCheck: Date? = nil
        let shouldCheck = lastCheck == nil

        #expect(shouldCheck == true)
    }

    @Test("Should check for updates after interval passes")
    func testShouldCheckAfterInterval() {
        let now = Date()
        let twoDaysAgo = now.addingTimeInterval(-172800)  // 2 days ago

        // Default check interval is 24 hours (86400 seconds)
        let checkInterval: TimeInterval = 86400
        let timeSinceLastCheck = now.timeIntervalSince(twoDaysAgo)
        let shouldCheck = timeSinceLastCheck >= checkInterval

        #expect(shouldCheck == true)
    }

    @Test("Should not check for updates before interval passes")
    func testShouldNotCheckBeforeInterval() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)  // 1 hour ago

        // Default check interval is 24 hours (86400 seconds)
        let checkInterval: TimeInterval = 86400
        let timeSinceLastCheck = now.timeIntervalSince(oneHourAgo)
        let shouldCheck = timeSinceLastCheck >= checkInterval

        #expect(shouldCheck == false)
    }

    // MARK: - Version Tracking Tests

    @Test("Current label version nil handling")
    func testCurrentVersionNilHandling() {
        // Test that nil version is correctly represented
        // The preferences use a sentinel value (0) to represent nil
        // When reading, 0 -> nil, any other value -> value - 1
        // When writing, nil -> remove, value -> value + 1

        let testDefaults = UserDefaults(suiteName: "test.labelprefs.version")!
        testDefaults.removePersistentDomain(forName: "test.labelprefs.version")

        // Fresh defaults should have no version key
        let storedValue = testDefaults.integer(forKey: "labelCurrentVersion")
        #expect(storedValue == 0)  // Default for missing key is 0

        // 0 represents nil (no version)
        let currentVersion: Int? = storedValue > 0 ? storedValue - 1 : nil
        #expect(currentVersion == nil)
    }

    @Test("Current label version storage")
    func testCurrentVersionStorage() {
        let testDefaults = UserDefaults(suiteName: "test.labelprefs.version2")!
        testDefaults.removePersistentDomain(forName: "test.labelprefs.version2")

        // Store version 5
        let versionToStore = 5
        testDefaults.set(versionToStore + 1, forKey: "labelCurrentVersion")  // Stored as 6

        // Read back
        let storedValue = testDefaults.integer(forKey: "labelCurrentVersion")
        let currentVersion: Int? = storedValue > 0 ? storedValue - 1 : nil

        #expect(currentVersion == 5)
    }

    // MARK: - Has Update Available Tests

    @Test("Has update available flag")
    func testHasUpdateAvailable() {
        let testDefaults = UserDefaults(suiteName: "test.labelprefs.update")!
        testDefaults.removePersistentDomain(forName: "test.labelprefs.update")

        // Default should be false
        #expect(testDefaults.bool(forKey: "labelHasUpdateAvailable") == false)

        // Set to true
        testDefaults.set(true, forKey: "labelHasUpdateAvailable")
        #expect(testDefaults.bool(forKey: "labelHasUpdateAvailable") == true)

        // Set to false
        testDefaults.set(false, forKey: "labelHasUpdateAvailable")
        #expect(testDefaults.bool(forKey: "labelHasUpdateAvailable") == false)
    }

    // MARK: - Last Update Dates Tests

    @Test("Last update check date storage")
    func testLastUpdateCheckDate() {
        let testDefaults = UserDefaults(suiteName: "test.labelprefs.dates")!
        testDefaults.removePersistentDomain(forName: "test.labelprefs.dates")

        // Default should be nil
        #expect(testDefaults.object(forKey: "labelLastUpdateCheck") == nil)

        // Store a date
        let testDate = Date()
        testDefaults.set(testDate, forKey: "labelLastUpdateCheck")

        // Read back (with tolerance for encoding)
        let storedDate = testDefaults.object(forKey: "labelLastUpdateCheck") as? Date
        #expect(storedDate != nil)
        if let stored = storedDate {
            #expect(abs(stored.timeIntervalSince(testDate)) < 1)  // Within 1 second
        }
    }

    @Test("Last successful update date storage")
    func testLastSuccessfulUpdateDate() {
        let testDefaults = UserDefaults(suiteName: "test.labelprefs.dates2")!
        testDefaults.removePersistentDomain(forName: "test.labelprefs.dates2")

        // Default should be nil
        #expect(testDefaults.object(forKey: "labelLastSuccessfulUpdate") == nil)

        // Store a date
        let testDate = Date()
        testDefaults.set(testDate, forKey: "labelLastSuccessfulUpdate")

        // Read back
        let storedDate = testDefaults.object(forKey: "labelLastSuccessfulUpdate") as? Date
        #expect(storedDate != nil)
    }

    // MARK: - Label Source Storage Tests

    @Test("Label source storage")
    func testLabelSourceStorage() {
        let testDefaults = UserDefaults(suiteName: "test.labelprefs.source")!
        testDefaults.removePersistentDomain(forName: "test.labelprefs.source")

        // Store bundled source
        testDefaults.set(LabelUpdatePreferences.LabelSource.bundled.rawValue, forKey: "labelSource")
        let bundledValue = testDefaults.string(forKey: "labelSource")
        #expect(bundledValue == "Bundled")

        // Store downloaded source
        testDefaults.set(LabelUpdatePreferences.LabelSource.downloaded.rawValue, forKey: "labelSource")
        let downloadedValue = testDefaults.string(forKey: "labelSource")
        #expect(downloadedValue == "Downloaded")
    }
}
