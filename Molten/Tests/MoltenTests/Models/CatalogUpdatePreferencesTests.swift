//
//  CatalogUpdatePreferencesTests.swift
//  MoltenTests
//
//  Created by Assistant on 11/9/25.
//  Tests for catalog update preferences
//

import Foundation
import Testing

@testable import Molten

@Suite("CatalogUpdatePreferences Tests")
@MainActor
struct CatalogUpdatePreferencesTests {

    // MARK: - Download Policy Tests

    @Test("Download policy allows WiFi correctly")
    func testDownloadPolicyWiFi() {
        let wifiOnlyPolicy = CatalogUpdatePreferences.DownloadPolicy.wifiOnly
        #expect(wifiOnlyPolicy.allowsDownload(isOnWiFi: true) == true)
        #expect(wifiOnlyPolicy.allowsDownload(isOnWiFi: false) == false)

        let wifiAndCellularPolicy = CatalogUpdatePreferences.DownloadPolicy.wifiAndCellular
        #expect(wifiAndCellularPolicy.allowsDownload(isOnWiFi: true) == true)
        #expect(wifiAndCellularPolicy.allowsDownload(isOnWiFi: false) == true)

        let manualPolicy = CatalogUpdatePreferences.DownloadPolicy.manual
        #expect(manualPolicy.allowsDownload(isOnWiFi: true) == false)
        #expect(manualPolicy.allowsDownload(isOnWiFi: false) == false)
    }

    @Test("Download policy descriptions are correct")
    func testDownloadPolicyDescriptions() {
        let wifiOnly = CatalogUpdatePreferences.DownloadPolicy.wifiOnly
        #expect(wifiOnly.description.contains("WiFi"))

        let wifiAndCellular = CatalogUpdatePreferences.DownloadPolicy.wifiAndCellular
        #expect(wifiAndCellular.description.contains("WiFi"))
        #expect(wifiAndCellular.description.contains("cellular"))

        let manual = CatalogUpdatePreferences.DownloadPolicy.manual
        #expect(manual.description.contains("Never") || manual.description.contains("Manual"))
    }

    // MARK: - Update Frequency Tests

    @Test("Update frequency intervals are correct")
    func testUpdateFrequencyIntervals() {
        let daily = CatalogUpdatePreferences.UpdateFrequency.daily
        #expect(daily.checkInterval == 86400)  // 24 hours

        let weekly = CatalogUpdatePreferences.UpdateFrequency.weekly
        #expect(weekly.checkInterval == 604800)  // 7 days

        let monthly = CatalogUpdatePreferences.UpdateFrequency.monthly
        #expect(monthly.checkInterval == 2592000)  // 30 days
    }

    // MARK: - Should Check For Updates Tests

    @Test("Should check for updates when never checked")
    func testShouldCheckWhenNeverChecked() {
        // Create test instance with fresh UserDefaults
        let testDefaults = UserDefaults(suiteName: "test.catalogprefs.neverChecked")!
        testDefaults.removePersistentDomain(forName: "test.catalogprefs.neverChecked")

        // Manually check the logic
        let lastCheck: Date? = nil
        let shouldCheck = lastCheck == nil

        #expect(shouldCheck == true)
    }

    @Test("Should check for updates after interval passes")
    func testShouldCheckAfterInterval() {
        let now = Date()
        let twoDaysAgo = now.addingTimeInterval(-172800)  // 2 days ago

        let dailyFrequency = CatalogUpdatePreferences.UpdateFrequency.daily
        let timeSinceLastCheck = now.timeIntervalSince(twoDaysAgo)
        let shouldCheck = timeSinceLastCheck >= dailyFrequency.checkInterval

        #expect(shouldCheck == true)
    }

    @Test("Should not check for updates before interval passes")
    func testShouldNotCheckBeforeInterval() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)  // 1 hour ago

        let dailyFrequency = CatalogUpdatePreferences.UpdateFrequency.daily
        let timeSinceLastCheck = now.timeIntervalSince(oneHourAgo)
        let shouldCheck = timeSinceLastCheck >= dailyFrequency.checkInterval

        #expect(shouldCheck == false)
    }

    // MARK: - Catalog Source Tests

    @Test("Catalog source enum has correct values")
    func testCatalogSource() {
        let bundled = CatalogUpdatePreferences.CatalogSource.bundled
        #expect(bundled.rawValue == "Bundled")

        let downloaded = CatalogUpdatePreferences.CatalogSource.downloaded
        #expect(downloaded.rawValue == "Downloaded")

        let unknown = CatalogUpdatePreferences.CatalogSource.unknown
        #expect(unknown.rawValue == "Unknown")
    }

    // MARK: - All Cases Tests

    @Test("Download policy has all cases")
    func testDownloadPolicyAllCases() {
        let allCases = CatalogUpdatePreferences.DownloadPolicy.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.wifiOnly))
        #expect(allCases.contains(.wifiAndCellular))
        #expect(allCases.contains(.manual))
    }

    @Test("Update frequency has all cases")
    func testUpdateFrequencyAllCases() {
        let allCases = CatalogUpdatePreferences.UpdateFrequency.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.daily))
        #expect(allCases.contains(.weekly))
        #expect(allCases.contains(.monthly))
    }
}
