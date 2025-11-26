//
//  SubscriptionConfigTests.swift
//  MoltenTests
//
//  Unit tests for SubscriptionConfig and SubscriptionTier
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

@Suite("SubscriptionConfig Tests")
@MainActor
struct SubscriptionConfigTests {

    // MARK: - SubscriptionTier Tests

    @Test("SubscriptionTier equality works correctly")
    func testSubscriptionTierEquality() {
        #expect(SubscriptionTier.free == SubscriptionTier.free)
        #expect(SubscriptionTier.premium == SubscriptionTier.premium)
        #expect(SubscriptionTier.free != SubscriptionTier.premium)
    }

    // MARK: - FreeTierLimits Tests

    @Test("FreeTierLimits.maxInventoryItems has correct value")
    func testMaxInventoryItems() {
        #expect(SubscriptionConfig.FreeTierLimits.maxInventoryItems == 25)
    }

    @Test("FreeTierLimits.maxShoppingListItems matches FeatureFlags")
    func testMaxShoppingListItems() {
        #expect(SubscriptionConfig.FreeTierLimits.maxShoppingListItems == FeatureFlags.FREE_TIER_SHOPPING_LIST_LIMIT)
    }

    @Test("FreeTierLimits.maxProjects has correct value")
    func testMaxProjects() {
        #expect(SubscriptionConfig.FreeTierLimits.maxProjects == 5)
    }

    @Test("FreeTierLimits.maxLogbookEntries has correct value")
    func testMaxLogbookEntries() {
        #expect(SubscriptionConfig.FreeTierLimits.maxLogbookEntries == 10)
    }

    @Test("FreeTierLimits are all positive values")
    func testFreeTierLimitsPositive() {
        #expect(SubscriptionConfig.FreeTierLimits.maxInventoryItems > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxShoppingListItems > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxProjects > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxLogbookEntries > 0)
    }

    // MARK: - ProFeatures Tests

    @Test("ProFeatures.unlimitedInventory is true")
    func testUnlimitedInventory() {
        #expect(SubscriptionConfig.ProFeatures.unlimitedInventory == true)
    }

    @Test("ProFeatures.unlimitedShoppingList is true")
    func testUnlimitedShoppingList() {
        #expect(SubscriptionConfig.ProFeatures.unlimitedShoppingList == true)
    }

    @Test("ProFeatures.unlimitedProjects is true")
    func testUnlimitedProjects() {
        #expect(SubscriptionConfig.ProFeatures.unlimitedProjects == true)
    }

    @Test("ProFeatures.unlimitedLogbookEntries is true")
    func testUnlimitedLogbookEntries() {
        #expect(SubscriptionConfig.ProFeatures.unlimitedLogbookEntries == true)
    }

    @Test("ProFeatures.versionedCloudBackups is true")
    func testVersionedCloudBackups() {
        #expect(SubscriptionConfig.ProFeatures.versionedCloudBackups == true)
    }

    // MARK: - UniversalFeatures Tests

    @Test("UniversalFeatures.catalogAccess is true")
    func testCatalogAccess() {
        #expect(SubscriptionConfig.UniversalFeatures.catalogAccess == true)
    }

    @Test("UniversalFeatures.cloudKitSync is true")
    func testCloudKitSync() {
        #expect(SubscriptionConfig.UniversalFeatures.cloudKitSync == true)
    }

    @Test("UniversalFeatures.exportData is true")
    func testExportData() {
        #expect(SubscriptionConfig.UniversalFeatures.exportData == true)
    }

    @Test("UniversalFeatures.labelPrinting is true")
    func testLabelPrinting() {
        #expect(SubscriptionConfig.UniversalFeatures.labelPrinting == true)
    }

    @Test("UniversalFeatures.qrCodeScanning is true")
    func testQRCodeScanning() {
        #expect(SubscriptionConfig.UniversalFeatures.qrCodeScanning == true)
    }

    @Test("UniversalFeatures.customInventoryTags is true")
    func testCustomInventoryTags() {
        #expect(SubscriptionConfig.UniversalFeatures.customInventoryTags == true)
    }

    @Test("UniversalFeatures.inventoryItemImages is true")
    func testInventoryItemImages() {
        #expect(SubscriptionConfig.UniversalFeatures.inventoryItemImages == true)
    }

    @Test("UniversalFeatures.customInventoryNotes is true")
    func testCustomInventoryNotes() {
        #expect(SubscriptionConfig.UniversalFeatures.customInventoryNotes == true)
    }

