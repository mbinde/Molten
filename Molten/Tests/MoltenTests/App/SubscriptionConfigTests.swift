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
        #expect(SubscriptionConfig.FreeTierLimits.maxInventoryItems == 50)
    }

    @Test("FreeTierLimits.maxShoppingListItems has correct value")
    func testMaxShoppingListItems() {
        #expect(SubscriptionConfig.FreeTierLimits.maxShoppingListItems == 10)
    }

    @Test("FreeTierLimits.maxProjects has correct value")
    func testMaxProjects() {
        #expect(SubscriptionConfig.FreeTierLimits.maxProjects == 5)
    }

    @Test("FreeTierLimits.maxLogbookEntries has correct value")
    func testMaxLogbookEntries() {
        #expect(SubscriptionConfig.FreeTierLimits.maxLogbookEntries == 30)
    }

    @Test("FreeTierLimits.allowBatchLabelPrinting is false")
    func testAllowBatchLabelPrinting() {
        #expect(SubscriptionConfig.FreeTierLimits.allowBatchLabelPrinting == false)
    }

    @Test("FreeTierLimits are all positive or reasonable values")
    func testFreeTierLimitsPositive() {
        #expect(SubscriptionConfig.FreeTierLimits.maxInventoryItems > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxShoppingListItems > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxProjects > 0)
        #expect(SubscriptionConfig.FreeTierLimits.maxLogbookEntries > 0)
    }

    // MARK: - PremiumFeatures Tests

    @Test("PremiumFeatures.batchLabelPrinting is true")
    func testBatchLabelPrinting() {
        #expect(SubscriptionConfig.PremiumFeatures.batchLabelPrinting == true)
    }

    @Test("PremiumFeatures.qrCodeScanning is true")
    func testQRCodeScanning() {
        #expect(SubscriptionConfig.PremiumFeatures.qrCodeScanning == true)
    }

    @Test("PremiumFeatures.customInventoryTags is true")
    func testCustomInventoryTags() {
        #expect(SubscriptionConfig.PremiumFeatures.customInventoryTags == true)
    }

    @Test("PremiumFeatures.inventoryItemImages is true")
    func testInventoryItemImages() {
        #expect(SubscriptionConfig.PremiumFeatures.inventoryItemImages == true)
    }

    @Test("PremiumFeatures.customInventoryNotes is true")
    func testCustomInventoryNotes() {
        #expect(SubscriptionConfig.PremiumFeatures.customInventoryNotes == true)
    }

    @Test("PremiumFeatures.unlimitedImages is true")
    func testUnlimitedImages() {
        #expect(SubscriptionConfig.PremiumFeatures.unlimitedImages == true)
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

    @Test("UniversalFeatures.basicLabelPrinting is true")
    func testBasicLabelPrinting() {
        #expect(SubscriptionConfig.UniversalFeatures.basicLabelPrinting == true)
    }

    @Test("UniversalFeatures.csvImport is true")
    func testCSVImport() {
        #expect(SubscriptionConfig.UniversalFeatures.csvImport == true)
    }

    @Test("UniversalFeatures.bulkEditing is true")
    func testBulkEditing() {
        #expect(SubscriptionConfig.UniversalFeatures.bulkEditing == true)
    }

    // MARK: - Inventory Limit Tests

    @Test("inventoryLimit for free tier returns FreeTierLimits value")
    func testInventoryLimitForFree() {
        let limit = SubscriptionConfig.inventoryLimit(for: .free)
        #expect(limit == SubscriptionConfig.FreeTierLimits.maxInventoryItems)
        #expect(limit == 50)
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
        #expect(limit == 10)
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
        #expect(limit == 30)
    }

    @Test("logbookEntriesLimit for premium tier returns nil (unlimited)")
    func testLogbookEntriesLimitForPremium() {
        let limit = SubscriptionConfig.logbookEntriesLimit(for: .premium)
        #expect(limit == nil)
    }

    // MARK: - Batch Label Printing Tests

    @Test("allowsBatchLabelPrinting for free tier returns false")
    func testAllowsBatchLabelPrintingForFree() {
        let allowed = SubscriptionConfig.allowsBatchLabelPrinting(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsBatchLabelPrinting for premium tier returns true")
    func testAllowsBatchLabelPrintingForPremium() {
        let allowed = SubscriptionConfig.allowsBatchLabelPrinting(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - QR Code Scanning Tests

    @Test("allowsQRCodeScanning for free tier returns false")
    func testAllowsQRCodeScanningForFree() {
        let allowed = SubscriptionConfig.allowsQRCodeScanning(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsQRCodeScanning for premium tier returns true")
    func testAllowsQRCodeScanningForPremium() {
        let allowed = SubscriptionConfig.allowsQRCodeScanning(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Custom Inventory Tags Tests

    @Test("allowsCustomInventoryTags for free tier returns false")
    func testAllowsCustomInventoryTagsForFree() {
        let allowed = SubscriptionConfig.allowsCustomInventoryTags(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsCustomInventoryTags for premium tier returns true")
    func testAllowsCustomInventoryTagsForPremium() {
        let allowed = SubscriptionConfig.allowsCustomInventoryTags(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Inventory Item Images Tests

    @Test("allowsInventoryItemImages for free tier returns false")
    func testAllowsInventoryItemImagesForFree() {
        let allowed = SubscriptionConfig.allowsInventoryItemImages(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsInventoryItemImages for premium tier returns true")
    func testAllowsInventoryItemImagesForPremium() {
        let allowed = SubscriptionConfig.allowsInventoryItemImages(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - Custom Inventory Notes Tests

    @Test("allowsCustomInventoryNotes for free tier returns false")
    func testAllowsCustomInventoryNotesForFree() {
        let allowed = SubscriptionConfig.allowsCustomInventoryNotes(for: .free)
        #expect(allowed == false)
    }

    @Test("allowsCustomInventoryNotes for premium tier returns true")
    func testAllowsCustomInventoryNotesForPremium() {
        let allowed = SubscriptionConfig.allowsCustomInventoryNotes(for: .premium)
        #expect(allowed == true)
    }

    // MARK: - CSV Import Tests

    @Test("allowsCSVImport returns true for all tiers")
    func testAllowsCSVImport() {
        #expect(SubscriptionConfig.allowsCSVImport(for: .free) == true)
        #expect(SubscriptionConfig.allowsCSVImport(for: .premium) == true)
    }

    // MARK: - Bulk Editing Tests

    @Test("allowsBulkEditing returns true for all tiers")
    func testAllowsBulkEditing() {
        #expect(SubscriptionConfig.allowsBulkEditing(for: .free) == true)
        #expect(SubscriptionConfig.allowsBulkEditing(for: .premium) == true)
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

    @Test("Free tier has limited premium features")
    func testFreeTierLimitedFeatures() {
        #expect(SubscriptionConfig.allowsBatchLabelPrinting(for: .free) == false)
        #expect(SubscriptionConfig.allowsQRCodeScanning(for: .free) == false)
        #expect(SubscriptionConfig.allowsCustomInventoryTags(for: .free) == false)
    }

    @Test("Premium tier has all premium features")
    func testPremiumTierAllFeatures() {
        #expect(SubscriptionConfig.allowsBatchLabelPrinting(for: .premium) == true)
        #expect(SubscriptionConfig.allowsQRCodeScanning(for: .premium) == true)
        #expect(SubscriptionConfig.allowsCustomInventoryTags(for: .premium) == true)
    }
}