    // MARK: - Inventory Limit Tests

    @Test("inventoryLimit for free tier returns FreeTierLimits value")
    func testInventoryLimitForFree() {
        let limit = SubscriptionConfig.inventoryLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxInventoryItems)
        #expect(limit == 25)
    }

    @Test("inventoryLimit for premium tier returns nil (unlimited)")
    func testInventoryLimitForPremium() {
        let limit = SubscriptionConfig.inventoryLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Shopping List Limit Tests

    @Test("shoppingListLimit for free tier returns FreeTierLimits value")
    func testShoppingListLimitForFree() {
        let limit = SubscriptionConfig.shoppingListLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxShoppingListItems)
    }

    @Test("shoppingListLimit for premium tier returns nil (unlimited)")
    func testShoppingListLimitForPremium() {
        let limit = SubscriptionConfig.shoppingListLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Projects Limit Tests

    @Test("projectsLimit for free tier returns FreeTierLimits value")
    func testProjectsLimitForFree() {
        let limit = SubscriptionConfig.projectsLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxProjects)
        #expect(limit == 5)
    }

    @Test("projectsLimit for premium tier returns nil (unlimited)")
    func testProjectsLimitForPremium() {
        let limit = SubscriptionConfig.projectsLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Logbook Entries Limit Tests

    @Test("logbookEntriesLimit for free tier returns FreeTierLimits value")
    func testLogbookEntriesLimitForFree() {
        let limit = SubscriptionConfig.logbookEntriesLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxLogbookEntries)
        #expect(limit == 10)
    }

    @Test("logbookEntriesLimit for premium tier returns nil (unlimited)")
    func testLogbookEntriesLimitForPremium() {
        let limit = SubscriptionConfig.logbookEntriesLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Versioned Cloud Backups Tests

    @Test("allowsVersionedCloudBackups for free tier returns false")
    func testAllowsVersionedCloudBackupsForFree() {
        let allowed = SubscriptionConfig.allowsVersionedCloudBackups(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsVersionedCloudBackups for premium tier returns true")
    func testAllowsVersionedCloudBackupsForPremium() {
        let allowed = SubscriptionConfig.allowsVersionedCloudBackups(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Comprehensive Tier Comparison Tests

    @Test("Free tier has all limits set")
    func testFreeTierHasLimits() {
        #expect(SubscriptionConfig.inventoryLimit(for: .free) != nil)
        #expect(SubscriptionConfig.shoppingListLimit(for: .free) != nil)
        #expect(SubscriptionConfig.projectsLimit(for: .free) != nil)
        #expect(SubscriptionConfig.logbookEntriesLimit(for: .free) != nil)
    }

    @Test("Premium tier has no limits (all nil)")
    func testPremiumTierHasNoLimits() {
        #expect(SubscriptionConfig.inventoryLimit(for: .premium) == nil)
        #expect(SubscriptionConfig.shoppingListLimit(for: .premium) == nil)
        #expect(SubscriptionConfig.projectsLimit(for: .premium) == nil)
        #expect(SubscriptionConfig.logbookEntriesLimit(for: .premium) == nil)
    }

    @Test("Free tier does not have versioned cloud backups")
    func testFreeTierNoVersionedBackups() {
        #expect(SubscriptionConfig.allowsVersionedCloudBackups(for: .free) == false)
    }

    @Test("Premium tier has versioned cloud backups")
    func testPremiumTierHasVersionedBackups() {
        #expect(SubscriptionConfig.allowsVersionedCloudBackups(for: .premium) == true)
    }

    @Test("All universal features are available")
    func testAllUniversalFeaturesAvailable() {
        #expect(SubscriptionConfig.UniversalFeatures.catalogAccess == true)
        #expect(SubscriptionConfig.UniversalFeatures.cloudKitSync == true)
        #expect(SubscriptionConfig.UniversalFeatures.exportData == true)
        #expect(SubscriptionConfig.UniversalFeatures.labelPrinting == true)
        #expect(SubscriptionConfig.UniversalFeatures.qrCodeScanning == true)
        #expect(SubscriptionConfig.UniversalFeatures.customInventoryTags == true)
        #expect(SubscriptionConfig.UniversalFeatures.inventoryItemImages == true)
        #expect(SubscriptionConfig.UniversalFeatures.customInventoryNotes == true)
    }
}
